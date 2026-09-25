//
//  AppModelContainer.swift
//  Finlogue
//
//  One container for the whole process. App Intents run inside the app's
//  process without launching the UI, so the intent and the app must share a
//  container rather than each opening the same store file.
//

import Foundation
import SwiftData

enum AppModelContainer {
    static let schema = Schema([
        Transaction.self, Account.self, Category.self, Budget.self, RecurringRule.self,
        Person.self, TransactionSplit.self, RecurringSplit.self, CreditGroup.self,
        AccountIdentifier.self, PendingTransaction.self, MerchantRule.self,
    ])

    static let shared: ModelContainer = {
        let configuration = ModelConfiguration("Finlogue-v3", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
