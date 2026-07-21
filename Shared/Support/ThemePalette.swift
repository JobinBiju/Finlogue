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
    case ocean
    case noir

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tino: "Tino"
        case .plum: "Plum"
        case .olive: "Olive"
        case .ocean: "Ocean"
        case .noir: "Noir"
        }
    }

    /// A one-line description shown in the theme picker.
    var subtitle: String {
        switch self {
        case .tino: "Warm cream & coral"
        case .plum: "Ghost-white & plum"
        case .olive: "Cornsilk & olive"
        case .ocean: "Alice-blue & teal"
        case .noir: "Charcoal & terracotta"
        }
    }

    /// Dark themes drive `.preferredColorScheme(.dark)` so system controls
    /// (menus, pickers, keyboard) match the dark canvas.
    var isDark: Bool {
        switch self {
        case .noir: true
        default: false
        }
    }

    var palette: ThemePalette {
        switch self {
        case .tino: .tino
        case .plum: .plum
        case .olive: .olive
        case .ocean: .ocean
        case .noir: .noir
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
        ink: "#0D1208", ink600: "#3C5124", ink400: "#6B9041",
        line: "#DFE3C8", lineSoft: "#EEF0DD", cream: "#FEFAE0",
        tintLime: "#E4EFC0", tintPeach: "#F6E0CE",
        tintAmber: "#FBEBC7", tintCoral: "#FBDECF",
        shadowTint: "#606C38", watchGradientTop: "#BC6C25",
        slate: "#64748B", mutedIcon: "#94A3B8"
    )

    /// Ocean — alice-blue canvas, stormy-teal primary, with pearl-aqua and
    /// tangerine warm accents. Same override scope as Plum/Olive; the five
    /// source colors are mapped across primary, canvas, positive-soft, warm
    /// accent and the soft "spent" tint.
    static let ocean = ThemePalette(
        coral: "#006D77", coral600: "#005A63",
        amber: "#E29578", amber500: "#D07E5E",
        lime100: "#DCEDE9", lime300: "#83C5BE", lime400: "#5FB0A6",
        green: "#2F8F7A", red400: "#E29578", red: "#D9694B",
        blue: "#2E6BD6", violet: "#B96BE0",
        canvas: "#EDF6F9", paper: "#FBFDFE", paperInset: "#E3EFF1",
        ink: "#102123", ink600: "#2E5A60", ink400: "#6E9298",
        line: "#D5E6E9", lineSoft: "#E4EFF1", cream: "#EDF6F9",
        tintLime: "#DCEDE9", tintPeach: "#FFDDD2",
        tintAmber: "#FFE7DD", tintCoral: "#FFDDD2",
        shadowTint: "#04353B", watchGradientTop: "#006D77",
        slate: "#64748B", mutedIcon: "#94A3B8"
    )

    /// Noir — a dark theme: charcoal canvas, terracotta primary, forest green,
    /// warm cream. Luminance is inverted vs the light themes — `ink` is the
    /// light text and `cream` is the dark text sitting on the cream tab pill and
    /// credit-card tiles (which fill with `ink`).
    static let noir = ThemePalette(
        coral: "#C84B31", coral600: "#A93D28",
        amber: "#E0B074", amber500: "#D0994F",
        lime100: "#25322A", lime300: "#4E9E78", lime400: "#5FB088",
        green: "#4E9E78", red400: "#E06B4A", red: "#D9553A",
        blue: "#5B8DEF", violet: "#B98AE0",
        canvas: "#161616", paper: "#1F1F1E", paperInset: "#282826",
        ink: "#ECDBBA", ink600: "#B7AC92", ink400: "#847B67",
        line: "#33322E", lineSoft: "#2A2926", cream: "#161616",
        tintLime: "#25322A", tintPeach: "#33241E",
        tintAmber: "#332B1C", tintCoral: "#33211B",
        shadowTint: "#000000", watchGradientTop: "#C84B31",
        slate: "#6E6A60", mutedIcon: "#57534A"
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
