//
//  ColorHex.swift
//  Finlogue
//

import SwiftUI

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            (r, g, b) = (0.31, 0.56, 0.97)
        }
        self.init(red: r, green: g, blue: b)
    }
}
