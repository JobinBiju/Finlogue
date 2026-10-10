//
//  SpendingPeriod.swift
//  Finlogue
//
//  The stretch of time the spending coach reads: a calendar month, or a
//  credit card's statement cycle. Cycles come from `BillingCycle`, the same
//  dates Insights shows.
//

import Foundation
import SwiftData

/// Card statement cycles, anchored on the statement day and clamped for short
/// months (a statement on the 31st falls on Feb 28).
enum BillingCycle {
    static func statementDate(
        day: Int, inMonthOf reference: Date, calendar: Calendar = .current
    ) -> Date? {
        guard let month = calendar.dateInterval(of: .month, for: reference),
              let dayCount = calendar.range(of: .day, in: .month, for: reference)?.count
        else { return nil }
        return calendar.date(byAdding: .day, value: min(day, dayCount) - 1, to: month.start)
    }

    /// The cycle that opens on the statement date in `month`'s month and runs
    /// to the next statement date.
    static func cycle(
        statementDay: Int, startingInMonthOf month: Date, calendar: Calendar = .current
    ) -> DateInterval? {
        guard let start = statementDate(day: statementDay, inMonthOf: month, calendar: calendar),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: month),
              let end = statementDate(day: statementDay, inMonthOf: nextMonth, calendar: calendar)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// The cycle shown for `month`: the one opening on that month's statement
    /// date. For the current month the cycle rolls over only *after* the
    /// statement day — with a statement on the 15th, through Sep 15 you're
    /// still in the Aug 15 – Sep 15 cycle; Sep 15 – Oct 15 starts on the 16th.
    static func cycle(
        statementDay: Int, overlapping month: Date, now: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval? {
        var cycleMonth = month
        if calendar.isDate(month, equalTo: now, toGranularity: .month),
           let statementDate = statementDate(day: statementDay, inMonthOf: month, calendar: calendar),
           calendar.startOfDay(for: now) <= statementDate,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: month) {
            cycleMonth = previousMonth
        }
        return cycle(statementDay: statementDay, startingInMonthOf: cycleMonth, calendar: calendar)
    }
}

struct SpendingPeriod: Equatable {
    enum Kind: Equatable {
        case month
        case cycle(statementDay: Int)
    }

    let kind: Kind
    let interval: DateInterval

    static func month(containing date: Date, calendar: Calendar = .current) -> SpendingPeriod? {
        calendar.dateInterval(of: .month, for: date).map { SpendingPeriod(kind: .month, interval: $0) }
    }

    static func cycle(
        statementDay: Int, overlapping month: Date, now: Date = .now
    ) -> SpendingPeriod? {
        BillingCycle.cycle(statementDay: statementDay, overlapping: month, now: now)
            .map { SpendingPeriod(kind: .cycle(statementDay: statementDay), interval: $0) }
    }

    /// What alerts follow: the card cycle when a card has a statement day,
    /// otherwise the calendar month. Strictly the cycle containing `now` — on
    /// the statement day itself Insights still shows the cycle that just
    /// closed, but that day's spending already counts toward the next one.
    static func current(in context: ModelContext, now: Date = .now) -> SpendingPeriod? {
        guard let statementDay = primaryStatementDay(in: context) else {
            return month(containing: now)
        }
        let calendar = Calendar.current
        for offset in [0, -1] {
            guard let month = calendar.date(byAdding: .month, value: offset, to: now),
                  let interval = BillingCycle.cycle(statementDay: statementDay, startingInMonthOf: month)
            else { continue }
            let period = SpendingPeriod(kind: .cycle(statementDay: statementDay), interval: interval)
            if period.contains(now) { return period }
        }
        return month(containing: now)
    }

    /// The card whose cycle Insights and Budgets use: the first credit card by
    /// name that has a statement day.
    static func primaryStatementDay(in context: ModelContext) -> Int? {
        let accounts = (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))) ?? []
        return accounts.first { $0.type == .creditCard && $0.statementDay != nil }?.statementDay
    }

    /// The same kind of period, `count` before this one.
    func previous(_ count: Int, calendar: Calendar = .current) -> SpendingPeriod? {
        guard let anchor = calendar.date(byAdding: .month, value: -count, to: interval.start) else { return nil }
        switch kind {
        case .month:
            return .month(containing: anchor, calendar: calendar)
        case .cycle(let statementDay):
            return BillingCycle.cycle(statementDay: statementDay, startingInMonthOf: anchor, calendar: calendar)
                .map { SpendingPeriod(kind: kind, interval: $0) }
        }
    }

    func dayCount(calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 30
    }

    func contains(_ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }

    // MARK: Wording

    /// "month" / "cycle".
    var unit: String {
        if case .cycle = kind { return "cycle" }
        return "month"
    }

    /// "September 2026" / "18 Sep – 18 Oct".
    var title: String {
        switch kind {
        case .month:
            return interval.start.formatted(.dateTime.month(.wide).year())
        case .cycle:
            let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
            return "\(interval.start.formatted(format)) – \(interval.end.formatted(format))"
        }
    }

    /// Ends "You spent ₹X in …": "September" / "the 18 Aug – 18 Sep cycle".
    var spentInPhrase: String {
        switch kind {
        case .month: interval.start.formatted(.dateTime.month(.wide))
        case .cycle: "the \(title) cycle"
        }
    }

    /// "by the 30th" / "by day 13 of the cycle".
    func byDayPhrase(_ day: Int) -> String {
        switch kind {
        case .month: "by the \(SpendingCoach.ordinal(day))"
        case .cycle: "by day \(day) of the cycle"
        }
    }

    /// Identifies the period in caches and alert bookkeeping; sorts by date.
    var key: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: interval.start)
        switch kind {
        case .month:
            return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        case .cycle:
            return String(format: "%04d-%02d-%02d-cycle", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }
    }
}
