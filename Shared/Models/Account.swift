//
//  Account.swift
//  Finlogue
//

import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    /// Bank/cash: starting balance. Credit card: opening outstanding (amount
    /// already owed when the account was added to the app).
    var openingBalance: Double
    var creditLimit: Double?
    /// Credit card only: day of month the statement generates (1–31).
    var statementDay: Int?
    /// Credit card only: shared credit-limit pool. When set, `creditLimit` is
    /// ignored and availability is computed against the group's shared limit.
    var creditGroup: CreditGroup?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    /// Transfers where this account is the destination. The transaction itself
    /// belongs to the source account, so deleting this account just nullifies.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.toAccount)
    var incomingTransfers: [Transaction]? = []

    /// Recurring rules that pay *from* this account. Declaring the inverse
    /// here lets SwiftData nullify these on delete — without it, deleting the
    /// account leaves rules pointing at a missing row and reads crash.
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.account)
    var recurringRules: [RecurringRule]? = []

    /// Recurring transfers that pay *into* this account.
    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.toAccount)
    var incomingRecurringTransfers: [RecurringRule]? = []

    init(
        id: UUID = UUID(),
        name: String,
        type: AccountType,
        openingBalance: Double = 0,
        creditLimit: Double? = nil,
        statementDay: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.openingBalance = openingBalance
        self.creditLimit = creditLimit
        self.statementDay = statementDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .bank }
        set { typeRaw = newValue.rawValue }
    }
}

/// Display grouping used wherever accounts are listed.
enum AccountGroup: String, CaseIterable, Identifiable {
    case banks = "Banks"
    case cards = "Cards"
    case others = "Others"

    var id: String { rawValue }

    init(type: AccountType) {
        switch type {
        case .bank: self = .banks
        case .creditCard: self = .cards
        case .cash: self = .others
        }
    }
}

extension Array where Element == Account {
    /// Banks first, then cards, then everything else; empty groups omitted.
    var grouped: [(group: AccountGroup, accounts: [Account])] {
        AccountGroup.allCases.compactMap { group in
            let members = filter { AccountGroup(type: $0.type) == group }
            return members.isEmpty ? nil : (group, members)
        }
    }
}

extension Account {
    private var incomeTotal: Double {
        (transactions ?? [])
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var expenseTotal: Double {
        (transactions ?? [])
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    /// Transfers leaving this account (this account is the source).
    private var transferOutTotal: Double {
        (transactions ?? [])
            .filter { $0.type == .transfer }
            .reduce(0) { $0 + $1.amount }
    }

    /// Fees on this account's own transactions — always an extra outflow,
    /// regardless of transaction type.
    private var chargesTotal: Double {
        (transactions ?? []).reduce(0) { $0 + $1.charges }
    }

    /// Transfers arriving into this account.
    private var transferInTotal: Double {
        (incomingTransfers ?? [])
            .filter { $0.type == .transfer }
            .reduce(0) { $0 + $1.amount }
    }

    /// Bank/cash: openingBalance + income + transfers in − expenses − transfers
    /// out − fees.
    var currentBalance: Double {
        openingBalance + incomeTotal + transferInTotal
            - expenseTotal - transferOutTotal - chargesTotal
    }

    /// Credit card: total outstanding. Opening outstanding plus charges and
    /// fees, minus payments (income on the card or transfers into it).
    var spent: Double {
        max(0, openingBalance + expenseTotal + transferOutTotal + chargesTotal
            - incomeTotal - transferInTotal)
    }

    /// Credit available on this card. For a grouped card this is the whole
    /// remaining shared pool; otherwise its own limit minus outstanding.
    var available: Double? {
        guard type == .creditCard else { return nil }
        if let creditGroup { return creditGroup.available }
        guard let creditLimit else { return nil }
        return creditLimit - spent
    }

    /// The limit governing this card — shared if grouped, else its own.
    var effectiveCreditLimit: Double? {
        creditGroup?.sharedLimit ?? creditLimit
    }

    // MARK: Billing cycle (credit cards with a statement day)

    /// The most recent statement date on or before `now`, derived from
    /// `statementDay` and clamped for short months.
    func lastStatementDate(asOf now: Date = .now, calendar: Calendar = .current) -> Date? {
        guard type == .creditCard, let statementDay else { return nil }
        func statementDate(inMonthOf reference: Date) -> Date? {
            guard let interval = calendar.dateInterval(of: .month, for: reference),
                  let dayCount = calendar.range(of: .day, in: .month, for: reference)?.count
            else { return nil }
            return calendar.date(
                byAdding: .day, value: min(statementDay, dayCount) - 1, to: interval.start
            )
        }
        guard let thisMonth = statementDate(inMonthOf: now) else { return nil }
        if thisMonth <= now { return thisMonth }
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: now) else {
            return nil
        }
        return statementDate(inMonthOf: previousMonth)
    }

    /// Outstanding that was already billed on the last statement, net of
    /// payments made since. nil when no statement day is set.
    var billedOutstanding: Double? {
        guard let statementDate = lastStatementDate() else { return nil }
        let endOfStatementDay = Calendar.current.date(
            byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: statementDate)
        ) ?? statementDate

        let owedAtStatement = (transactions ?? []).reduce(openingBalance) { total, transaction in
            guard transaction.date < endOfStatementDay else { return total }
            switch transaction.type {
            case .expense: return total + transaction.amount + transaction.charges
            case .income: return total - transaction.amount + transaction.charges
            case .transfer: return total + transaction.amount + transaction.charges
            }
        } - (incomingTransfers ?? [])
            .filter { $0.type == .transfer && $0.date < endOfStatementDay }
            .reduce(0) { $0 + $1.amount }

        let paymentsSinceStatement = (transactions ?? [])
            .filter { $0.type == .income && $0.date >= endOfStatementDay }
            .reduce(0) { $0 + $1.amount }
            + (incomingTransfers ?? [])
            .filter { $0.type == .transfer && $0.date >= endOfStatementDay }
            .reduce(0) { $0 + $1.amount }

        return min(max(0, owedAtStatement - paymentsSinceStatement), spent)
    }

    /// Charges made after the last statement (not yet billed).
    var unbilledOutstanding: Double? {
        guard let billed = billedOutstanding else { return nil }
        return max(0, spent - billed)
    }
}
