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

struct PersonDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var updatedAt: Date

    init(from person: Person) {
        id = person.id
        name = person.name
        colorHex = person.colorHex
        createdAt = person.createdAt
        updatedAt = person.updatedAt
    }
}

struct TransactionDTO: Codable, Identifiable {
    var id: UUID
    var type: TransactionType
    var name: String
    var amount: Double
    var charges: Double
    var date: Date
    var note: String?
    var accountID: UUID?
    var toAccountID: UUID?
    var categoryID: UUID?
    var personID: UUID?
    var createdAt: Date
    var updatedAt: Date

    init(from transaction: Transaction) {
        id = transaction.id
        type = transaction.type
        name = transaction.name
        amount = transaction.amount
        charges = transaction.charges
        date = transaction.date
        note = transaction.note
        accountID = transaction.account?.id
        toAccountID = transaction.toAccount?.id
        categoryID = transaction.category?.id
        personID = transaction.person?.id
        createdAt = transaction.createdAt
        updatedAt = transaction.updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, name, amount, charges, date, note
        case accountID, toAccountID, categoryID, personID, createdAt, updatedAt
    }

    // Custom decode so snapshots from older builds (no charges/personID) still
    // load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(TransactionType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        charges = try container.decodeIfPresent(Double.self, forKey: .charges) ?? 0
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        accountID = try container.decodeIfPresent(UUID.self, forKey: .accountID)
        toAccountID = try container.decodeIfPresent(UUID.self, forKey: .toAccountID)
        categoryID = try container.decodeIfPresent(UUID.self, forKey: .categoryID)
        personID = try container.decodeIfPresent(UUID.self, forKey: .personID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
    /// Active theme identifier so the watch follows the phone's theme.
    var themeID: String = AppTheme.tino.rawValue
    var accounts: [AccountDTO]
    var categories: [CategoryDTO]
    var budgets: [BudgetDTO]
    var recurringRules: [RecurringRuleDTO]
    var transactions: [TransactionDTO]
    var people: [PersonDTO] = []

    private enum CodingKeys: String, CodingKey {
        case version, generatedAt, currencyCode, themeID
        case accounts, categories, budgets, recurringRules, transactions, people
    }

    init(
        version: Int = 1,
        generatedAt: Date,
        currencyCode: String,
        themeID: String = AppTheme.tino.rawValue,
        accounts: [AccountDTO],
        categories: [CategoryDTO],
        budgets: [BudgetDTO],
        recurringRules: [RecurringRuleDTO],
        transactions: [TransactionDTO],
        people: [PersonDTO] = []
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.currencyCode = currencyCode
        self.themeID = themeID
        self.accounts = accounts
        self.categories = categories
        self.budgets = budgets
        self.recurringRules = recurringRules
        self.transactions = transactions
        self.people = people
    }

    // Tolerate snapshots from older builds that predate `people`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        themeID = try container.decodeIfPresent(String.self, forKey: .themeID)
            ?? AppTheme.tino.rawValue
        accounts = try container.decode([AccountDTO].self, forKey: .accounts)
        categories = try container.decode([CategoryDTO].self, forKey: .categories)
        budgets = try container.decode([BudgetDTO].self, forKey: .budgets)
        recurringRules = try container.decode([RecurringRuleDTO].self, forKey: .recurringRules)
        transactions = try container.decode([TransactionDTO].self, forKey: .transactions)
        people = try container.decodeIfPresent([PersonDTO].self, forKey: .people) ?? []
    }
}

enum SyncKeys {
    static let snapshot = "snapshot"
    static let newTransaction = "newTransaction"
    static let request = "request"
    static let requestSnapshot = "requestSnapshot"
}
