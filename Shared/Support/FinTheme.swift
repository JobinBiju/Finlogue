//
//  FinTheme.swift
//  Finlogue
//
//  Design tokens from the Finlogue design system (claude.ai/design
//  "Finlogue Redesign"): warm cream canvas, paper cards, coral primary,
//  money-semantic lime/red, large friendly radii, soft warm shadows.
//

import SwiftUI

enum FinTheme {
    // MARK: Brand

    static let coral = Color(hex: "#E85D28")      // primary
    static let coral600 = Color(hex: "#CE4C1C")
    static let amber = Color(hex: "#F3B63D")      // balance card yellow
    static let amber500 = Color(hex: "#E9A21F")

    // MARK: Money semantics

    static let lime100 = Color(hex: "#EAF3CE")
    static let lime300 = Color(hex: "#C0DE64")
    static let lime400 = Color(hex: "#A6CF43")
    static let green = Color(hex: "#55963B")      // positive
    static let red400 = Color(hex: "#E4552B")
    static let red = Color(hex: "#D23F1C")        // negative

    // MARK: Support accents

    static let blue = Color(hex: "#2E6BD6")
    static let violet = Color(hex: "#B96BE0")

    // MARK: Warm neutrals

    static let canvas = Color(hex: "#F3E9DA")     // page background
    static let paper = Color(hex: "#FCF9F3")      // card surface
    static let paperInset = Color(hex: "#F7F2E9") // inset / secondary surface
    static let ink = Color(hex: "#1A1815")        // near-black text / dark pills
    static let ink600 = Color(hex: "#57534B")     // secondary text
    static let ink400 = Color(hex: "#8C877B")     // muted text
    static let line = Color(hex: "#E7DFD1")
    static let lineSoft = Color(hex: "#EFE8DB")
    static let cream = Color(hex: "#F3E9DA")      // text on dark

    // MARK: Soft tinted surfaces

    static let tintLime = Color(hex: "#E4EFC0")
    static let tintPeach = Color(hex: "#F6E0CE")
    static let tintAmber = Color(hex: "#FBEBC7")
    static let tintCoral = Color(hex: "#FBDECF")

    /// Warm diffuse card shadow color.
    static let shadowTint = Color(hex: "#46341E")
}

extension View {
    /// Standard floating paper card: warm off-white, radius 20, soft shadow.
    func finCard(radius: CGFloat = 20) -> some View {
        self
            .background(FinTheme.paper, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: FinTheme.shadowTint.opacity(0.07), radius: 10, x: 0, y: 6)
    }

    /// Micro uppercase section label (design: 12–13pt bold, wide tracking, muted).
    func finSectionLabel() -> some View {
        self
            .font(.system(size: 13, weight: .bold))
            .kerning(0.6)
            .textCase(.uppercase)
            .foregroundStyle(FinTheme.ink400)
    }

    /// Cancels the extra ~16pt inset list section headers get relative to
    /// rows, so custom header content aligns with the card edges.
    func finHeaderAligned() -> some View {
        self.padding(.horizontal, -16)
    }
}
