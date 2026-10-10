//
//  SpendingAnalyzer.swift
//  Finlogue
//
//  Deterministic month analysis behind the spending coach: what you've spent,
//  what's usual for you, and where the two part ways. Every number the coach
//  shows or says comes from here — the language model only puts it into
//  words, because small on-device models are unreliable at arithmetic.
//

import Foundation
import SwiftData

/// One category's spend this period next to your usual for it.
struct CategoryDigest: Identifiable {
    let id: UUID
    let name: String
    let symbol: String
    let colorHex: String
    let spent: Double
    let purchaseCount: Int
    /// Average spend over a whole baseline period; nil without history.
    let usualTotal: Double?
    /// Average spend by the same day of the period — the fair comparison
    /// while one is in progress (rent on the 1st doesn't look like a spike).
    let usualByNow: Double?
    /// Rent, EMIs, investments: commitments, not something to cut back on.
    let isCommitment: Bool
}

/// A place you keep going back to.
struct MerchantHabit: Identifiable {
    let name: String
    let categoryID: UUID?
    let count: Int
    let total: Double
    var id: String { name }
}

/// Something worth pointing out, ordered by how much it matters.
enum SpendingSignal: Identifiable {
    /// Already past a whole usual period for this category.
    case overUsual(CategoryDigest)
    /// Well ahead of where you usually are by this day.
    case runningAhead(CategoryDigest)
    /// A budget at 80% or more.
    case budget(name: String, spent: Double, limit: Double)
    /// Noticeably under your usual — worth a pat on the back.
    case underUsual(CategoryDigest)

    var id: String {
        switch self {
        case .overUsual(let category): "over-\(category.id)"
        case .runningAhead(let category): "ahead-\(category.id)"
        case .budget(let name, _, _): "budget-\(name)"
        case .underUsual(let category): "under-\(category.id)"
        }
    }

    var isGoodNews: Bool {
        if case .underUsual = self { return true }
        return false
    }
}

struct SpendingDigest {
    let period: SpendingPeriod
    let isCurrent: Bool
    /// Days of the period covered so far, counting today (all of it once
    /// it's over).
    let dayOfPeriod: Int
    let periodDays: Int

    let spent: Double
    let income: Double
    let transactionCount: Int
    /// Full periods of history the "usual" figures are averaged over (0–3).
    let baselinePeriods: Int
    let usualTotal: Double?
    let usualByNow: Double?

    let categories: [CategoryDigest]
    let signals: [SpendingSignal]
    /// Every budget at 80% or more, even ones `signals` leaves out.
    let budgets: [(name: String, spent: Double, limit: Double)]
    let merchants: [MerchantHabit]
    /// Share of spending that landed on Saturdays and Sundays (0–1).
    let weekendShare: Double?
    let smallPurchaseLimit: Double
    let smallPurchaseCount: Int
    let smallPurchaseTotal: Double

    var hasHistory: Bool { baselinePeriods > 0 }

    /// Where the period should end up if the rest of it goes like your usual
    /// rest-of-period — steadier than extrapolating the daily rate, which
    /// overreacts to rent and EMIs landing early.
    var projectedTotal: Double? {
        guard isCurrent, let usualTotal, let usualByNow else { return nil }
        return spent + max(0, usualTotal - usualByNow)
    }

    /// Changes whenever the analysis would read differently — the coach's
    /// cache key.
    var fingerprint: String {
        let signalKey = signals.map(\.id).joined(separator: ",")
        return "\(period.key)|\(transactionCount)|\(Int(spent.rounded()))|\(baselinePeriods)|\(signalKey)"
    }
}

enum SpendingAnalyzer {
    /// How far back "usual" looks.
    static let baselineWindow = 3

