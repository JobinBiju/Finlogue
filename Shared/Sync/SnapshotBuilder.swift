//
//  SnapshotBuilder.swift
//  Finlogue
//
//  Builds phone-side snapshots and applies them watch-side.
//

import Foundation
import SwiftData

enum SnapshotBuilder {
    /// applicationContext payloads must stay under ~65 KB; leave headroom.
    static let maxPayloadBytes = 60_000
    static let maxTransactions = 200

    // MARK: Build (phone)

    @MainActor
    static func build(context: ModelContext) throws -> SyncSnapshot {
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.createdAt)]))
        let categories = try context.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
        let budgets = try context.fetch(FetchDescriptor<Budget>())
        let rules = try context.fetch(FetchDescriptor<RecurringRule>(sortBy: [SortDescriptor(\.name)]))
        let people = try context.fetch(FetchDescriptor<Person>(sortBy: [SortDescriptor(\.name)]))
        var transactionDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        transactionDescriptor.fetchLimit = maxTransactions
        let transactions = try context.fetch(transactionDescriptor)

        // Only ship splits belonging to transactions in the (trimmed) snapshot.
        let transactionIDs = Set(transactions.map(\.id))
        let splits = try context.fetch(FetchDescriptor<TransactionSplit>())
            .filter { $0.transaction.map { transactionIDs.contains($0.id) } ?? false }

        return SyncSnapshot(
            generatedAt: .now,
            currencyCode: AppSettings.currencyCode,
            themeID: ThemeManager.shared.theme.rawValue,
            accounts: accounts.map(AccountDTO.init),
            categories: categories.map(CategoryDTO.init),
            budgets: budgets.map(BudgetDTO.init),
            recurringRules: rules.map(RecurringRuleDTO.init),
            transactions: transactions.map(TransactionDTO.init),
            people: people.map(PersonDTO.init),
            splits: splits.map(TransactionSplitDTO.init)
        )
    }

    /// Encodes the snapshot, trimming oldest transactions until it fits the payload limit.
    static func encode(_ snapshot: SyncSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        var trimmed = snapshot
        var data = try encoder.encode(trimmed)
        while data.count > maxPayloadBytes && !trimmed.transactions.isEmpty {
            trimmed.transactions.removeLast(max(1, trimmed.transactions.count / 10))
            data = try encoder.encode(trimmed)
        }
        return data
    }

    static func decode(_ data: Data) throws -> SyncSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(SyncSnapshot.self, from: data)
    }

    static func encodeTransaction(_ dto: TransactionDTO) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(dto)
    }

    static func decodeTransaction(_ data: Data) throws -> TransactionDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(TransactionDTO.self, from: data)
    }

    // MARK: Apply (watch)

    /// Replaces the local store's contents with the snapshot: upsert everything
    /// present, delete everything missing. Phone is the source of truth.
    @MainActor
    static func apply(_ snapshot: SyncSnapshot, context: ModelContext) throws {
        // Accounts
        let existingAccounts = try context.fetch(FetchDescriptor<Account>())
        var accountsByID: [UUID: Account] = [:]
        for account in existingAccounts {
            if snapshot.accounts.contains(where: { $0.id == account.id }) {
                accountsByID[account.id] = account
            } else {
                context.delete(account)
            }
        }
        for dto in snapshot.accounts {
            let account = accountsByID[dto.id] ?? {
                let created = Account(id: dto.id, name: dto.name, type: dto.type)
                context.insert(created)
                accountsByID[dto.id] = created
                return created
            }()
            account.name = dto.name
            account.type = dto.type
            account.openingBalance = dto.openingBalance
            account.creditLimit = dto.creditLimit
            account.statementDay = dto.statementDay
            account.createdAt = dto.createdAt
            account.updatedAt = dto.updatedAt
        }

        // Categories
        let existingCategories = try context.fetch(FetchDescriptor<Category>())
        var categoriesByID: [UUID: Category] = [:]
        for category in existingCategories {
            if snapshot.categories.contains(where: { $0.id == category.id }) {
                categoriesByID[category.id] = category
            } else {
                context.delete(category)
            }
        }
        for dto in snapshot.categories {
            let category = categoriesByID[dto.id] ?? {
                let created = Category(id: dto.id, name: dto.name, type: dto.type)
                context.insert(created)
                categoriesByID[dto.id] = created
                return created
            }()
            category.name = dto.name
            category.type = dto.type
            category.symbol = dto.symbol
            category.colorHex = dto.colorHex
            category.sortOrder = dto.sortOrder
            category.updatedAt = dto.updatedAt
        }

        // People
        let existingPeople = try context.fetch(FetchDescriptor<Person>())
        var peopleByID: [UUID: Person] = [:]
        for person in existingPeople {
            if snapshot.people.contains(where: { $0.id == person.id }) {
                peopleByID[person.id] = person
            } else {
                context.delete(person)
            }
        }
        for dto in snapshot.people {
            let person = peopleByID[dto.id] ?? {
                let created = Person(id: dto.id, name: dto.name, colorHex: dto.colorHex)
                context.insert(created)
                peopleByID[dto.id] = created
                return created
            }()
            person.name = dto.name
            person.colorHex = dto.colorHex
            person.createdAt = dto.createdAt
            person.updatedAt = dto.updatedAt
        }

        // Transactions
        let existingTransactions = try context.fetch(FetchDescriptor<Transaction>())
        var transactionsByID: [UUID: Transaction] = [:]
        for transaction in existingTransactions {
            if snapshot.transactions.contains(where: { $0.id == transaction.id }) {
                transactionsByID[transaction.id] = transaction
            } else {
                context.delete(transaction)
            }
        }
        for dto in snapshot.transactions {
            let transaction = transactionsByID[dto.id] ?? {
                let created = Transaction(id: dto.id, type: dto.type, name: dto.name, amount: dto.amount)
                context.insert(created)
                transactionsByID[dto.id] = created
                return created
            }()
            transaction.type = dto.type
            transaction.name = dto.name
            transaction.amount = dto.amount
            transaction.charges = dto.charges
            transaction.date = dto.date
            transaction.note = dto.note
            transaction.account = dto.accountID.flatMap { accountsByID[$0] }
            transaction.toAccount = dto.toAccountID.flatMap { accountsByID[$0] }
            transaction.category = dto.categoryID.flatMap { categoriesByID[$0] }
            transaction.person = dto.personID.flatMap { peopleByID[$0] }
            transaction.isSettlement = dto.isSettlement
            transaction.createdAt = dto.createdAt
            transaction.updatedAt = dto.updatedAt
        }

        // Splits (reference transactions + people, so applied after both)
        let existingSplits = try context.fetch(FetchDescriptor<TransactionSplit>())
        var splitsByID: [UUID: TransactionSplit] = [:]
        for split in existingSplits {
            if snapshot.splits.contains(where: { $0.id == split.id }) {
                splitsByID[split.id] = split
            } else {
                context.delete(split)
            }
        }
        for dto in snapshot.splits {
            let split = splitsByID[dto.id] ?? {
                let created = TransactionSplit(id: dto.id, shareAmount: dto.shareAmount)
                context.insert(created)
                splitsByID[dto.id] = created
                return created
            }()
            split.shareAmount = dto.shareAmount
            split.transaction = dto.transactionID.flatMap { transactionsByID[$0] }
            split.person = dto.personID.flatMap { peopleByID[$0] }
        }

        // Budgets
        let existingBudgets = try context.fetch(FetchDescriptor<Budget>())
        var budgetsByID: [UUID: Budget] = [:]
        for budget in existingBudgets {
            if snapshot.budgets.contains(where: { $0.id == budget.id }) {
                budgetsByID[budget.id] = budget
            } else {
                context.delete(budget)
            }
        }
        for dto in snapshot.budgets {
            let budget = budgetsByID[dto.id] ?? {
                let created = Budget(id: dto.id, limit: dto.limit)
                context.insert(created)
                budgetsByID[dto.id] = created
                return created
            }()
            budget.limit = dto.limit
            budget.category = dto.categoryID.flatMap { categoriesByID[$0] }
            budget.updatedAt = dto.updatedAt
        }

        // Recurring rules
        let existingRules = try context.fetch(FetchDescriptor<RecurringRule>())
        var rulesByID: [UUID: RecurringRule] = [:]
        for rule in existingRules {
            if snapshot.recurringRules.contains(where: { $0.id == rule.id }) {
                rulesByID[rule.id] = rule
            } else {
                context.delete(rule)
            }
        }
        for dto in snapshot.recurringRules {
            let rule = rulesByID[dto.id] ?? {
                let created = RecurringRule(id: dto.id, name: dto.name, amount: dto.amount)
                context.insert(created)
                rulesByID[dto.id] = created
                return created
            }()
            rule.name = dto.name
            rule.amount = dto.amount
            rule.type = dto.type
            rule.account = dto.accountID.flatMap { accountsByID[$0] }
            rule.toAccount = dto.toAccountID.flatMap { accountsByID[$0] }
            rule.category = dto.categoryID.flatMap { categoriesByID[$0] }
            rule.frequency = dto.frequency
            rule.dayAnchor = dto.dayAnchor
            rule.endDate = dto.endDate
            rule.remainingInstallments = dto.remainingInstallments
            rule.autoPost = dto.autoPost
            rule.lastPostedDate = dto.lastPostedDate
            rule.isActive = dto.isActive
            rule.updatedAt = dto.updatedAt
        }

        try context.save()

        UserDefaults.standard.set(snapshot.currencyCode, forKey: AppSettings.currencyCodeKey)
        // Follow the phone's theme (applied on the watch, whose root observes it).
        ThemeManager.shared.applySynced(snapshot.themeID)
    }
}
