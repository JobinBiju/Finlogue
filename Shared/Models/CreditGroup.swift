//
//  CreditGroup.swift
//  Finlogue
//
//  A shared credit limit across an issuer's cards (e.g. Flipkart Axis + Axis
//  Ace draw from one pool). Cards keep their own outstanding and billing cycle;
//  only the limit and available credit are shared.
//

import Foundation
import SwiftData

@Model
final class CreditGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sharedLimit: Double
    var createdAt: Date
    var updatedAt: Date

    /// Cards drawing from this shared limit. Nullified (not deleted) when the
    /// group is removed, so the cards revert to standalone.
    @Relationship(deleteRule: .nullify, inverse: \Account.creditGroup)
    var cards: [Account]? = []

    init(
        id: UUID = UUID(),
        name: String,
        sharedLimit: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sharedLimit = sharedLimit
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension CreditGroup {
    /// Combined outstanding across every card in the group.
    var totalSpent: Double {
        (cards ?? []).reduce(0) { $0 + $1.spent }
    }

    /// Remaining credit in the shared pool, available to any member card.
    var available: Double {
        sharedLimit - totalSpent
    }

    var utilization: Double {
        sharedLimit > 0 ? totalSpent / sharedLimit : 0
    }
}
