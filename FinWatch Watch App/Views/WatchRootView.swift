//
//  WatchRootView.swift
//  FinWatch Watch App
//

import SwiftUI

struct WatchRootView: View {
    // Rebuild with the new palette when the phone syncs a theme change.
    @ObservedObject private var themeManager = ThemeManager.shared

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
        .id(themeManager.theme)
    }
}
