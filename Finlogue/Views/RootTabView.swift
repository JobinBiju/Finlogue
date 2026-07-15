//
//  RootTabView.swift
//  Finlogue
//

import SwiftUI

struct RootTabView: View {
    @State private var selection = initialTab

    /// Test hook: `-initialTab N` launch argument opens a specific tab.
    private static var initialTab: Int {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-initialTab"),
           arguments.indices.contains(index + 1),
           let tab = Int(arguments[index + 1]) {
            return tab
        }
        #endif
        return 0
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie.fill") }
                .tag(1)
            BudgetsView()
                .tabItem { Label("Budgets", systemImage: "gauge.with.needle") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
    }
}
