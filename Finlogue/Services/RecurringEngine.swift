//
//  RecurringEngine.swift
//  Finlogue
//
//  Posts due occurrences of recurring rules (mandates, EMIs, subscriptions).
//  Runs on launch and whenever the app becomes active. Catch-up safe: each
//  missed period is posted exactly once, keyed off lastPostedDate.
//

import Foundation
import SwiftData

@MainActor
enum RecurringEngine {
    static func processDueRules(store: TransactionStore, now: Date = .now) {
        let rules = (try? store.context.fetch(
            FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive })
        )) ?? []

        for rule in rules where rule.autoPost {
            // Post every missed occurrence up to today, one per period.
            var safety = 0
            while let due = rule.nextDueDate(), due <= now, rule.isActive, safety < 120 {
                store.postOccurrence(of: rule, on: due)
                safety += 1
            }
        }
    }

    /// Rules with a due date inside the next `days` days — shown as "Upcoming"
    /// on Home; non-autoPost ones get a confirm button there.
    static func upcomingRules(
        in context: ModelContext, within days: Int = 7, now: Date = .now
    ) -> [(rule: RecurringRule, dueDate: Date)] {
        let rules = (try? context.fetch(
            FetchDescriptor<RecurringRule>(predicate: #Predicate { $0.isActive })
        )) ?? []
        guard let horizon = Calendar.current.date(byAdding: .day, value: days, to: now) else {
            return []
        }
        return rules
            .compactMap { rule in
                guard let due = rule.nextDueDate(), due <= horizon else { return nil }
                return (rule, due)
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}
