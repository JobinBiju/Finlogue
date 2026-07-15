//
//  CurrencyFormatter.swift
//  Finlogue
//

import Foundation

enum CurrencyFormatter {
    /// "₹1,250.00" — full currency string in the user's display currency.
    static func string(_ amount: Double, code: String = AppSettings.currencyCode) -> String {
        amount.formatted(.currency(code: code).precision(.fractionLength(0...2)))
    }

    /// "+₹500" / "−₹120" — signed, for transaction rows.
    static func signedString(_ signedAmount: Double, code: String = AppSettings.currencyCode) -> String {
        let formatted = string(abs(signedAmount), code: code)
        return signedAmount < 0 ? "−\(formatted)" : "+\(formatted)"
    }

    /// The bare symbol for the current display currency, e.g. "₹".
    static func symbol(code: String = AppSettings.currencyCode) -> String {
        let locale = Locale.availableIdentifiers
            .lazy
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? code
    }
}
