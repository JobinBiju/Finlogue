//
//  AmountInput.swift
//  Finlogue
//
//  Locale-aware live grouping for money text fields (e.g. 1,45,650 in en_IN).
//

import Foundation

enum AmountInput {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func string(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: value)) ?? String(format: "%g", value)
    }

    static func parse(_ text: String) -> Double? {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let raw = text
            .replacingOccurrences(of: groupSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Double(raw)
    }

    /// Re-groups typed input, preserving a partially typed fraction.
    static func reformat(_ text: String) -> String {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var raw = text.replacingOccurrences(of: groupSeparator, with: "")
        raw = String(raw.filter { $0.isNumber || String($0) == decimalSeparator })

        let parts = raw.components(separatedBy: decimalSeparator)
        let integerPart = parts.first ?? ""
        let hasSeparator = parts.count > 1
        let fractionPart = String(parts.dropFirst().joined().prefix(2))

        var result = integerPart
        if !integerPart.isEmpty, let intValue = Double(integerPart) {
            result = string(intValue)
        }
        if hasSeparator {
            result += decimalSeparator + fractionPart
        }
        return result
    }
}
