//
//  AppSettings.swift
//  Finlogue
//

import Foundation

enum AppSettings {
    static let currencyCodeKey = "displayCurrencyCode"
    static let defaultCurrencyCode = "INR"
    static let lastAccountIDKey = "lastAccountID"
    static let themeKey = "appTheme"
    // Bump the suffix whenever the store name changes so the fresh store
    // re-seeds its default categories.
    static let didSeedCategoriesKey = "didSeedDefaultCategories-v3"

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: currencyCodeKey) ?? defaultCurrencyCode
    }

    /// Curated list for the Settings currency picker.
    static let supportedCurrencyCodes: [String] = [
        "INR", "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "SGD", "AED", "CHF", "CNY",
    ]
}
