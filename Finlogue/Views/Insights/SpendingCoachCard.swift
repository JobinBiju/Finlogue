//
//  SpendingCoachCard.swift
//  Finlogue
//
//  The coach at the top of Insights: a short review of the month or card
//  cycle on screen, what stands
//  out against your usual, recurring habits, and ways to save. Facts come
//  from `SpendingAnalyzer`; the wording from the on-device model when
//  Apple Intelligence is available (see `SpendingCoach`).
//

import SwiftUI
import SwiftData

@MainActor
final class SpendingCoachModel: ObservableObject {
    /// The latest review for the period on screen — possibly written from
    /// slightly older data while a fresh one is on its way.
    @Published private(set) var review: CoachReview?
    @Published private(set) var isThinking = false
    @Published private(set) var failed = false
    @Published private(set) var availability = SpendingCoach.availability

    private var periodKey: String?

    func refresh(for digest: SpendingDigest, force: Bool = false) async {
        availability = SpendingCoach.availability
        let cached = SpendingCoach.cachedReview(for: digest.period)
        if periodKey != digest.period.key {
            periodKey = digest.period.key
            review = cached
            failed = false
        }
        if !force, let cached, cached.fingerprint == SpendingCoach.reviewKey(for: digest) {
            review = cached
            return
        }
        guard availability == .available else { return }
        // Flicking through periods shouldn't start a generation for each one.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isThinking = true
        defer { isThinking = false }
        do {
            let fresh = try await SpendingCoach.review(for: digest)
            // Valid for its digest even if the screen has moved on.
            SpendingCoach.store(fresh, for: digest.period)
            guard !Task.isCancelled, periodKey == digest.period.key else { return }
            review = fresh
            failed = false
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}

struct SpendingCoachCard: View {
    let digest: SpendingDigest

    @Environment(\.modelContext) private var context
    @Environment(\.isTabActive) private var isTabActive
    @StateObject private var coach = SpendingCoachModel()
    @AppStorage(AppSettings.spendingAlertsKey) private var alertsEnabled = false
    @State private var alertsDeclined = false

    private var isStale: Bool {
        guard let review = coach.review else { return false }
        return review.fingerprint != SpendingCoach.reviewKey(for: digest)
    }

    private var summary: String {
        coach.review?.summary ?? SpendingCoach.plainSummary(for: digest)
    }

    private var tips: [CoachTip] {
        coach.review?.tips ?? []
    }

    private var signals: [SpendingSignal] {
        Array(digest.signals.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            // Crossfades in place when the period or the wording changes.
            ZStack(alignment: .topLeading) {
                Text(summary)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FinTheme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(summary)
                    .transition(.opacity)
            }
            .opacity(isStale && coach.isThinking ? 0.45 : 1)

            if !signals.isEmpty {
                VStack(spacing: 12) {
                    ForEach(signals) { signal in
                        signalRow(signal)
                            .transition(.opacity)
                    }
                }
            }

            if !habitChips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Habits")
                        .finSectionLabel()
                    FlowLayout(spacing: 8) {
                        ForEach(habitChips, id: \.text) { chip in
                            habitChip(chip)
                        }
                    }
                }
            }

            tipsArea

            footer
        }
        .padding(20)
        .animation(FinMotion.swap, value: digest.fingerprint)
        .animation(FinMotion.swap, value: coach.review)
        .animation(FinMotion.swap, value: coach.isThinking)
        .task(id: "\(digest.fingerprint)|\(isTabActive)") {
            guard isTabActive else { return }
            await coach.refresh(for: digest)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FinTheme.coral)
                .symbolEffect(.pulse, isActive: coach.isThinking)
            Text(digest.isCurrent
                 ? "Your \(digest.period.unit) so far"
                 : "\(digest.period.unit.capitalized) in review")
                .finSectionLabel()
                .contentTransition(.opacity)
            Spacer()
            if coach.availability == .available {
                Button {
                    FinHaptics.tap()
                    Task { await coach.refresh(for: digest, force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FinTheme.ink400)
                        .frame(width: 30, height: 30)
                        .background(FinTheme.paperInset, in: Circle())
                }
                .buttonStyle(.pressable)
                .disabled(coach.isThinking)
                .opacity(coach.isThinking ? 0.4 : 1)
                .accessibilityLabel("Rewrite review")
            }
        }
    }

    // MARK: Signals

