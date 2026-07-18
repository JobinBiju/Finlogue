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
    /// Friend or family member this transaction is on behalf of. Display/filter
    /// tag only; does not affect balances.
    var person: Person?
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
}
