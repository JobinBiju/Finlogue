//
//  SpendingCoach.swift
//  Finlogue
//
//  Puts a `SpendingDigest` into words with Apple's on-device language model
//  (Foundation Models, iOS 26+): a short review of the month or card cycle and a few ways to
//  save. The model only phrases facts the analyzer already worked out, and
//  everything runs on the device. Without Apple Intelligence the coach falls
//  back to plain sentences built from the same facts.
//

import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

struct CoachTip: Codable, Equatable, Hashable {
    let title: String
    let detail: String
}

struct CoachReview: Codable, Equatable {
    let summary: String
    let tips: [CoachTip]
    /// `SpendingCoach.reviewKey` of the digest this was written from — a
    /// mismatch means it's out of date.
    let fingerprint: String
}

enum CoachAvailability: Equatable {
    case available
    /// Apple Intelligence is switched off in Settings.
    case turnedOff
    /// Supported, but the model is still downloading.
    case preparing
    /// Older iOS, an ineligible device, or an unsupported language.
    case unsupported
}

enum SpendingCoach {
    // MARK: Availability

    static var availability: CoachAvailability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .unsupported }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale() ? .available : .unsupported
        case .unavailable(.appleIntelligenceNotEnabled):
            return .turnedOff
        case .unavailable(.modelNotReady):
            return .preparing
        case .unavailable:
            return .unsupported
        }
        #else
        return .unsupported
        #endif
    }

    // MARK: Review

    enum CoachError: Error {
        case unavailable
    }

    /// Writes the period review. Throws when the model is unavailable or the
    /// generation fails; callers keep showing `plainSummary` in that case.
    static func review(for digest: SpendingDigest) async throws -> CoachReview {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availability == .available else { throw CoachError.unavailable }
        let facts = factSheet(for: digest)
        let subjects = tipSubjects(for: digest)
        let request = facts + "\n\n" + reviewRequest(for: digest, ideas: subjects.count)
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: 0.5, maximumResponseTokens: 400)
        // Anything quoting a figure that isn't in the facts was made up
        // (usually a botched sum): the summary falls back to the plain one.
        let known = figures(in: facts)
        func checked(_ text: String) -> String {
            let summary = tidy(text)
            return figures(in: summary).isSubset(of: known) ? summary : plainSummary(for: digest)
        }

        // Nothing worth cutting back on: a review with no tips rather than
        // tips stretched to fit.
        guard !subjects.isEmpty else {
            let response = try await session.respond(to: request, generating: GeneratedSummary.self, options: options)
            return CoachReview(summary: checked(response.content.summary), tips: [], fingerprint: reviewKey(for: digest))
        }

        let response = try await session.respond(to: request, generating: GeneratedReview.self, options: options)
        // The model only picks what each tip is about and names the action;
        // the sentence with the figures is ours. Left to word it, the model
        // relabelled them ("Food & Dining costs ₹1,200").
        var used: Set<String> = []
        let tips = response.content.tips.compactMap { tip -> CoachTip? in
            let title = tip.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, figures(in: title).isEmpty,
                  let subject = match(tip.subject, in: subjects),
                  used.insert(subject.name).inserted
            else { return nil }
            return CoachTip(title: title, detail: subject.fact)
        }
        return CoachReview(summary: checked(response.content.summary), tips: tips, fingerprint: reviewKey(for: digest))
        #else
        throw CoachError.unavailable
        #endif
    }

    /// One practical suggestion for a spending alert, or nil when the model
    /// isn't available or takes too long — the alert then goes out without it.
    static func alertTip(for signal: SpendingSignal, in digest: SpendingDigest) async -> String? {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), availability == .available,
              let subject = alertSubject(for: signal, in: digest)
        else { return nil }
        let places = digest.merchants
            .filter { $0.categoryID == subject.categoryID && subject.categoryID != nil }
            .map { "\($0.name) (\($0.count) times)" }
        var prompt = "\(subject.fact)"
        if !places.isEmpty {
            prompt += " Where it went most often: \(places.joined(separator: ", "))."
        }
        prompt += " Suggest one practical way to spend less on \(subject.name) for the rest of the \(digest.period.unit)."

        // Generous: the first request after a while has to load the model.
        return await withTimeout(seconds: 15) {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: prompt,
                generating: GeneratedNudge.self,
                options: GenerationOptions(temperature: 0.6, maximumResponseTokens: 80)
            )
            let tip = response.content.tip.trimmingCharacters(in: .whitespacesAndNewlines)
            // Asked for no amounts; one that slips in can't be trusted.
            guard figures(in: tip).isEmpty else { throw CoachError.unavailable }
            return tip
        }
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// Test hook: `-previewCoachReview` prints the current period's fact
    /// sheet and the review the model writes from it.
    @MainActor
    static func printPreview(context: ModelContext) async {
        guard let period = SpendingPeriod.current(in: context),
              let digest = SpendingAnalyzer.digest(in: context, period: period)
        else { return }
        print("[Coach] facts:\n\(factSheet(for: digest))")
        do {
            let review = try await review(for: digest)
            print("[Coach] summary: \(review.summary)")
            for tip in review.tips {
                print("[Coach] tip: \(tip.title) — \(tip.detail)")
            }
        } catch {
            print("[Coach] model unavailable: \(error)")
        }
        print("[Coach] done")
    }
    #endif

    // MARK: Plain-language fallback

    /// A one-line summary built without the model — shown while the model
    /// writes, and instead of it when Apple Intelligence isn't available.
    static func plainSummary(for digest: SpendingDigest) -> String {
        let spent = whole(digest.spent)
        let period = digest.period
        let unit = period.unit
        guard digest.hasHistory else {
            return digest.isCurrent
                ? "You've spent \(spent) so far this \(unit). Once you've logged a full \(unit), Finlogue can tell you how that compares to your usual."
                : "You spent \(spent) in \(period.spentInPhrase)."
        }
        if digest.isCurrent, let usual = digest.usualByNow {
            let gap = digest.spent - usual
            let byDay = period.byDayPhrase(digest.dayOfPeriod)
            if abs(gap) < max(usual * 0.05, 1) {
                return "You've spent \(spent) so far — about what you usually have \(byDay)."
            }
            return "You've spent \(spent) so far — \(whole(abs(gap))) \(gap > 0 ? "more" : "less") than you usually have \(byDay)."
        }
        if let usual = digest.usualTotal {
            let gap = digest.spent - usual
            if abs(gap) < max(usual * 0.05, 1) {
                return "You spent \(spent) in \(period.spentInPhrase) — right around your usual \(unit)."
            }
            return "You spent \(spent) in \(period.spentInPhrase) — \(whole(abs(gap))) \(gap > 0 ? "more" : "less") than your usual \(unit)."
        }
        return "You spent \(spent) in \(period.spentInPhrase)."
    }

    // MARK: Prompting

    private static let instructions = """
        You are the spending coach inside Finlogue, a personal finance app. \
        You help the user understand their spending and find realistic ways to save.
        Rules:
        - Use only the facts you are given. Never invent merchants, categories or amounts.
        - Copy amounts exactly as written, including the currency symbol. Never add, subtract or total amounts yourself.
        - Talk to the user as "you". Be warm, direct and brief. No greetings, emojis or exclamation marks.
        - Rent, EMIs, loans, insurance and investments are commitments. Never suggest cutting them.
        - Do not lecture or judge.
        """

    /// The list of ideas is already only what's worth acting on, so a quiet
    /// period gets fewer tips by having fewer ideas.
    private static func reviewRequest(for digest: SpendingDigest, ideas: Int) -> String {
        let unit = digest.period.unit
        let review = digest.isCurrent ? "Review this \(unit) so far" : "Review this finished \(unit)"
        guard ideas > 0 else { return review + "." }
        let when = digest.isCurrent ? "for the rest of it" : "next \(unit)"
        let count = min(ideas, 3)
        return review + " and suggest \(count == 1 ? "one way" : "\(count) ways") to save \(when), "
            + "each about a different idea from the list."
    }

    /// The facts handed to the model, amounts pre-formatted so it never has to
    /// do sums or currency formatting itself.
    static func factSheet(for digest: SpendingDigest) -> String {
        var lines: [String] = []
        let period = digest.period
        let unit = period.unit
        let label = unit == "cycle" ? "Credit card statement cycle" : "Month"
        lines.append(digest.isCurrent
            ? "\(label): \(period.title), day \(digest.dayOfPeriod) of \(digest.periodDays) (in progress)"
            : "\(label): \(period.title) (finished)")
        lines.append("Spent\(digest.isCurrent ? " so far" : ""): \(whole(digest.spent))")
        if digest.isCurrent, let usual = digest.usualByNow {
            lines.append("Usually spent by this day: \(whole(usual))")
            lines.append("Compared with usual: \(difference(digest.spent - usual))")
        }
        if let usual = digest.usualTotal {
            lines.append("Usual whole \(unit): \(whole(usual)) (average of the previous \(digest.baselinePeriods) \(unit)\(digest.baselinePeriods == 1 ? "" : "s"))")
            if !digest.isCurrent {
                lines.append("Compared with usual: \(difference(digest.spent - usual))")
            }
        } else {
            lines.append("Usual: not known yet (less than one full \(unit) of history)")
        }
        if let projected = digest.projectedTotal {
            lines.append("Heading for about \(whole(projected)) by the end of the \(unit)")
        }
        if digest.income > 0 {
            lines.append("Income this \(unit): \(whole(digest.income))")
        }

        lines.append("Stands out: \(standout(in: digest))")

        let listed = digest.categories.filter { $0.spent > 0 || ($0.usualByNow ?? 0) > 0 }.prefix(8)
        if !listed.isEmpty {
            lines.append("")
            lines.append("Categories:")
            // Every figure carries its own label: given a bare list, the
            // model quoted the gap from usual as the amount spent.
            let usualLabel = digest.isCurrent ? "usual by this point" : "usual for a whole \(unit)"
            for category in listed {
                var line = "- \(category.name)"
                if category.isCommitment { line += " [commitment]" }
                line += ": spent \(whole(category.spent)) in \(category.purchaseCount) purchase\(category.purchaseCount == 1 ? "" : "s")"
                if let usual = digest.isCurrent ? category.usualByNow : category.usualTotal {
                    let gap = category.spent - usual
                    if usual > 0, abs(gap) >= usual * 0.1 {
                        line += "; \(usualLabel) \(whole(usual)); spent \(whole(abs(gap))) \(gap > 0 ? "more" : "less") than usual"
                    } else if usual > 0 {
                        line += "; about usual"
                    } else {
                        line += "; new this \(unit)"
                    }
                }
                lines.append(line)
            }
        }

        let budgets = digest.budgets.map { budget in
            "- \(budget.name) budget: \(whole(budget.spent)) of \(whole(budget.limit)) (\(Int((budget.spent / budget.limit * 100).rounded()))% used)"
        }
        if !budgets.isEmpty {
            lines.append("")
            lines.append("Budgets near or over the limit:")
            lines.append(contentsOf: budgets)
        }

        var habits: [String] = []
        for merchant in digest.merchants {
            habits.append("- \(merchant.name): \(merchant.count) times, \(whole(merchant.total)) in total")
        }
        // Only when it's a pattern — handed a low share, the model still
        // builds a tip around it.
        if let weekend = digest.weekendShare, weekend >= Self.notableWeekendShare {
            habits.append("- Weekends: \(Int((weekend * 100).rounded()))% of spending")
        }
        if digest.smallPurchaseCount >= 5 {
            habits.append("- Small purchases under \(whole(digest.smallPurchaseLimit)): \(digest.smallPurchaseCount), \(whole(digest.smallPurchaseTotal)) in total")
        }
        if !habits.isEmpty {
            lines.append("")
            lines.append("Habits:")
            lines.append(contentsOf: habits)
        }

        // Every tip has to be about one of these, so it can't land on a
        // category that's already under its usual.
        let ideas = tipSubjects(for: digest)
        lines.append("")
        if ideas.isEmpty {
            lines.append("Ideas for ways to save: none, spending is in line with usual")
        } else {
            lines.append("Ideas for ways to save (each tip is about one of these):")
            lines.append(contentsOf: ideas.map { "- \($0.name): \($0.fact)" })
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Tip subjects

    /// Something a tip can be about, with the sentence of figures shown
    /// under it already written.
    struct TipSubject: Equatable {
        let name: String
        let fact: String
    }

    /// What's worth cutting back on: everyday categories at least 10% over
    /// their usual, budgets near their limit, and the habits. Categories at
    /// or under usual are left out — telling someone to cook at home when
    /// they're already spending less on food than usual reads as nonsense.
    static func tipSubjects(for digest: SpendingDigest) -> [TipSubject] {
        let unit = digest.period.unit
        let spentIn = digest.isCurrent ? "so far this \(unit)" : "this \(unit)"
        // Too small to bother with: under 3% of a usual period.
        let floor = (digest.usualTotal ?? digest.spent) * 0.03
        func purchases(_ count: Int) -> String { "\(count) purchase\(count == 1 ? "" : "s")" }

        var categories: [TipSubject] = []
        var underUsual: Set<UUID> = []
        for category in digest.categories where !category.isCommitment && category.spent > 0 {
            let spent = "\(whole(category.spent)) on \(category.name) across \(purchases(category.purchaseCount))"
            guard digest.hasHistory else {
                if category.spent >= digest.spent * 0.1 {
                    categories.append(TipSubject(name: category.name, fact: "\(spent) \(spentIn)."))
                }
                continue
            }
            let usual = (digest.isCurrent ? category.usualByNow : category.usualTotal) ?? 0
            let gap = category.spent - usual
            if usual > 0, gap < usual * 0.1 {
                if gap <= -usual * 0.1 { underUsual.insert(category.id) }
                continue
            }
            guard category.spent >= floor else { continue }
            let comparison = usual == 0
                ? "new this \(unit)"
                : "\(whole(gap)) more than \(digest.isCurrent ? "you usually have by now" : "a usual \(unit)")"
            categories.append(TipSubject(name: category.name, fact: "\(spent) — \(comparison)."))
        }

        var subjects = Array(categories.prefix(3))
        // A budget over a category that's already an idea is the same money.
        let named = Set(subjects.map(\.name))
        for budget in digest.budgets where !named.contains(budget.name) {
            let fact = budget.spent >= budget.limit
                ? "\(whole(budget.spent)) against a \(whole(budget.limit)) budget — \(whole(budget.spent - budget.limit)) over."
                : "\(Int((budget.spent / budget.limit * 100).rounded()))% of the \(whole(budget.limit)) budget used."
            subjects.append(TipSubject(name: "\(budget.name) budget", fact: fact))
        }
        let commitments = Set(digest.categories.filter(\.isCommitment).map(\.id))
        for merchant in digest.merchants {
            if let id = merchant.categoryID, commitments.contains(id) || underUsual.contains(id) { continue }
            subjects.append(TipSubject(
                name: merchant.name,
                fact: "\(merchant.count) purchases at \(merchant.name) \(spentIn), \(whole(merchant.total)) in total."
            ))
        }
        if let weekend = digest.weekendShare, weekend >= notableWeekendShare {
            subjects.append(TipSubject(
                name: "Weekends",
                fact: "\(Int((weekend * 100).rounded()))% of your spending \(spentIn) landed on weekends."
            ))
        }
        if digest.smallPurchaseCount >= 5 {
            subjects.append(TipSubject(
                name: "Small purchases",
                fact: "\(digest.smallPurchaseCount) purchases under \(whole(digest.smallPurchaseLimit)) added up to \(whole(digest.smallPurchaseTotal))."
            ))
        }
        return subjects
    }

    /// The subject the model named — exactly, or failing that one whose name
    /// it used inside a longer phrase ("Food & Dining spending").
    private static func match(_ name: String, in subjects: [TipSubject]) -> TipSubject? {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        guard !wanted.isEmpty else { return nil }
        return subjects.first { $0.name.localizedLowercase == wanted }
            ?? subjects.first { wanted.contains($0.name.localizedLowercase) }
    }

    /// What an alert is about, as a sentence of facts.
    static func alertSubject(
        for signal: SpendingSignal, in digest: SpendingDigest
    ) -> (name: String, categoryID: UUID?, fact: String)? {
        let unit = digest.period.unit
        switch signal {
        case .overUsual(let category):
            guard let usual = category.usualTotal else { return nil }
            return (category.name, category.id,
                    "The user has spent \(whole(category.spent)) on \(category.name) this \(unit), more than their usual \(whole(usual)) for a whole \(unit).")
        case .runningAhead(let category):
            guard let usual = category.usualByNow else { return nil }
            return (category.name, category.id,
                    "The user has spent \(whole(category.spent)) on \(category.name) so far this \(unit); by this point they usually spend \(whole(usual)).")
        case .budget(let name, let spent, let limit):
            return (name, nil,
                    "The user has used \(whole(spent)) of their \(whole(limit)) \(name) budget this \(unit).")
        case .underUsual:
            return nil
        }
    }

    // MARK: Cache

    /// Bump when the prompt or output format changes, so reviews written
    /// the old way are replaced rather than served from the cache.
    private static let promptVersion = 7

    /// What a cached review must match to still be current.
    static func reviewKey(for digest: SpendingDigest) -> String {
        "v\(promptVersion)|\(digest.fingerprint)"
    }

    /// Last review per period, so reopening Insights doesn't re-run the model.
    static func cachedReview(for period: SpendingPeriod) -> CoachReview? {
        cache()[period.key]
    }

    static func store(_ review: CoachReview, for period: SpendingPeriod) {
        var reviews = cache()
        reviews[period.key] = review
        // Keep about a year of months and cycles; keys sort by date.
        if reviews.count > 26 {
            for key in reviews.keys.sorted().prefix(reviews.count - 26) {
                reviews[key] = nil
            }
        }
        if let data = try? JSONEncoder().encode(reviews) {
            UserDefaults.standard.set(data, forKey: AppSettings.coachReviewsKey)
        }
    }

    private static func cache() -> [String: CoachReview] {
        guard let data = UserDefaults.standard.data(forKey: AppSettings.coachReviewsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: CoachReview].self, from: data)) ?? [:]
    }

    // MARK: Formatting

    /// Weekend spending worth calling a habit: well over the 2-in-7 share
    /// weekends would get if every day were alike.
    static let notableWeekendShare = 0.35

    /// Every figure of 100 or more in `text`, grouping separators removed —
    /// "₹12,220" and "12220" both become "12220". Small numbers (counts, days,
    /// percentages) are left alone.
    static func figures(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(
            pattern: "[0-9](?:[0-9]|[,.\u{00A0}\u{202F}](?=[0-9]))*"
        ) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return Set(regex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: text) else { return nil }
            let digits = text[tokenRange].filter(\.isNumber)
            guard let value = Int(digits), value >= 100 else { return nil }
            return String(value)
        })
    }

    /// Drops fact-sheet labels the model sometimes copies into its prose.
    private static func tidy(_ text: String) -> String {
        text.replacingOccurrences(of: "What stands out: ", with: "")
            .replacingOccurrences(of: "Stands out: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whole currency units — the precision a coach should talk in.
    static func whole(_ amount: Double) -> String {
        amount.formatted(.currency(code: AppSettings.currencyCode).precision(.fractionLength(0)))
    }

    /// The one thing the summary should mention, decided here rather than by
    /// the model — left to itself it reaches for a story that isn't there.
    private static func standout(in digest: SpendingDigest) -> String {
        guard digest.hasHistory else {
            let top = digest.categories.first { $0.spent > 0 && !$0.isCommitment }
            return top.map { "\($0.name) is the biggest everyday spend at \(whole($0.spent))" }
                ?? "nothing yet"
        }
        if let signal = digest.signals.first {
            switch signal {
            case .overUsual(let category):
                return "\(category.name) at \(whole(category.spent)), already past its usual \(whole(category.usualTotal ?? 0)) for a whole \(digest.period.unit)"
            case .runningAhead(let category):
                return "\(category.name) at \(whole(category.spent)), ahead of the usual \(whole(category.usualByNow ?? 0)) by this point"
            case .budget(let name, let spent, let limit):
                return "the \(name) budget, \(whole(spent)) of \(whole(limit)) used"
            case .underUsual(let category):
                return "\(category.name) at \(whole(category.spent)), well under the usual \(whole(category.usualByNow ?? 0))"
            }
        }
        return "nothing unusual; every category is close to usual"
    }

    /// "₹5,160 more" / "₹900 less" / "about the same".
    private static func difference(_ gap: Double) -> String {
        guard abs(gap) >= 1 else { return "about the same" }
        return "\(whole(abs(gap))) \(gap > 0 ? "more" : "less")"
    }

    static func ordinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    /// Runs `work`, giving up with nil after `seconds`.
    private static func withTimeout(
        seconds: Double, _ work: @escaping @Sendable () async throws -> String
    ) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { try? await work() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

// MARK: - Generable output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct GeneratedReview {
    @Guide(description: "Two short sentences starting with \"You\": first the total compared with usual, then the \"Stands out\" fact in your own words. Quote amounts exactly as given. Neutral and kind, never alarmed.")
    var summary: String

    @Guide(description: "Realistic ways to save, each about a different idea from the \"Ideas for ways to save\" list", .count(1...3))
    var tips: [GeneratedTip]
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedSummary {
    @Guide(description: "Two short sentences starting with \"You\": first the total compared with usual, then the \"Stands out\" fact in your own words. Quote amounts exactly as given. Neutral and kind, never alarmed.")
    var summary: String
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedTip {
    @Guide(description: "The idea this tip is about: one name copied exactly from the \"Ideas for ways to save\" list")
    var subject: String

    @Guide(description: "A short, specific action for that idea, at most six words and without amounts, e.g. \"Cook at home on weeknights\"")
    var title: String
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedNudge {
    @Guide(description: "One practical suggestion in a single sentence of at most 20 words, without any amounts")
    var tip: String
}
#endif
