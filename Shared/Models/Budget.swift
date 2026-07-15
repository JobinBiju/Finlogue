//
//  Budget.swift
//  Finlogue
//

import Foundation
import SwiftData

/// A monthly spending limit for one category.
@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    @Relationship(deleteRule: .nullify) var category: Category?
    var limit: Double
    var updatedAt: Date

    init(id: UUID = UUID(), category: Category? = nil, limit: Double, updatedAt: Date = .now) {
        self.id = id
        self.category = category
        self.limit = limit
        self.updatedAt = updatedAt
    }
}
