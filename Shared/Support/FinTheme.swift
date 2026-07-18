//
//  FinTheme.swift
//  Finlogue
//
//  Design tokens from the Finlogue design system (claude.ai/design
//  "Finlogue Redesign"): warm cream canvas, paper cards, coral primary,
//  money-semantic lime/red, large friendly radii, soft warm shadows.
//

import SwiftUI

/// Color tokens resolved against the currently-active theme palette.
/// Screens keep using `FinTheme.coral` etc.; switching the theme changes
/// what these return (see `ThemeManager` / `ThemePalette`).
enum FinTheme {
    private static var p: ThemePalette { ThemeManager.activePalette }

    // MARK: Brand
    static var coral: Color { Color(hex: p.coral) }        // primary
    static var coral600: Color { Color(hex: p.coral600) }
    static var amber: Color { Color(hex: p.amber) }        // balance card
    static var amber500: Color { Color(hex: p.amber500) }

    // MARK: Money semantics
    static var lime100: Color { Color(hex: p.lime100) }
    static var lime300: Color { Color(hex: p.lime300) }
    static var lime400: Color { Color(hex: p.lime400) }
    static var green: Color { Color(hex: p.green) }        // positive
    static var red400: Color { Color(hex: p.red400) }
    static var red: Color { Color(hex: p.red) }            // negative

    // MARK: Support accents
    static var blue: Color { Color(hex: p.blue) }
    static var violet: Color { Color(hex: p.violet) }

    // MARK: Neutrals
    static var canvas: Color { Color(hex: p.canvas) }      // page background
    static var paper: Color { Color(hex: p.paper) }        // card surface
    static var paperInset: Color { Color(hex: p.paperInset) }
    static var ink: Color { Color(hex: p.ink) }            // near-black text
    static var ink600: Color { Color(hex: p.ink600) }      // secondary text
    static var ink400: Color { Color(hex: p.ink400) }      // muted text
    static var line: Color { Color(hex: p.line) }
    static var lineSoft: Color { Color(hex: p.lineSoft) }
    static var cream: Color { Color(hex: p.cream) }        // text on dark

    // MARK: Soft tinted surfaces
    static var tintLime: Color { Color(hex: p.tintLime) }
    static var tintPeach: Color { Color(hex: p.tintPeach) }
    static var tintAmber: Color { Color(hex: p.tintAmber) }
    static var tintCoral: Color { Color(hex: p.tintCoral) }

    // MARK: Effects & misc
    static var shadowTint: Color { Color(hex: p.shadowTint) }
    static var watchGradientTop: Color { Color(hex: p.watchGradientTop) }
    static var slate: Color { Color(hex: p.slate) }        // transfer chips
    static var mutedIcon: Color { Color(hex: p.mutedIcon) } // uncategorized icon
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
