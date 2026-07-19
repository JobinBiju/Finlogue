//
//  FinWatchApp.swift
//  FinWatch Watch App
//

import SwiftUI
import SwiftData

@main
struct FinWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer

    init() {
        let schema = Schema([
            Transaction.self, Account.self, Category.self, Budget.self, RecurringRule.self,
            Person.self, TransactionSplit.self, RecurringSplit.self,
        ])
        let configuration = ModelConfiguration("Finlogue-v3", schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        WatchSyncEngine.shared.configure(container: container)

        #if DEBUG
        // Test hook: simulates a quick-add without driving the UI.
        if ProcessInfo.processInfo.arguments.contains("-autoAddTestTransaction") {
            let context = container.mainContext
            let transaction = Transaction(
                type: .expense, name: "Watch test coffee", amount: 123, date: .now
            )
            context.insert(transaction)
            try? context.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                WatchSyncEngine.shared.send(transaction: TransactionDTO(from: transaction))
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(WatchSyncEngine.shared)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WatchSyncEngine.shared.requestSnapshot()
            }
        }
    }
}