    static func digest(
        in context: ModelContext, period: SpendingPeriod, now: Date = .now,
        calendar: Calendar = .current
    ) -> SpendingDigest? {
        let interval = period.interval
        let periodDays = period.dayCount(calendar: calendar)
        let isCurrent = period.contains(now)
        let elapsed = calendar.dateComponents(
            [.day], from: interval.start, to: calendar.startOfDay(for: now)
        ).day ?? 0
        let dayOfPeriod = isCurrent ? min(elapsed + 1, periodDays) : periodDays

        let items = InsightsService.transactions(in: context, interval: interval)
        let expenses = items.filter { $0.type == .expense && $0.myShare > 0 }
        let income = items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let spent = expenses.reduce(0) { $0 + $1.myShare }

        // Baseline: the full periods just before this one, starting no earlier
        // than the period you began logging in (a half-logged first period
        // would drag "usual" down) and skipping periods with nothing logged.
        let firstLogged = earliestTransactionDate(in: context)
        var baseline: [(whole: [Transaction], byNow: [Transaction])] = []
        for offset in 1...baselineWindow {
            guard let previous = period.previous(offset, calendar: calendar),
                  let firstLogged,
                  let grace = calendar.date(byAdding: .day, value: 3, to: previous.interval.start),
                  firstLogged <= grace
            else { break }
            let previousExpenses = InsightsService.transactions(in: context, interval: previous.interval)
                .filter { $0.type == .expense && $0.myShare > 0 }
            guard !previousExpenses.isEmpty else { continue }
            let cutoff = calendar.date(
                byAdding: .day,
                value: min(dayOfPeriod, previous.dayCount(calendar: calendar)),
                to: previous.interval.start
            ) ?? previous.interval.end
            baseline.append((previousExpenses, previousExpenses.filter { $0.date < cutoff }))
        }

        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        let usualTotal = average(baseline.map { $0.whole.reduce(0) { $0 + $1.myShare } })
        let usualByNow = average(baseline.map { $0.byNow.reduce(0) { $0 + $1.myShare } })

        // Per category, over every category seen this period or in the baseline.
        let uncategorizedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        func key(_ transaction: Transaction) -> UUID { transaction.category?.id ?? uncategorizedID }
        func sum(_ list: [Transaction], _ id: UUID) -> Double {
            list.filter { key($0) == id }.reduce(0) { $0 + $1.myShare }
        }
        var seen: [UUID: Transaction] = [:]
        for transaction in expenses + baseline.flatMap(\.whole) where seen[key(transaction)] == nil {
            seen[key(transaction)] = transaction
        }
        let categories: [CategoryDigest] = seen.map { id, sample in
            let name = sample.category?.name ?? "Uncategorized"
            return CategoryDigest(
                id: id,
                name: name,
                symbol: sample.category?.symbol ?? "questionmark",
                colorHex: sample.category?.colorHex ?? "#94A3B8",
                spent: sum(expenses, id),
                purchaseCount: expenses.filter { key($0) == id }.count,
                usualTotal: baseline.isEmpty ? nil : average(baseline.map { sum($0.whole, id) }),
                usualByNow: baseline.isEmpty ? nil : average(baseline.map { sum($0.byNow, id) }),
                isCommitment: isCommitment(name)
            )
        }
        .sorted { $0.spent > $1.spent }

        let budgets = isCurrent ? InsightsService.budgetProgress(in: context, interval: interval) : []
        let signals = signals(
            categories: categories, budgets: budgets, usualTotal: usualTotal,
            isCurrent: isCurrent, dayOfPeriod: dayOfPeriod, periodDays: periodDays
        )

        // Habits.
        let merchants = Dictionary(grouping: expenses) {
            $0.name.trimmingCharacters(in: .whitespaces).localizedLowercase
        }
        .compactMap { _, group -> MerchantHabit? in
            guard group.count >= 3, let first = group.first else { return nil }
            return MerchantHabit(
                name: first.name.trimmingCharacters(in: .whitespaces),
                categoryID: first.category?.id,
                count: group.count,
                total: group.reduce(0) { $0 + $1.myShare }
            )
        }
        .sorted { ($0.count, $0.total) > ($1.count, $1.total) }
        .prefix(3)

        let weekendSpend = expenses.filter { calendar.isDateInWeekend($0.date) }.reduce(0) { $0 + $1.myShare }
        // "Small" scales with how much you spend: 1% of a usual period.
        let smallLimit = roundedDown((usualTotal ?? spent) * 0.01)
        let small = expenses.filter { $0.myShare < smallLimit }

        return SpendingDigest(
            period: period,
            isCurrent: isCurrent,
            dayOfPeriod: dayOfPeriod,
            periodDays: periodDays,
            spent: spent,
            income: income,
            transactionCount: items.count,
            baselinePeriods: baseline.count,
            usualTotal: usualTotal,
            usualByNow: usualByNow,
            categories: categories,
            signals: signals,
            budgets: budgets
                .filter { $0.budget.limit > 0 && $0.spent >= $0.budget.limit * 0.8 }
                .map { (budgetName($0.budget), $0.spent, $0.budget.limit) },
            merchants: Array(merchants),
            weekendShare: spent > 0 && expenses.count >= 5 ? weekendSpend / spent : nil,
            smallPurchaseLimit: smallLimit,
            smallPurchaseCount: small.count,
            smallPurchaseTotal: small.reduce(0) { $0 + $1.myShare }
        )
    }

