//
//  Transaction.swift
//  Finlogue
//

import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var name: String
    var amount: Double
    /// Extra fees on top of `amount` (e.g. credit-card surcharge). Always an
    /// additional outflow from the source account; `amount + charges` is the
    /// total deducted.
    var charges: Double = 0
    var date: Date
    var note: String?
    /// Source account; for transfers this is the "from" side.
    var account: Account?
    /// Destination account — set only for transfers.
    var toAccount: Account?
    @Relationship(deleteRule: .nullify) var category: Category?
    /// For a settlement (repayment) transaction, the person who paid you back.
    /// Expense sharing is tracked via `splits`, not this field.
    var person: Person?
    /// True when this is a repayment logged from a person's ledger. Excluded
    /// from income/insights, but still moves the account balance like income.
    var isSettlement: Bool = false
    /// Friends' shares of this transaction. Cascade-deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \TransactionSplit.transaction)
    var splits: [TransactionSplit]? = []
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: TransactionType,
        name: String,
        amount: Double,
        charges: Double = 0,
        date: Date = .now,
        note: String? = nil,
        account: Account? = nil,
        toAccount: Account? = nil,
        category: Category? = nil,
        person: Person? = nil,
        isSettlement: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.name = name
        self.amount = amount
        self.charges = charges
        self.date = date
        self.note = note
        self.account = account
        self.toAccount = toAccount
        self.category = category
        self.person = person
        self.isSettlement = isSettlement
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }

    /// Positive for income, negative for expense, zero for transfers
    /// (a transfer is net-neutral across the user's own accounts).
    var signedAmount: Double {
        switch type {
        case .income: amount
        case .expense: -amount
        case .transfer: 0
        }
    }

    // MARK: Sharing

    /// Full outlay including any fee — the amount split among participants.
    var splitTotal: Double { amount + charges }

    /// Sum of what everyone else owes on this transaction.
    var othersShare: Double {
        (splits ?? []).reduce(0) { $0 + $1.shareAmount }
    }

    /// Whether this transaction is split with anyone.
    var isSplit: Bool { !(splits ?? []).isEmpty }

    /// Your own portion of the outlay — the remainder after everyone else's
    /// shares. This is the only value that counts as your spending in insights.
    var myShare: Double { max(0, splitTotal - othersShare) }
}
