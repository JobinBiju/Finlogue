//
//  RootTabView.swift
//  Finlogue
//
//  Custom floating pill tab bar per the Finlogue design: frosted paper
//  capsule, selected tab as a dark pill with a coral icon + label.
//  The dark pill slides between tabs; tab content crossfades. All four
//  tabs stay alive so scroll positions and per-tab state persist.
//

import SwiftUI

/// Shared switch that lets pushed sub-screens hide the floating tab bar.
final class TabBarVisibility: ObservableObject {
    @Published var isHidden = false
}

struct RootTabView: View {
    @State private var selection = initialTab
    @StateObject private var tabBarVisibility = TabBarVisibility()

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
        ZStack {
            // Solid canvas behind the crossfade so the window's white never
            // shows through while both tabs are semi-transparent.
            FinTheme.canvas.ignoresSafeArea()
            tabContent(0) { HomeView() }
            tabContent(1) { InsightsView() }
            tabContent(2) { BudgetsView() }
            tabContent(3) { SettingsView() }
        }
        .overlay(alignment: .bottom) {
            if !tabBarVisibility.isHidden {
                FinTabBar(selection: $selection)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: tabBarVisibility.isHidden)
        .environmentObject(tabBarVisibility)
    }

    @ViewBuilder
    private func tabContent(_ index: Int, @ViewBuilder content: () -> some View) -> some View {
        let isSelected = selection == index
        content()
            .opacity(isSelected ? 1 : 0)
            .scaleEffect(isSelected ? 1 : 0.98)
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
            .animation(.easeInOut(duration: 0.25), value: selection)
    }
}

private struct FinTabBar: View {
    @Binding var selection: Int

    @Namespace private var pillNamespace

    private let tabs: [(symbol: String, label: String)] = [
        ("house.fill", "Home"),
        ("chart.pie.fill", "Insights"),
        ("gauge.with.needle", "Budgets"),
        ("gearshape.fill", "Settings"),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                let tab = tabs[index]
                let isSelected = selection == index
                Button {
                    FinHaptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? FinTheme.coral : FinTheme.ink400)
                        if isSelected {
                            Text(tab.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FinTheme.cream)
                                .fixedSize()
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .leading)),
                                        removal: .opacity
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, isSelected ? 18 : 13)
                    .frame(height: 44)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(FinTheme.ink)
                                .matchedGeometryEffect(id: "selection-pill", in: pillNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(FinTheme.paper.opacity(0.86))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(FinTheme.lineSoft, lineWidth: 1))
                .shadow(color: FinTheme.shadowTint.opacity(0.12), radius: 14, x: 0, y: 8)
        }
    }
}
