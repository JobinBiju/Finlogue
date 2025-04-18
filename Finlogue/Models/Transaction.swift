//
//  Transaction.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI
import SwiftData

enum TransactionType: String, Codable {
    case income = "Income"
    case expense = "Expense"
}

@Model
class Transaction {
    var id: UUID = UUID()
    var type: TransactionType
    var name: String
    var category: String
    var amount: Double
    var account: Account
    var date: Date
    
    init(type: TransactionType, name: String, category: String, amount: Double, account: Account, date: Date) {
        self.type = type
        self.name = name
        self.category = category
        self.amount = amount
        self.account = account
        self.date = date
    }
}
