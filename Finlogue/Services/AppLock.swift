//
//  AppLock.swift
//  Finlogue
//

import LocalAuthentication
import SwiftUI
import UIKit

/// Opt-in Face ID lock. The app locks whenever it goes to the background and
/// asks to unlock when it comes back.
///
/// The lock screen lives in its own window above the app's, so it also covers
/// open sheets and the app-switcher snapshot, which an in-hierarchy overlay
/// can't do.
@MainActor
final class AppLock: ObservableObject {
    static let shared = AppLock()

    @Published private(set) var isLocked: Bool
    @Published private(set) var isAuthenticating = false

    /// Set on lock, consumed by the first activation after it. The Face ID
    /// sheet itself bounces the scene through `.inactive`, so prompting on
    /// every activation would re-prompt straight after a cancel.
    private var promptOnActivation: Bool
    private var coverWindow: UIWindow?

    private init() {
        isLocked = AppSettings.appLockEnabled
        promptOnActivation = AppSettings.appLockEnabled
    }

    // MARK: Scene phase

    func scenePhaseChanged(_ phase: ScenePhase) {
        guard AppSettings.appLockEnabled else { return }
        switch phase {
        case .background:
            isLocked = true
            promptOnActivation = true
            // Otherwise the keyboard window stays up over the lock screen.
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
            showCover()
        case .inactive:
            // Keeps balances out of the app-switcher snapshot. The Face ID
            // sheet from the Settings toggle also lands here; it shouldn't.
            guard !isAuthenticating else { return }
            showCover()
        case .active:
            if isLocked {
                showCover()
                if promptOnActivation {
                    promptOnActivation = false
                    Task { await unlock() }
                }
            } else {
                hideCover()
            }
        @unknown default:
            break
        }
    }

    // MARK: Unlocking

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        switch await authenticate(reason: "Unlock Finlogue") {
        case .success:
            isLocked = false
            hideCover()
        case .unavailable:
            // The device passcode was removed after the lock was turned on.
            // Without it there's nothing to unlock with, so stand the lock
            // down rather than shutting the user out of their own data.
            UserDefaults.standard.set(false, forKey: AppSettings.appLockKey)
            isLocked = false
            hideCover()
        case .failed:
            break
        }
    }

    enum AuthResult { case success, failed, unavailable }

    /// Face ID, falling back to the device passcode.
    func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
                ? .success : .failed
        } catch {
            return .failed
        }
    }

    // MARK: Biometry

    /// What the device unlocks with, for labels and icons.
    static var biometry: (name: String, symbol: String) {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return ("Face ID", "faceid")
        case .touchID: return ("Touch ID", "touchid")
        case .opticID: return ("Optic ID", "opticid")
        default: return ("Passcode", "lock.fill")
        }
    }

    // MARK: Cover window

    private func showCover() {
        if let coverWindow {
            coverWindow.layer.removeAllAnimations()
            coverWindow.alpha = 1
            coverWindow.isHidden = false
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: AppLockView(lock: self).fontDesign(.rounded))
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        coverWindow = window
    }

    private func hideCover() {
        guard let coverWindow, !coverWindow.isHidden else { return }
        let duration = FinMotion.reduceMotion ? 0 : 0.2
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            coverWindow.alpha = 0
        } completion: { finished in
            // A lock that lands mid-fade has already put the alpha back.
            guard finished, !self.isLocked else { return }
            coverWindow.isHidden = true
        }
    }
}
