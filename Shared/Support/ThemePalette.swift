//
//  ThemePalette.swift
//  Finlogue
//
//  Runtime-swappable color themes. Every screen reads colors through
//  `FinTheme.*`, which resolves against the currently-active palette here.
//  Add a new theme by adding an `AppTheme` case and its `ThemePalette`.
//

import SwiftUI

/// A full set of color tokens for one theme. Values are hex strings so a
/// palette reads as a concise, reviewable block.
struct ThemePalette {
    // Brand
    let coral: String       // primary accent
    let coral600: String
    let amber: String       // balance / savings card
    let amber500: String

    // Money semantics
    let lime100: String
    let lime300: String
    let lime400: String
    let green: String       // positive / income
    let red400: String
    let red: String         // negative / expense

    // Support accents
    let blue: String
    let violet: String

    // Neutrals (text, surfaces, borders)
    let canvas: String      // page background
    let paper: String       // card surface
    let paperInset: String  // inset / secondary surface
    let ink: String         // near-black text / dark pills
    let ink600: String      // secondary text
    let ink400: String      // muted text
    let line: String
    let lineSoft: String
    let cream: String       // text on dark

    // Soft tinted surfaces
    let tintLime: String
    let tintPeach: String
    let tintAmber: String
    let tintCoral: String

    // Effects & misc
    let shadowTint: String
    let watchGradientTop: String  // top of the watch home gradient
    let slate: String             // transfer chips, neutral icon backing
    let mutedIcon: String         // uncategorized icon backing
}

/// The available themes. Raw value is the persisted / synced identifier.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case tino
    case plum
    case olive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tino: "Tino"
        case .plum: "Plum"
        case .olive: "Olive"
        }
    }

    /// A one-line description shown in the theme picker.
    var subtitle: String {
        switch self {
        case .tino: "Warm cream & coral"
        case .plum: "Ghost-white & plum"
        case .olive: "Cornsilk & olive"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .tino: .tino
        case .plum: .plum
        case .olive: .olive
        }
    }
}

extension ThemePalette {
    /// The original warm cream + coral design system.
    static let tino = ThemePalette(
        coral: "#E85D28", coral600: "#CE4C1C",
        amber: "#F3B63D", amber500: "#E9A21F",
        lime100: "#EAF3CE", lime300: "#C0DE64", lime400: "#A6CF43",
        green: "#55963B", red400: "#E4552B", red: "#D23F1C",
        blue: "#2E6BD6", violet: "#B96BE0",
        canvas: "#F5EDE1", paper: "#FCF9F3", paperInset: "#F7F2E9",
        ink: "#1A1815", ink600: "#57534B", ink400: "#8C877B",
        line: "#E7DFD1", lineSoft: "#EFE8DB", cream: "#F3E9DA",
        tintLime: "#E4EFC0", tintPeach: "#F6E0CE",
        tintAmber: "#FBEBC7", tintCoral: "#FBDECF",
        shadowTint: "#46341E", watchGradientTop: "#E85D28",
        slate: "#64748B", mutedIcon: "#94A3B8"
    )

    /// Plum — ghost-white canvas, plum/magenta primary. Design overrides only
    /// the primary, canvas, surfaces, text ramp, borders and money semantics;
    /// warm amber/lime accents and tints are kept from the base.
    static let plum = ThemePalette(
        coral: "#DA4167", coral600: "#B93456",
        amber: "#F3B63D", amber500: "#E9A21F",
        lime100: "#EAF3CE", lime300: "#C0DE64", lime400: "#A6CF43",
        green: "#2F8F5B", red400: "#D64545", red: "#D64545",
        blue: "#2E6BD6", violet: "#B96BE0",
        canvas: "#F5F5F8", paper: "#FFFFFF", paperInset: "#EFE6EE",
        ink: "#000000", ink600: "#3D2645", ink400: "#6B5673",
        line: "#E3DBE6", lineSoft: "#EFE9F0", cream: "#F0EFF4",
        tintLime: "#E4EFC0", tintPeach: "#F6E0CE",
        tintAmber: "#FBEBC7", tintCoral: "#FBDECF",
        shadowTint: "#832161", watchGradientTop: "#DA4167",
        slate: "#64748B", mutedIcon: "#94A3B8"
    )

    /// Olive — cornsilk canvas, copperwood primary, olive-leaf greens. Same
    /// override scope as Plum; warm amber/lime accents kept from the base.
    static let olive = ThemePalette(
        coral: "#BC6C25", coral600: "#9C581E",
        amber: "#F3B63D", amber500: "#E9A21F",
        lime100: "#EAF3CE", lime300: "#C0DE64", lime400: "#A6CF43",
        green: "#5A7D2B", red400: "#B5462A", red: "#B5462A",
        blue: "#2E6BD6", violet: "#B96BE0",
        canvas: "#FFF9DD", paper: "#FFFDF2", paperInset: "#EEF0DD",
        ink: "#283618", ink600: "#606C38", ink400: "#7A8253",
        line: "#DFE3C8", lineSoft: "#EEF0DD", cream: "#FEFAE0",
        tintLime: "#E4EFC0", tintPeach: "#F6E0CE",
        tintAmber: "#FBEBC7", tintCoral: "#FBDECF",
        shadowTint: "#606C38", watchGradientTop: "#BC6C25",
        slate: "#64748B", mutedIcon: "#94A3B8"
    )
}

/// Owns the active theme: persists it, exposes it for SwiftUI observation,
/// and keeps a fast global cache that `FinTheme` reads on every color access.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Global cache read by `FinTheme.*` — updated in lockstep with `theme`.
    static private(set) var activePalette: ThemePalette = ThemePalette.tino

    @Published private(set) var theme: AppTheme

    private init() {
        #if DEBUG
        // Test hook: `-theme <id>` forces a theme at launch.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-theme"),
           arguments.indices.contains(index + 1),
           let forced = AppTheme(rawValue: arguments[index + 1]) {
            theme = forced
            ThemeManager.activePalette = forced.palette
            return
        }
        #endif
        let stored = UserDefaults.standard.string(forKey: AppSettings.themeKey)
        let resolved = stored.flatMap(AppTheme.init(rawValue:)) ?? .tino
        theme = resolved
        ThemeManager.activePalette = resolved.palette
    }

    /// Change the theme, persist it, and refresh the color cache. On iOS the
    /// caller also pushes a snapshot so the watch follows.
    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        ThemeManager.activePalette = newTheme.palette
        UserDefaults.standard.set(newTheme.rawValue, forKey: AppSettings.themeKey)
        theme = newTheme
    }

    /// Apply a theme received via sync without re-persisting redundantly.
    func applySynced(_ rawValue: String) {
        guard let synced = AppTheme(rawValue: rawValue), synced != theme else { return }
        ThemeManager.activePalette = synced.palette
        UserDefaults.standard.set(synced.rawValue, forKey: AppSettings.themeKey)
        theme = synced
    }
}
