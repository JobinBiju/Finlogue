//
//  SpendingAlerts.swift
//  Finlogue
//
//  Local notifications when spending crosses a line as it happens: a
//  category passing its usual total for the period (card cycle, or month
//  when no card has a statement day), running well ahead of where you
//  usually are, or a budget reaching 80% / 100%. Each alert fires once per
//  period. When Apple Intelligence is available the alert carries a
//  one-line tip from the on-device model.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
final class SpendingAlerts {
    static let shared = SpendingAlerts()

    private var pendingCheck: Task<Void, Never>?

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: AppSettings.spendingAlertsKey)
    }

    // MARK: Opt-in

    /// Asks for notification permission and switches alerts on. Returns false
    /// when the user declines (or declined before).
    func enable(context: ModelContext) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else {
            UserDefaults.standard.set(false, forKey: AppSettings.spendingAlertsKey)
            return false
        }
        UserDefaults.standard.set(true, forKey: AppSettings.spendingAlertsKey)
        // Alerts are about lines being crossed from now on; whatever is
        // already true shows on the Insights card instead of as a burst of
        // notifications.
        if let digest = currentDigest(context: context) {
            var sent = sentKeys(for: digest.period)
            for signal in digest.signals {
                sent.formUnion(keys(for: signal))
            }
            saveSentKeys(sent, for: digest.period)
        }
        return true
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: AppSettings.spendingAlertsKey)
        pendingCheck?.cancel()
    }

    // MARK: Checking

    /// Debounced so a burst of saves (an SMS batch, a restore) checks once.
    func scheduleCheck(context: ModelContext) {
        guard Self.isEnabled else { return }
        pendingCheck?.cancel()
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.check(context: context)
        }
    }

    private func check(context: ModelContext) async {
        guard Self.isEnabled, let digest = currentDigest(context: context) else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        var sent = sentKeys(for: digest.period)
        // At most two per check; anything else waits for the next save.
        let fresh = digest.signals
            .filter { !$0.isGoodNews }
            .filter { signal in
                // Early in a period "running ahead" is mostly noise.
                if case .runningAhead = signal, digest.dayOfPeriod < 8 { return false }
                return !keys(for: signal).isSubset(of: sent)
            }
            .prefix(2)
        guard !fresh.isEmpty else { return }

        // Record before the (slow) tip generation, so an overlapping check
        // can't send the same alert twice.
        for signal in fresh {
            sent.formUnion(keys(for: signal))
        }
        saveSentKeys(sent, for: digest.period)

        for signal in fresh {
            guard let text = await compose(signal, in: digest) else { continue }
            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default
            content.threadIdentifier = "spending-alerts"
            content.userInfo = [NotificationRouter.routeKey: NotificationRouter.insightsRoute]
            let request = UNNotificationRequest(
                identifier: "\(digest.period.key)-\(signal.id)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }

    // MARK: Wording

    /// The alert's fact, plus the model's tip when there is one.
    private func compose(_ signal: SpendingSignal, in digest: SpendingDigest) async -> (title: String, body: String)? {
        guard let text = message(for: signal, in: digest) else { return nil }
        guard let tip = await SpendingCoach.alertTip(for: signal, in: digest), !tip.isEmpty else { return text }
        return (text.title, text.body + " " + tip)
    }

    #if DEBUG
    /// Test hook: `-previewSpendingAlerts` prints every alert the current
    /// period would raise, without needing notification permission.
    func printPreview(context: ModelContext) async {
        guard let digest = currentDigest(context: context) else { return }
        for signal in digest.signals where !signal.isGoodNews {
            guard let text = await compose(signal, in: digest) else { continue }
            print("[SpendingAlert] \(text.title) — \(text.body)")
        }
        print("[SpendingAlert] done")
    }
    #endif

    private func message(for signal: SpendingSignal, in digest: SpendingDigest) -> (title: String, body: String)? {
        let whole = SpendingCoach.whole
        let daysLeft = digest.periodDays - digest.dayOfPeriod
        let unit = digest.period.unit
        let remaining = daysLeft == 0 ? "last day of the \(unit)"
            : daysLeft == 1 ? "1 day to go" : "\(daysLeft) days to go"
        switch signal {
        case .overUsual(let category):
            guard let usual = category.usualTotal else { return nil }
            return ("\(category.name) is above your usual",
                    "\(whole(category.spent)) so far this \(unit) — you usually spend about \(whole(usual)) in a whole \(unit).")
        case .runningAhead(let category):
            guard let usual = category.usualByNow else { return nil }
            return ("\(category.name) is running high",
                    "\(whole(category.spent)) \(digest.period.byDayPhrase(digest.dayOfPeriod)) — usually about \(whole(usual)) by now.")
        case .budget(let name, let spent, let limit):
            if spent >= limit {
                return ("\(name) budget used up",
                        "\(whole(spent)) of \(whole(limit)) spent, \(remaining).")
            }
            let percent = Int((spent / limit * 100).rounded(.down))
            return ("\(name) budget at \(percent)%",
                    "\(whole(spent)) of \(whole(limit)) spent, \(remaining).")
        case .underUsual:
            return nil
        }
    }

    // MARK: Once-a-period bookkeeping

    /// Alerts follow the card cycle when a card has a statement day — what
    /// Insights and Budgets open on — and the calendar month otherwise.
    private func currentDigest(context: ModelContext) -> SpendingDigest? {
        guard let period = SpendingPeriod.current(in: context) else { return nil }
        return SpendingAnalyzer.digest(in: context, period: period)
    }

    /// Keys an alert is recorded under. A budget past its limit also counts as
    /// having passed 80%, so the smaller alert never follows the bigger one.
    private func keys(for signal: SpendingSignal) -> Set<String> {
        switch signal {
        case .budget(let name, let spent, let limit):
            return spent >= limit ? ["budget80-\(name)", "budget100-\(name)"] : ["budget80-\(name)"]
        default:
            return [signal.id]
        }
    }

    private func sentKeys(for period: SpendingPeriod) -> Set<String> {
        let all = UserDefaults.standard.dictionary(forKey: AppSettings.spendingAlertsSentKey) as? [String: [String]]
        return Set(all?[period.key] ?? [])
    }

    private func saveSentKeys(_ keys: Set<String>, for period: SpendingPeriod) {
        // Only the current period matters; older entries are dropped.
        UserDefaults.standard.set(
            [period.key: Array(keys)],
            forKey: AppSettings.spendingAlertsSentKey
        )
    }
}

// MARK: - Notification routing

/// Shows spending alerts even while Finlogue is open, and opens Insights when
/// one is tapped.
@MainActor
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    static let routeKey = "route"
    static let insightsRoute = "insights"

    /// Tab to switch to; RootTabView consumes and clears it. Published so a
    /// tap that cold-launches the app is still picked up once the UI exists.
    @Published var requestedTab: Int?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let route = response.notification.request.content.userInfo[Self.routeKey] as? String
        guard route == Self.insightsRoute else { return }
        await MainActor.run { self.requestedTab = 1 }
    }
}
