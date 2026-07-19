//
//  Person.swift
//  Finlogue
//
//  A friend or family member a transaction can be attributed to — e.g. money
//  spent on behalf of someone. Purely a tag for filtering and display; it does
//  not affect balances.
//

import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    /// Settlement (repayment) transactions attributed to this person. Declaring
    /// the inverse here lets SwiftData nullify them on delete instead of leaving
    /// dangling references.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.person)
    var transactions: [Transaction]? = []

    /// This person's shares across all shared transactions. Cascade-deleted
    /// with the person.
    @Relationship(deleteRule: .cascade, inverse: \TransactionSplit.person)
    var splits: [TransactionSplit]? = []

    /// This person's share templates on recurring rules. Not debts.
    @Relationship(deleteRule: .cascade, inverse: \RecurringSplit.person)
    var recurringSplits: [RecurringSplit]? = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = Person.palette[0],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Ledger

    /// Total this person owes you across every shared transaction.
    var owed: Double {
        (splits ?? []).reduce(0) { $0 + $1.shareAmount }
    }

    /// Total this person has paid back (settlement transactions).
    var repaid: Double {
        (transactions ?? [])
            .filter { $0.isSettlement }
            .reduce(0) { $0 + $1.amount }
    }

    /// What's still outstanding. Positive = they owe you; negative = you owe
    /// them (overpaid).
    var outstanding: Double { owed - repaid }

    /// Two-letter initials for the avatar badge.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.joined().uppercased()
    }

    /// Swatch options for person avatars — theme-independent so tags read the
    /// same across palettes.
    static let palette: [String] = [
        "#E8833A", "#3B82F6", "#22C55E", "#EC4899",
        "#8B5CF6", "#EAB308", "#14B8A6", "#EF4444",
    ]

    /// Picks the next colour in the palette given how many people already exist.
    static func color(forIndex index: Int) -> String {
        palette[((index % palette.count) + palette.count) % palette.count]
    }
}
