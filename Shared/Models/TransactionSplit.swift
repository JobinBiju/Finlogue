//
//  TransactionSplit.swift
//  Finlogue
//
//  One friend's share of a shared transaction. "You" are never a split row —
//  your share is the remainder (transaction total minus everyone else's shares).
//  Shares feed each person's owed/repaid ledger; they do not move balances.
//

import Foundation
import SwiftData

@Model
final class TransactionSplit {
    @Attribute(.unique) var id: UUID
    var transaction: Transaction?
    var person: Person?
    /// What this person owes for this transaction.
    var shareAmount: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        transaction: Transaction? = nil,
        person: Person? = nil,
        shareAmount: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.transaction = transaction
        self.person = person
        self.shareAmount = shareAmount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
