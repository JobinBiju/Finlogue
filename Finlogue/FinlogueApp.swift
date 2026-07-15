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
        let schema = Schema([
            Transaction.self, Account.self, Category.self, Budget.self, RecurringRule.self,
        ])
        let configuration = ModelConfiguration(
            "Finlogue-v2",
            schema: schema,
            groupContainer: .identifier("group.dev.jobin.finlogue")
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            _store = StateObject(wrappedValue: TransactionStore(container: container))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        PhoneSyncEngine.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.onAppBecameActive()
            }
        }
    }
}
