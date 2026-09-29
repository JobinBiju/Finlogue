//
//  KeyboardDismissTap.swift
//  Finlogue
//
//  Closes the keyboard when the user taps anywhere outside the field being
//  edited. A window-level UIKit recognizer that never cancels or delays the
//  touches it sees, so list rows, navigation links and buttons underneath
//  still get their taps — a SwiftUI gesture on the List swallowed them.
//  Installed only while a field is focused.
//

import UIKit

@MainActor
final class KeyboardDismissTap: NSObject, UIGestureRecognizerDelegate {
    private var recognizer: UITapGestureRecognizer?
    /// Screen-space area that doesn't dismiss (e.g. the whole search pill,
    /// including its clear button and padding).
    private var keepsKeyboard: () -> CGRect = { .zero }

    func install(keepingKeyboardIn area: @escaping () -> CGRect) {
        keepsKeyboard = area
        guard recognizer == nil, let window = Self.keyWindow else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        window.addGestureRecognizer(tap)
        recognizer = tap
    }

    func remove() {
        guard let recognizer else { return }
        recognizer.view?.removeGestureRecognizer(recognizer)
        self.recognizer = nil
    }

    @objc private func dismiss(_ recognizer: UITapGestureRecognizer) {
        recognizer.view?.endEditing(true)
    }

    // MARK: UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch
    ) -> Bool {
        if keepsKeyboard().contains(touch.location(in: nil)) { return false }
        // Taps inside any text input move the cursor; they never dismiss.
        var view = touch.view
        while let current = view {
            if current is UITextInput { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
