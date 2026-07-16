//
//  FinHaptics.swift
//  Finlogue
//
//  Central haptic vocabulary: light tap for buttons, selection ticks for
//  toggles/pickers, notification haptics for outcomes.
//

import UIKit

enum FinHaptics {
    /// Light impact — button presses, opening sheets.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Selection tick — segment switches, chip picks, tab changes.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Something was saved / completed.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Destructive action (delete).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
