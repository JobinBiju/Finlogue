//
//  TransactionStore.swift
//  Finlogue
//
//  Single mutation choke point: every write saves the context and pushes a
//  fresh snapshot to the watch.
//

import Foundation
import SwiftData

@MainActor
final class TransactionStore: ObservableObject {
    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        seedDefaultCategoriesIfNeeded()
        backfillCategoryIfMissing(
            name: "Investments", type: .expense,
            symbol: "chart.line.uptrend.xyaxis", colorHex: "#0EA5E9"
        )
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedSampleData") {
            seedSampleData()
        }
        #endif
    }

    func onAppBecameActive() {
        RecurringEngine.processDueRules(store: self)
        PhoneSyncEngine.shared.pushSnapshot()
    }

    // MARK: Transactions

    func addTransaction(
        type: TransactionType,
        name: String,
        amount: Double,
        charges: Double = 0,
        date: Date,
        note: String?,
        account: Account?,
        toAccount: Account? = nil,
        category: Category?,
        person: Person? = nil
    ) {
        let transaction = Transaction(
            type: type, name: name, amount: amount,
            charges: max(0, charges), date: date,
            note: note, account: account,
            toAccount: type == .transfer ? toAccount : nil,
            category: type == .transfer ? nil : category,
            person: person
        )
        context.insert(transaction)
        persist()
    }

    func updateTransaction(
        _ transaction: Transaction,
        type: TransactionType,
        name: String,
        amount: Double,
        charges: Double = 0,
        date: Date,
        note: String?,
        account: Account?,
        toAccount: Account? = nil,
        category: Category?,
        person: Person? = nil
    ) {
        transaction.type = type
        transaction.name = name
        transaction.amount = amount
        transaction.charges = max(0, charges)
        transaction.date = date
        transaction.note = note
        transaction.account = account
        transaction.toAccount = type == .transfer ? toAccount : nil
        transaction.category = type == .transfer ? nil : category
        transaction.person = person
        transaction.updatedAt = .now
        persist()
    }

    func delete(_ transaction: Transaction) {
        context.delete(transaction)
        persist()
    }

    // MARK: Accounts

    func saveAccount(
        _ account: Account?,
        name: String,
        type: AccountType,
        openingBalance: Double,
        creditLimit: Double?,
        statementDay: Int? = nil
    ) {
        let day = type == .creditCard ? statementDay : nil
        if let account {
            account.name = name
            account.type = type
            account.openingBalance = openingBalance
            account.creditLimit = creditLimit
            account.statementDay = day
            account.updatedAt = .now
        } else {
            context.insert(Account(
                name: name, type: type,
                openingBalance: openingBalance, creditLimit: creditLimit,
                statementDay: day
            ))
        }
        persist()
    }

    func delete(_ account: Account) {
        context.delete(account)
        persist()
    }

    // MARK: Categories

    func saveCategory(
        _ category: Category?,
        name: String,
        type: TransactionType,
        symbol: String,
        colorHex: String
    ) {
        if let category {
            category.name = name
            category.type = type
            category.symbol = symbol
            category.colorHex = colorHex
            category.updatedAt = .now
        } else {
            let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
            context.insert(Category(
                name: name, type: type, symbol: symbol, colorHex: colorHex, sortOrder: count
            ))
        }
        persist()
    }

    func delete(_ category: Category) {
        context.delete(category)
        persist()
    }

    // MARK: People

    @discardableResult
    func savePerson(_ person: Person?, name: String, colorHex: String) -> Person {
        if let person {
            person.name = name
            person.colorHex = colorHex
            person.updatedAt = .now
            persist()
            return person
        } else {
            let count = (try? context.fetchCount(FetchDescriptor<Person>())) ?? 0
            let created = Person(
                name: name,
                colorHex: colorHex.isEmpty ? Person.color(forIndex: count) : colorHex
            )
            context.insert(created)
            persist()
            return created
        }
    }

    func delete(_ person: Person) {
        context.delete(person)
        persist()
    }

    // MARK: Budgets

    func saveBudget(_ budget: Budget?, category: Category?, limit: Double) {
        if let budget {
            budget.category = category
            budget.limit = limit
            budget.updatedAt = .now
        } else {
            context.insert(Budget(category: category, limit: limit))
        }
        persist()
    }

    func delete(_ budget: Budget) {
        context.delete(budget)
        persist()
    }

    // MARK: Recurring rules

    func saveRecurringRule(
        _ rule: RecurringRule?,
        name: String,
        amount: Double,
        type: TransactionType,
        account: Account?,
        toAccount: Account? = nil,
        category: Category?,
        frequency: RecurrenceFrequency,
        dayAnchor: Date,
        remainingInstallments: Int?,
        autoPost: Bool
    ) {
        let destination = type == .transfer ? toAccount : nil
        let ruleCategory = type == .transfer ? nil : category
        if let rule {
            rule.name = name
            rule.amount = amount
            rule.type = type
            rule.account = account
            rule.toAccount = destination
            rule.category = ruleCategory
            rule.frequency = frequency
            rule.dayAnchor = dayAnchor
            rule.remainingInstallments = remainingInstallments
            rule.autoPost = autoPost
            rule.updatedAt = .now
        } else {
            context.insert(RecurringRule(
                name: name, amount: amount, type: type, account: account,
                toAccount: destination, category: ruleCategory,
                frequency: frequency, dayAnchor: dayAnchor,
                remainingInstallments: remainingInstallments, autoPost: autoPost
            ))
        }
        persist()
    }

    func delete(_ rule: RecurringRule) {
        context.delete(rule)
        persist()
    }

    /// Posts one due occurrence of a rule as a real transaction.
    func postOccurrence(of rule: RecurringRule, on dueDate: Date) {
        let transaction = Transaction(
            type: rule.type,
            name: rule.name,
            amount: rule.amount,
            date: dueDate,
            note: "Auto: \(rule.frequency.label.lowercased()) mandate",
            account: rule.account,
            toAccount: rule.toAccount,
            category: rule.category
        )
        context.insert(transaction)
        rule.lastPostedDate = dueDate
        if let remaining = rule.remainingInstallments {
            rule.remainingInstallments = remaining - 1
            if remaining - 1 <= 0 {
                rule.isActive = false
            }
        }
        rule.updatedAt = .now
        persist()
    }

    // MARK: Shared

    func persist() {
        do {
            try context.save()
        } catch {
            print("TransactionStore.persist failed: \(error)")
        }
        PhoneSyncEngine.shared.pushSnapshot()
    }

    private func seedDefaultCategoriesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppSettings.didSeedCategoriesKey) else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existing == 0 else {
            defaults.set(true, forKey: AppSettings.didSeedCategoriesKey)
            return
        }
        let seeds: [(String, TransactionType, String, String)] = [
            ("Food & Dining", .expense, "fork.knife", "#F97316"),
            ("Groceries", .expense, "cart", "#22C55E"),
            ("Transport", .expense, "car", "#3B82F6"),
            ("Shopping", .expense, "bag", "#EC4899"),
            ("Bills & Utilities", .expense, "bolt", "#EAB308"),
            ("Entertainment", .expense, "film", "#8B5CF6"),
            ("Health", .expense, "cross.case", "#EF4444"),
            ("Rent", .expense, "house", "#14B8A6"),
            ("EMI & Loans", .expense, "indianrupeesign.circle", "#64748B"),
            ("Investments", .expense, "chart.line.uptrend.xyaxis", "#0EA5E9"),
            ("Salary", .income, "briefcase", "#22C55E"),
            ("Refunds", .income, "arrow.uturn.backward.circle", "#3B82F6"),
            ("Other Income", .income, "plus.circle", "#8B5CF6"),
        ]
        for (index, seed) in seeds.enumerated() {
            context.insert(Category(
                name: seed.0, type: seed.1, symbol: seed.2, colorHex: seed.3, sortOrder: index
            ))
        }
        try? context.save()
        defaults.set(true, forKey: AppSettings.didSeedCategoriesKey)
    }

    /// Inserts a default category on installs that were seeded before it existed.
    private func backfillCategoryIfMissing(
        name: String, type: TransactionType, symbol: String, colorHex: String
    ) {
        let existing = (try? context.fetch(FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == name }
        ))) ?? []
        guard existing.isEmpty else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        context.insert(Category(
            name: name, type: type, symbol: symbol, colorHex: colorHex, sortOrder: count
        ))
        try? context.save()
    }

    #if DEBUG
    /// Test fixture: `-seedSampleData` launch argument fills the store with
    /// two months of realistic data. Runs once per install.
    private func seedSampleData() {
        let existing = (try? context.fetchCount(FetchDescriptor<Transaction>())) ?? 0
        guard existing == 0 else { return }
        let categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        func category(_ name: String) -> Category? {
            categories.first { $0.name == name }
        }

        let bank = Account(name: "HDFC Savings", type: .bank, openingBalance: 50_000)
        let card = Account(
            name: "Axis Credit Card", type: .creditCard,
            creditLimit: 100_000, statementDay: 10
        )
        let federal = Account(name: "Federal Bank", type: .bank, openingBalance: 15_000)
        let cash = Account(name: "Wallet", type: .cash, openingBalance: 2_000)
        [bank, card, federal, cash].forEach { context.insert($0) }

        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }

        let samples: [(TransactionType, String, Double, Int, String?, Account)] = [
            (.income, "Salary", 85_000, 44, "Salary", bank),
            (.income, "Salary", 85_000, 14, "Salary", bank),
            (.expense, "Rent", 22_000, 43, "Rent", bank),
            (.expense, "Rent", 22_000, 13, "Rent", bank),
            (.expense, "Swiggy dinner", 460, 36, "Food & Dining", card),
            (.expense, "BigBasket", 2_350, 32, "Groceries", card),
            (.expense, "Uber to office", 240, 28, "Transport", cash),
            (.expense, "Electricity bill", 1_850, 25, "Bills & Utilities", bank),
            (.expense, "Movie night", 800, 20, "Entertainment", card),
            (.expense, "Myntra order", 3_200, 16, "Shopping", card),
            (.expense, "Pharmacy", 540, 11, "Health", cash),
            (.expense, "Swiggy lunch", 320, 8, "Food & Dining", card),
            (.expense, "Groceries", 1_780, 6, "Groceries", card),
            (.expense, "Petrol", 2_000, 4, "Transport", card),
            (.expense, "Coffee", 180, 2, "Food & Dining", cash),
            (.expense, "Zepto order", 640, 1, "Groceries", card),
        ]
        for sample in samples {
            context.insert(Transaction(
                type: sample.0, name: sample.1, amount: sample.2,
                date: daysAgo(sample.3),
                account: sample.5,
                category: sample.4.flatMap(category)
            ))
        }
        // A friend/family member and a couple of transactions on their behalf,
        // plus a credit-card surcharge example.
        let rahul = Person(name: "Rahul", colorHex: Person.color(forIndex: 0))
        context.insert(rahul)
        context.insert(Transaction(
            type: .expense, name: "Concert tickets", amount: 4_500, charges: 90,
            date: daysAgo(9), account: card, category: category("Entertainment"), person: rahul
        ))
        context.insert(Transaction(
            type: .expense, name: "Flight fee", amount: 3_200, charges: 250,
            date: daysAgo(5), account: card, category: category("Transport")
        ))

        // Transfers: card bill payment and a savings sweep between banks.
        context.insert(Transaction(
            type: .transfer, name: "Card bill payment", amount: 8_000,
            date: daysAgo(3), account: bank, toAccount: card
        ))
        context.insert(Transaction(
            type: .transfer, name: "Savings sweep", amount: 20_000,
            date: daysAgo(13), account: bank, toAccount: federal
        ))

        context.insert(Budget(category: category("Food & Dining"), limit: 3_000))
        context.insert(Budget(category: category("Groceries"), limit: 4_000))
        context.insert(Budget(category: category("Shopping"), limit: 2_500))

        context.insert(RecurringRule(
            name: "Netflix", amount: 649, category: category("Entertainment"),
            frequency: .monthly, dayAnchor: daysAgo(-3), autoPost: true
        ))
        context.insert(RecurringRule(
            name: "Car EMI", amount: 12_500, account: bank, category: category("EMI & Loans"),
            frequency: .monthly, dayAnchor: daysAgo(-5),
            remainingInstallments: 18, autoPost: false
        ))
        try? context.save()
    }
    #endif
}
