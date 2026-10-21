//
//  AppLockView.swift
//  Finlogue
//

import SwiftUI

/// The screen `AppLock` puts over the app while it's locked.
struct AppLockView: View {
    @ObservedObject var lock: AppLock

    private let biometry = AppLock.biometry

    var body: some View {
        ZStack {
            FinTheme.canvas.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(FinTheme.coral)
                    .frame(width: 68, height: 68)
                    .background(FinTheme.tintCoral, in: Circle())
                Text("Finlogue is locked")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.4)
                    .foregroundStyle(FinTheme.ink)
                Text("Unlock to see your money.")
                    .font(.system(size: 15))
                    .foregroundStyle(FinTheme.ink400)
            }

            VStack {
                Spacer()
                Button {
                    FinHaptics.tap()
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(biometry.name)", systemImage: biometry.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FinTheme.cream)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(FinTheme.ink, in: Capsule())
                }
                .buttonStyle(.pressable)
                .disabled(lock.isAuthenticating)
                .opacity(lock.isAuthenticating ? 0 : 1)
                .animation(FinMotion.quick, value: lock.isAuthenticating)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}
