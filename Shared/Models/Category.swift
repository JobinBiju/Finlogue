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
