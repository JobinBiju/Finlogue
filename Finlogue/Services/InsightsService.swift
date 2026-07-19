//
//  InsightsService.swift
//  Finlogue
//

import Foundation
import SwiftData

struct CategoryTotal: Identifiable {
    let id: UUID
    let name: String
    let colorHex: String
    let symbol: String
    let total: Double
}

struct MonthlyTotal: Identifiable {
    let month: Date
    let income: Double
    let expense: Double
    var id: Date { month }
}

struct DailyTotal: Identifiable {
    let day: Date
    let expense: Double
    var id: Date { day }
}

enum InsightsService {
    /// Transactions in `month`, excluding settlement (repayment) transactions.
    /// Only your own share of a shared expense counts toward analytics — see
    /// `Transaction.myShare` — so split-out amounts you'll be paid back are
    /// never treated as your spending.
    static func transactions(
        in context: ModelContext, month: Date, calendar: Calendar = .current
    ) -> [Transaction] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return ((try? context.fetch(descriptor)) ?? []).filter { !$0.isSettlement }
    }

    /// Expense totals per category for one month, largest first. Uses each
    /// transaction's own share, so split-out amounts are left out.
    static func categoryTotals(in context: ModelContext, month: Date) -> [CategoryTotal] {
        let expenses = transactions(in: context, month: month)
            .filter { $0.type == .expense && $0.myShare > 0 }
        var totals: [UUID: CategoryTotal] = [:]
        let uncategorizedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        for transaction in expenses {
            let key = transaction.category?.id ?? uncategorizedID
            let existing = totals[key]?.total ?? 0
            totals[key] = CategoryTotal(
                id: key,
                name: transaction.category?.name ?? "Uncategorized",
                colorHex: transaction.category?.colorHex ?? "#94A3B8",
                symbol: transaction.category?.symbol ?? "questionmark",
                total: existing + transaction.myShare
            )
        }
        return totals.values.sorted { $0.total > $1.total }
    }

    /// Income vs expense for the last `months` months (oldest first).
    static func monthlySeries(
        in context: ModelContext, months: Int, endingAt reference: Date = .now
    ) -> [MonthlyTotal] {
        let calendar = Calendar.current
        return (0..<months).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: reference)
            else { return nil }
            let items = transactions(in: context, month: month)
            let monthStart = calendar.dateInterval(of: .month, for: month)?.start ?? month
            return MonthlyTotal(
                month: monthStart,
                income: items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount },
                expense: items.filter { $0.type == .expense }.reduce(0) { $0 + $1.myShare }
            )
        }
    }

    /// Cumulative daily spend inside one month (for the trend line).
    static func dailySpend(in context: ModelContext, month: Date) -> [DailyTotal] {
        let calendar = Calendar.current
        let expenses = transactions(in: context, month: month).filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.date) }
        var running = 0.0
        return grouped.keys.sorted().map { day in
            running += grouped[day]?.reduce(0) { $0 + $1.myShare } ?? 0
            return DailyTotal(day: day, expense: running)
        }
    }

    /// Spend so far this month against each budget.
    static func budgetProgress(in context: ModelContext, month: Date = .now) -> [(budget: Budget, spent: Double)] {
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        let totals = categoryTotals(in: context, month: month)
        return budgets.map { budget in
            let spent = totals.first { $0.id == budget.category?.id }?.total ?? 0
            return (budget, spent)
        }
        .sorted { ($0.spent / max($0.budget.limit, 1)) > ($1.spent / max($1.budget.limit, 1)) }
    }
}
