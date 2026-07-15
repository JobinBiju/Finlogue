//
//  Enums.swift
//  Finlogue
//

import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case transfer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        }
    }

    /// Categories only apply to money in/out, not to moves between own accounts.
    static var categorizable: [TransactionType] { [.income, .expense] }
}

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case bank
    case creditCard
    case cash

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: "Bank"
        case .creditCard: "Credit Card"
        case .cash: "Cash"
        }
    }

    var symbol: String {
        switch self {
        case .bank: "building.columns"
        case .creditCard: "creditcard"
        case .cash: "banknote"
        }
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}
