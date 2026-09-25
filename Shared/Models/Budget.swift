//
//  Budget.swift
//  Finlogue
//

import Foundation
import SwiftData

/// A monthly spending limit for one or more categories (e.g. Food + Groceries).
@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    /// Legacy single category — kept for migration of stores created before
    /// multi-category budgets. Read through `effectiveCategories`.
    @Relationship(deleteRule: .nullify) var category: Category?
    @Relationship(deleteRule: .nullify) var categories: [Category]? = []
    var limit: Double
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: Category? = nil,
        categories: [Category] = [],
        limit: Double,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.category = category
        self.categories = categories
        self.limit = limit
        self.updatedAt = updatedAt
    }

    /// The categories this budget covers, falling back to the legacy single one.
    var effectiveCategories: [Category] {
        if let categories, !categories.isEmpty { return categories }
        return [category].compactMap { $0 }
    }
}
