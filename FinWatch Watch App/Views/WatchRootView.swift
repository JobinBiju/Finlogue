//
//  WatchRootView.swift
//  FinWatch Watch App
//

import SwiftUI

struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            #if DEBUG
            // Test hooks: open a specific screen directly.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-quickAddAccountStep") || arguments.contains("-watchQuickAdd") {
                WatchQuickAddView()
            } else if arguments.contains("-watchTransactions") {
                WatchTransactionListView()
            } else {
                WatchHomeView()
            }
            #else
            WatchHomeView()
            #endif
        }
    }
}
