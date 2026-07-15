//
//  SyncDTOs.swift
//  Finlogue
//
//  Codable snapshots of the SwiftData models. @Model objects cannot cross
//  the WCSession boundary, so everything syncs as these DTOs.
//

import Foundation

struct AccountDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var type: AccountType
    var openingBalance: Double
    var creditLimit: Double?
    var statementDay: Int?
    var createdAt: Date
    var updatedAt: Date

    init(from account: Account) {
        id = account.id
        name = account.name
        type = account.type
        openingBalance = account.openingBalance
        creditLimit = account.creditLimit
        statementDay = account.statementDay
        createdAt = account.createdAt
        updatedAt = account.updatedAt
    }
}

struct CategoryDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var type: TransactionType
    var symbol: String
    var colorHex: String
    var sortOrder: Int
    var updatedAt: Date

    init(from category: Category) {
        id = category.id
        name = category.name
        type = category.type
        symbol = category.symbol
        colorHex = category.colorHex
        sortOrder = category.sortOrder
        updatedAt = category.updatedAt
    }
}

struct TransactionDTO: Codable, Identifiable {
    var id: UUID
    var type: TransactionType
    var name: String
    var amount: Double
    var date: Date
    var note: String?
    var accountID: UUID?
    var toAccountID: UUID?
    var categoryID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(from transaction: Transaction) {
        id = transaction.id
        type = transaction.type
        name = transaction.name
        amount = transaction.amount
        date = transaction.date
        note = transaction.note
        accountID = transaction.account?.id
        toAccountID = transaction.toAccount?.id
        categoryID = transaction.category?.id
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }
}

struct BudgetDTO: Codable, Identifiable {
    var id: UUID
    var categoryID: UUID?
    var limit: Double
    var updatedAt: Date

    init(from budget: Budget) {
        id = budget.id
        categoryID = budget.category?.id
        limit = budget.limit
        updatedAt = budget.updatedAt
    }
}

struct RecurringRuleDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Double
    var type: TransactionType
    var accountID: UUID?
    var toAccountID: UUID?
    var categoryID: UUID?
    var frequency: RecurrenceFrequency
    var dayAnchor: Date
    var endDate: Date?
    var remainingInstallments: Int?
    var autoPost: Bool
    var lastPostedDate: Date?
    var isActive: Bool
    var updatedAt: Date

    init(from rule: RecurringRule) {
        id = rule.id
        name = rule.name
        amount = rule.amount
        type = rule.type
        accountID = rule.account?.id
        toAccountID = rule.toAccount?.id
        categoryID = rule.category?.id
        frequency = rule.frequency
        dayAnchor = rule.dayAnchor
        endDate = rule.endDate
        remainingInstallments = rule.remainingInstallments
        autoPost = rule.autoPost
        lastPostedDate = rule.lastPostedDate
        isActive = rule.isActive
        updatedAt = rule.updatedAt
    }
}

/// The full phone → watch state transfer. Latest snapshot always wins.
struct SyncSnapshot: Codable {
    var version: Int = 1
    var generatedAt: Date
    var currencyCode: String
    var accounts: [AccountDTO]
    var categories: [CategoryDTO]
    var budgets: [BudgetDTO]
    var recurringRules: [RecurringRuleDTO]
    var transactions: [TransactionDTO]
}

enum SyncKeys {
    static let snapshot = "snapshot"
    static let newTransaction = "newTransaction"
    static let request = "request"
    static let requestSnapshot = "requestSnapshot"
}
