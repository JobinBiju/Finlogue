//
//  FinlogueApp.swift
//  Finlogue
//

import SwiftUI
import SwiftData

@main
struct FinlogueApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer
    @StateObject private var store: TransactionStore
    @ObservedObject private var appLock = AppLock.shared

    init() {
        // Shared with the SMS-import App Intent, which runs headless in this
        // same process — see AppModelContainer.
        let container = AppModelContainer.shared
        self.container = container
        _store = StateObject(wrappedValue: TransactionStore(container: container))
        PhoneSyncEngine.shared.configure(container: container)
        NotificationRouter.shared.install()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .fontDesign(.rounded)
                // AppLock's cover window only arrives with the first phase
                // change; this keeps a cold launch from flashing balances.
                .overlay {
                    if appLock.isLocked {
                        FinTheme.canvas.ignoresSafeArea()
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            appLock.scenePhaseChanged(phase)
            if phase == .active {
                store.onAppBecameActive()
            }
        }
    }
}
