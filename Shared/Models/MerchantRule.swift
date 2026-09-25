//
//  MerchantRule.swift
//  Finlogue
//

import Foundation
import SwiftData

/// Learned mapping from a merchant string in a bank SMS to a category and a
/// nicer display name.
///
/// Written whenever the user confirms or recategorises an imported transaction,
/// so the same merchant needs reviewing only once. Matching is a
/// case-insensitive substring test against the normalised merchant text — the
/// raw SMS merchant is noisy ("SWIGGY LIMITED BANGALORE IN") and a substring
/// pattern ("swiggy") survives that noise better than an exact match.
@Model
final class MerchantRule {
    @Attribute(.unique) var id: UUID
    /// Lowercased needle matched against the parsed merchant string.
    var pattern: String
    /// Name to use for the transaction, e.g. "Swiggy".
    var displayName: String
    /// Resolved lazily by ID so deleting a category can't leave a dangling
    /// relationship in the graph.
    var categoryID: UUID?
    /// How many times this rule has fired — used to prefer more established
    /// rules when several patterns match.
    var hitCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        pattern: String,
        displayName: String,
        categoryID: UUID? = nil,
        hitCount: Int = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.pattern = pattern.lowercased()
        self.displayName = displayName
        self.categoryID = categoryID
        self.hitCount = hitCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