    // MARK: Signals

    private static func signals(
        categories: [CategoryDigest],
        budgets: [(budget: Budget, spent: Double)],
        usualTotal: Double?,
        isCurrent: Bool,
        dayOfPeriod: Int,
        periodDays: Int
    ) -> [SpendingSignal] {
        var over: [SpendingSignal] = []
        var ahead: [SpendingSignal] = []
        var under: [SpendingSignal] = []

        // Ignore categories too small to matter: under 3% of a usual period.
        let floor = (usualTotal ?? 0) * 0.03
        for category in categories {
            guard let usual = category.usualTotal, let usualByNow = category.usualByNow,
                  usual >= floor, usual > 0
            else { continue }
            // Putting more into investments isn't overspending.
            let canOverspend = !category.name.localizedLowercase.contains("invest")
            if canOverspend, category.spent > usual * 1.05, category.spent - usual >= floor * 0.5 {
                over.append(.overUsual(category))
            } else if canOverspend, isCurrent, usualByNow > 0,
                      category.spent >= usualByNow * 1.3,
                      category.spent - usualByNow >= max(floor, usual * 0.15) {
                ahead.append(.runningAhead(category))
            } else if !category.isCommitment,
                      dayOfPeriod * 2 >= periodDays,
                      category.spent <= usualByNow * 0.6,
                      usualByNow - category.spent >= max(floor, usual * 0.2) {
                under.append(.underUsual(category))
            }
        }

        // A budget whose categories are all past their usual period already has
        // a row saying so — a second row for the same money is noise.
        let pastUsual = Set(over.compactMap { signal -> UUID? in
            if case .overUsual(let category) = signal { return category.id }
            return nil
        })
        let budgetSignals: [SpendingSignal] = budgets.compactMap { entry in
            guard entry.budget.limit > 0, entry.spent >= entry.budget.limit * 0.8 else { return nil }
            let covered = Set(entry.budget.effectiveCategories.map(\.id))
            guard covered.isEmpty || !covered.isSubset(of: pastUsual) else { return nil }
            return .budget(name: budgetName(entry.budget), spent: entry.spent, limit: entry.budget.limit)
        }

        func overshoot(_ signal: SpendingSignal) -> Double {
            switch signal {
            case .overUsual(let c): c.spent - (c.usualTotal ?? 0)
            case .runningAhead(let c): c.spent - (c.usualByNow ?? 0)
            case .underUsual(let c): (c.usualByNow ?? 0) - c.spent
            case .budget(_, let spent, let limit): spent - limit
            }
        }
        return over.sorted { overshoot($0) > overshoot($1) }
            + budgetSignals.sorted { overshoot($0) > overshoot($1) }
            + ahead.sorted { overshoot($0) > overshoot($1) }
            + under.sorted { overshoot($0) > overshoot($1) }
    }

    /// Down to a figure people say out loud: 539 → 500, 1,230 → 1,000.
    private static func roundedDown(_ value: Double) -> Double {
        guard value >= 10 else { return max(1, value.rounded()) }
        let step = pow(10, floor(log10(value))) / 2
        return floor(value / step) * step
    }

    static func budgetName(_ budget: Budget) -> String {
        let names = budget.effectiveCategories.map(\.name)
        switch names.count {
        case 0: return "Budget"
        case 1, 2: return names.joined(separator: " & ")
        default: return "\(names[0]) +\(names.count - 1)"
        }
    }

    /// Fixed commitments and savings — never framed as something to cut.
    static func isCommitment(_ categoryName: String) -> Bool {
        let name = categoryName.localizedLowercase
        return ["rent", "emi", "loan", "invest", "insurance", "sip"].contains { name.contains($0) }
    }

    private static func earliestTransactionDate(in context: ModelContext) -> Date? {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.date
    }
}
