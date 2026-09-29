//
//  RootTabView.swift
//  Finlogue
//
//  Custom floating pill tab bar per the Finlogue design: frosted paper
//  capsule, selected tab as a dark pill with a coral icon + label.
//  The dark pill stretches between tabs; tab content crossfades. All four
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
    // Observed so a theme change re-runs body; `.id(theme)` below then rebuilds
    // the content with the new palette. `selection` lives above the id, so the
    // current tab survives the swap.
    @ObservedObject private var themeManager = ThemeManager.shared

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
        themedContent
            // Below the .id boundary so system controls (pickers, etc.) pick up
            // the new primary when the theme changes.
            .tint(FinTheme.coral)
            .id(themeManager.theme)
            // Dark themes flip system chrome (menus, pickers, keyboard) to dark.
            .preferredColorScheme(themeManager.theme.isDark ? .dark : .light)
            #if DEBUG
            .task { await playMotionTourIfRequested() }
            #endif
    }

    #if DEBUG
    /// Test hook: `-motionTour` scripts a toast and a run of tab switches, so
    /// the app's motion can be screen-recorded in the simulator without taps.
    private func playMotionTourIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("-motionTour") else { return }
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        await wait(2.5)
        ToastCenter.shared.show("Added", detail: "Swiggy −₹340")
        await wait(3.5)
        for tab in [1, 2, 3, 0, 2, 1, 0] {
            withAnimation(FinMotion.select) { selection = tab }
            await wait(tab == 0 ? 1.2 : 2.2)
        }
    }
    #endif

    private var themedContent: some View {
        ZStack {
            // Solid canvas behind the crossfade so the window's white never
            // shows through while both tabs are semi-transparent.
            FinTheme.canvas.ignoresSafeArea()
            tabContent(0) { HomeView() }
            tabContent(1) { InsightsView() }
            tabContent(2) { BudgetsView() }
            tabContent(3) { SettingsView() }
        }
        .overlay {
            ZStack(alignment: .bottom) {
                Color.clear.allowsHitTesting(false)
                if !tabBarVisibility.isHidden {
                    FinTabBar(selection: $selection)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Stay pinned to the bottom when the keyboard comes up: the
            // keyboard covers the bar rather than pushing it over the content.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .animation(FinMotion.select, value: tabBarVisibility.isHidden)
        .overlay(alignment: .top) {
            FinToastView(center: .shared)
                .padding(.top, 4)
        }
        .environmentObject(tabBarVisibility)
    }

    @ViewBuilder
    private func tabContent(_ index: Int, @ViewBuilder content: () -> some View) -> some View {
        let isSelected = selection == index
        content()
            .environment(\.isTabActive, isSelected)
            // Scoped: only the crossfade itself animates, nothing else that
            // happens to change in the same update as a tab switch.
            .animation(FinMotion.swap) { view in
                view
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.98)
            }
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }
}

private struct FinTabBar: View {
    @Binding var selection: Int

    /// Per-tab tick that bounces the icon of the tab just picked.
    @State private var bounces = [0, 0, 0, 0]

    private let tabs: [(symbol: String, label: String)] = [
        ("house.fill", "Home"),
        ("chart.pie.fill", "Insights"),
        ("gauge.with.needle", "Budgets"),
        ("gearshape.fill", "Settings"),
    ]

    var body: some View {
        LiquidSegmentedControl(
            items: Array(tabs.indices),
            selection: selection,
            spacing: 4,
            onSelect: { index in
                guard index != selection else { return }
                FinHaptics.selection()
                bounces[index] += 1
                withAnimation(FinMotion.select) {
                    selection = index
                }
            },
            segment: { index, isSelected, onPill in
                let tab = tabs[index]
                HStack(spacing: 8) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(onPill ? FinTheme.coral : FinTheme.ink400)
                        .symbolEffect(.bounce.down, options: .speed(1.4), value: bounces[index])
                    if isSelected {
                        Text(tab.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(onPill ? FinTheme.cream : FinTheme.ink)
                            .fixedSize()
                            .blurSwapTransition()
                    }
                }
                .padding(.horizontal, isSelected ? 18 : 13)
                .frame(height: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tab.label)
            },
            pill: { shape in
                shape.fill(FinTheme.ink)
            }
        )
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
