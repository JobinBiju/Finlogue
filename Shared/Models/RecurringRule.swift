//
//  RecurringRule.swift
//  Finlogue
//

import Foundation
import SwiftData

/// An auto-mandate: subscription, EMI/loan auto-pay, or any repeating payment.
@Model
final class RecurringRule {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    var typeRaw: String
    /// Source account; for transfer rules this is the "from" side.
    var account: Account?
    /// Destination account — set only for transfer rules.
    var toAccount: Account?
    @Relationship(deleteRule: .nullify) var category: Category?
    var frequencyRaw: String
    /// Start date; the due day-of-period is derived from it.
    var dayAnchor: Date
    var endDate: Date?
    /// For loans/EMIs. nil = indefinite mandate (e.g. a subscription).
    var remainingInstallments: Int?
    /// true = post the transaction automatically when due; false = ask for confirmation.
    var autoPost: Bool
    var lastPostedDate: Date?
    var isActive: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        type: TransactionType = .expense,
        account: Account? = nil,
        toAccount: Account? = nil,
        category: Category? = nil,
        frequency: RecurrenceFrequency = .monthly,
        dayAnchor: Date = .now,
        endDate: Date? = nil,
        remainingInstallments: Int? = nil,
        autoPost: Bool = true,
        lastPostedDate: Date? = nil,
        isActive: Bool = true,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.typeRaw = type.rawValue
        self.account = account
        self.toAccount = toAccount
        self.category = category
        self.frequencyRaw = frequency.rawValue
        self.dayAnchor = dayAnchor
        self.endDate = endDate
        self.remainingInstallments = remainingInstallments
        self.autoPost = autoPost
        self.lastPostedDate = lastPostedDate
        self.isActive = isActive
        self.updatedAt = updatedAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }
}

extension RecurringRule {
    /// The next occurrence strictly after `lastPostedDate` (or the anchor itself if never posted).
    func nextDueDate(calendar: Calendar = .current) -> Date? {
        guard isActive else { return nil }
        if let remaining = remainingInstallments, remaining <= 0 { return nil }

        var due = dayAnchor
        if let lastPosted = lastPostedDate {
            var next = dayAnchor
            var steps = 1
            while next <= lastPosted {
                guard let advanced = calendar.date(
                    byAdding: frequency.calendarComponent, value: steps, to: dayAnchor
                ) else { return nil }
                next = advanced
                steps += 1
            }
            due = next
        }
        if let endDate, due > endDate { return nil }
        return due
    }
}
