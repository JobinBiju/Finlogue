//
//  ExpenseTracker.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import Foundation
import SwiftUI
import SwiftData

class ExpenseTrackerViewModel: ObservableObject {
    @Published var showAddTransaction = false
    @Published var selectedTransactionType: TransactionType = .expense
    @Published var selectedCategory: String = ""
    @Published var amount: String = ""
    @Published var name: String = ""
    @Published var selectedAccount: Account?
    @Published var transactionDate: Date = Date()
    
    func resetForm() {
        selectedTransactionType = .expense
        selectedCategory = ""
        amount = ""
        name = ""
        selectedAccount = nil
        transactionDate = Date()
    }
    
    func saveTransaction(context: ModelContext, categories: [Category], accounts: [Account]) {
        guard let amountValue = Double(amount),
              let account = selectedAccount,
              !selectedCategory.isEmpty else { return }
        
        let transaction = Transaction(
            type: selectedTransactionType,
            name: name,
            category: selectedCategory,
            amount: amountValue,
            account: account,
            date: transactionDate
        )
        
        // Update account balance
        account.balance += selectedTransactionType == .income ? amountValue : -amountValue
        
        context.insert(transaction)
        try? context.save()
        resetForm()
    }
    
    func deleteTransaction(_ transaction: Transaction, context: ModelContext) {
        context.delete(transaction)
        try? context.save()
    }
}
