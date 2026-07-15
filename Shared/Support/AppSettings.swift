//
//  AppSettings.swift
//  Finlogue
//

import Foundation

enum AppSettings {
    static let currencyCodeKey = "displayCurrencyCode"
    static let defaultCurrencyCode = "INR"
    static let lastAccountIDKey = "lastAccountID"
    static let didSeedCategoriesKey = "didSeedDefaultCategories"

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: currencyCodeKey) ?? defaultCurrencyCode
    }

    /// Curated list for the Settings currency picker.
    static let supportedCurrencyCodes: [String] = [
        "INR", "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "SGD", "AED", "CHF", "CNY",
    ]
}
