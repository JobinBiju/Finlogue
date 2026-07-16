//
//  Category.swift
//  Finlogue
//

import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var symbol: String
    var colorHex: String
    var sortOrder: Int
    var updatedAt: Date

    /// Everything that references this category. Declaring the inverses here
    /// lets SwiftData nullify them on delete — without them, deleting a
    /// category leaves dangling references whose reads crash.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Budget.category)
    var budgets: [Budget]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringRule.category)
    var recurringRules: [RecurringRule]? = []

    init(
        id: UUID = UUID(),
        name: String,
        type: TransactionType,
        symbol: String = "tag",
        colorHex: String = "#4F8EF7",
        sortOrder: Int = 0,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.symbol = symbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.updatedAt = updatedAt
    }

    var type: TransactionType {
        get { TransactionType(rawValue: typeRaw) ?? .expense }
        set { typeRaw = newValue.rawValue }
    }
}