    private func signalRow(_ signal: SpendingSignal) -> some View {
        let whole = SpendingCoach.whole
        let symbol: String
        let color: Color
        let title: String
        let caption: String
        let amount: Double
        switch signal {
        case .overUsual(let category):
            symbol = category.symbol
            color = Color(hex: category.colorHex)
            title = category.name
            caption = "Above your usual \(whole(category.usualTotal ?? 0)) \(digest.period.unit)"
            amount = category.spent
        case .runningAhead(let category):
            symbol = category.symbol
            color = Color(hex: category.colorHex)
            title = category.name
            caption = "\(whole(category.spent - (category.usualByNow ?? 0))) more than usual by now"
            amount = category.spent
        case .budget(let name, let spent, let limit):
            symbol = "gauge.with.needle"
            color = FinTheme.amber500
            title = "\(name) budget"
            caption = spent >= limit
                ? "Over the \(whole(limit)) limit"
                : "\(Int((spent / limit * 100).rounded(.down)))% of \(whole(limit)) used"
            amount = spent
        case .underUsual(let category):
            symbol = category.symbol
            color = Color(hex: category.colorHex)
            title = category.name
            caption = "\(whole((category.usualByNow ?? 0) - category.spent)) less than usual by now"
            amount = category.spent
        }
        return HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(signal.isGoodNews ? FinTheme.green : FinTheme.red)
            }
            Spacer(minLength: 8)
            Text(CurrencyFormatter.string(amount))
                .font(.system(size: 14, weight: .semibold))
                .kerning(-0.3)
                .foregroundStyle(FinTheme.ink)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Habits

    private struct HabitChip {
        let symbol: String
        let text: String
    }

    private var habitChips: [HabitChip] {
        var chips = digest.merchants.map {
            HabitChip(symbol: "repeat", text: "\($0.name) ×\($0.count)")
        }
        if let weekend = digest.weekendShare, weekend >= SpendingCoach.notableWeekendShare {
            chips.append(HabitChip(
                symbol: "calendar", text: "\(Int((weekend * 100).rounded()))% on weekends"
            ))
        }
        if digest.smallPurchaseCount >= 5 {
            chips.append(HabitChip(
                symbol: "cup.and.saucer",
                text: "\(digest.smallPurchaseCount) buys under \(SpendingCoach.whole(digest.smallPurchaseLimit))"
            ))
        }
        return chips
    }

    private func habitChip(_ chip: HabitChip) -> some View {
        // The symbol rides inside the text so it sits on the same line as the
        // letters rather than being centred against the whole line box.
        Text("\(Text(Image(systemName: chip.symbol)).font(.system(size: 10, weight: .bold)).foregroundStyle(FinTheme.ink400))\u{2009}\(chip.text)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(FinTheme.ink600)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(FinTheme.paperInset, in: Capsule())
    }

    // MARK: Tips

    @ViewBuilder
    private var tipsArea: some View {
        if coach.availability == .available {
            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ways to save")
                        .finSectionLabel()
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        tipRow(index: index, tip: tip)
                    }
                }
                .opacity(isStale && coach.isThinking ? 0.45 : 1)
                .transition(.opacity)
            } else if coach.isThinking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(FinTheme.ink400)
                    Text("Looking for ways to save…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                }
                .transition(.opacity)
            } else if coach.failed {
                Text("Couldn't write tips just now. Tap ↻ to try again.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FinTheme.ink400)
                    .transition(.opacity)
            }
        }
    }

    private func tipRow(index: Int, tip: CoachTip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FinTheme.coral)
                .frame(width: 22, height: 22)
                .background(FinTheme.tintCoral, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                Text(tip.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(FinTheme.ink600)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        let note: String? = switch coach.availability {
        case .available: "Written on your iPhone by Apple Intelligence"
        case .turnedOff: "Turn on Apple Intelligence in Settings for a written review and ways to save."
        case .preparing: "Apple Intelligence is still downloading. Tips will appear once it's ready."
        case .unsupported: nil
        }
        let showAlertsPrompt = digest.isCurrent && !alertsEnabled

        if note != nil || showAlertsPrompt {
            VStack(alignment: .leading, spacing: 14) {
                if showAlertsPrompt {
                    if alertsDeclined {
                        Text("Notifications are off for Finlogue. Allow them in the Settings app to get spending alerts.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                    } else {
                        Button {
                            FinHaptics.tap()
                            Task {
                                alertsDeclined = !(await SpendingAlerts.shared.enable(context: context))
                                if !alertsDeclined {
                                    ToastCenter.shared.show("Alerts on", detail: "We'll tell you when you overspend", symbol: "bell.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Alert me when I overspend")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(FinTheme.coral)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(FinTheme.tintCoral, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                }
                if let note {
                    Text("\(Image(systemName: coach.availability == .available ? "apple.intelligence" : "sparkles"))\u{2009}\(note)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                }
            }
            .transition(.opacity)
        }
    }
}
