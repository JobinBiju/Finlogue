//
//  SettingsView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var store: TransactionStore
    @ObservedObject private var syncEngine = PhoneSyncEngine.shared

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \RecurringRule.name) private var recurringRules: [RecurringRule]

    @AppStorage(AppSettings.currencyCodeKey) private var currencyCode = AppSettings.defaultCurrencyCode

    @State private var editingRule: RecurringRule?
    @State private var showAddRule = Self.launchIntoAddRule
    @State private var pushAccounts = Self.launchIntoAccounts
    @State private var pushCategories = Self.launchIntoCategories

    /// Test hook: `-openAccounts` pushes the Accounts screen on launch.
    private static var launchIntoAccounts: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-openAccounts")
        #else
        return false
        #endif
    }

    /// Test hook: `-openCategories` pushes the Categories screen on launch.
    private static var launchIntoCategories: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-openCategories")
        #else
        return false
        #endif
    }

    /// Test hook: `-showAddRule` opens the recurring payment sheet on launch.
    private static var launchIntoAddRule: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showAddRule")
        #else
        return false
        #endif
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                currencySection
                manageSection
                recurringSection
                syncSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $pushAccounts) {
                AccountsSettingsView()
            }
            .navigationDestination(isPresented: $pushCategories) {
                CategoriesSettingsView()
            }
            .sheet(isPresented: $showAddRule) { RecurringRuleEditorView() }
            .sheet(item: $editingRule) { RecurringRuleEditorView(rule: $0) }
        }
    }

    private var headerSection: some View {
        Section {
        } header: {
            HStack {
                Text("Settings")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button {
                    FinHaptics.tap()
                    PhoneSyncEngine.shared.pushSnapshot()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(FinTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.paper, in: Circle())
                        .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sync with Watch now")
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    private var currencySection: some View {
        Section {
            Picker("Currency", selection: $currencyCode) {
                ForEach(AppSettings.supportedCurrencyCodes, id: \.self) { code in
                    Text("\(code) (\(CurrencyFormatter.symbol(code: code)))").tag(code)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .onChange(of: currencyCode) {
                store.persist()
            }
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Display currency")
        }
    }

    private var manageSection: some View {
        Section {
            NavigationLink {
                AccountsSettingsView()
            } label: {
                manageRow(
                    title: "Accounts",
                    symbol: "building.columns",
                    count: accounts.count
                )
            }
            .listRowBackground(FinTheme.paper)
            .listRowSeparatorTint(FinTheme.lineSoft)
            NavigationLink {
                CategoriesSettingsView()
            } label: {
                manageRow(
                    title: "Categories",
                    symbol: "tag",
                    count: categories.count
                )
            }
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Manage")
        }
    }

    private func manageRow(title: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
                .frame(width: 34, height: 34)
                .background(FinTheme.paperInset, in: Circle())
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink)
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FinTheme.ink400)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private var recurringSection: some View {
        Section {
            ForEach(recurringRules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FinTheme.ink)
                        HStack(spacing: 4) {
                            Text(rule.frequency.label)
                            if let remaining = rule.remainingInstallments {
                                Text("· \(remaining) installments left")
                            }
                            if !rule.isActive {
                                Text("· Finished")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(rule.amount))
                        .font(.system(size: 15, weight: .semibold))
                        .kerning(-0.3)
                        .monospacedDigit()
                        .foregroundStyle(rule.isActive ? FinTheme.ink : FinTheme.ink400)
                }
                .listRowBackground(FinTheme.paper)
                .listRowSeparatorTint(FinTheme.lineSoft)
                .contentShape(Rectangle())
                .onTapGesture { editingRule = rule }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        FinHaptics.warning()
                        store.delete(rule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
                FinHaptics.tap()
                showAddRule = true
            } label: {
                Label("Add recurring payment", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.coral)
            }
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Recurring payments & mandates")
        } footer: {
            Text("Subscriptions, EMIs and loan auto-pay. Due payments are logged when you open the app.")
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink400)
        }
    }

    private var syncSection: some View {
        Section {
            Button {
                FinHaptics.tap()
                PhoneSyncEngine.shared.pushSnapshot()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FinTheme.green)
                        .frame(width: 34, height: 34)
                        .background(FinTheme.tintLime, in: Circle())
                    Text("Sync with Watch now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinTheme.coral)
                }
            }
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Apple Watch")
        } footer: {
            if let lastPush = syncEngine.lastPushDate {
                Text("Last synced \(lastPush.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
            } else {
                Text("Data syncs automatically whenever it changes.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
            }
        }
    }
}
