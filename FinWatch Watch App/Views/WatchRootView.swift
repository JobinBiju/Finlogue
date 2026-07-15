//
//  WatchRootView.swift
//  FinWatch Watch App
//

import SwiftUI

struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-quickAddAccountStep") {
                WatchQuickAddView()
            } else {
                WatchHomeView()
            }
            #else
            WatchHomeView()
            #endif
        }
    }
}
