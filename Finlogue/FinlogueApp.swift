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

    init() {
        // Shared with the SMS-import App Intent, which runs headless in this
        // same process — see AppModelContainer.
        let container = AppModelContainer.shared
        self.container = container
        _store = StateObject(wrappedValue: TransactionStore(container: container))
        PhoneSyncEngine.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .fontDesign(.rounded)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.onAppBecameActive()
            }
        }
    }
}
