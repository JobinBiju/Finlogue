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

    @State private var editingAccount: Account?
    @State private var showAddAccount = false
    @State private var editingCategory: Category?
    @State private var showAddCategory = false
    @State private var editingRule: RecurringRule?
    @State private var showAddRule = false

    var body: some View {
        NavigationStack {
            List {
                headerSection
                currencySection
                accountsSection
                categoriesSection
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
            .sheet(isPresented: $showAddAccount) { AccountEditorView() }
            .sheet(item: $editingAccount) { AccountEditorView(account: $0) }
            .sheet(isPresented: $showAddCategory) { CategoryEditorView() }
            .sheet(item: $editingCategory) { CategoryEditorView(category: $0) }
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

    /// One real list section per account group.
    @ViewBuilder
    private var accountsSection: some View {
        ForEach(accounts.grouped, id: \.group) { entry in
            Section {
                ForEach(entry.accounts) { account in
                    accountRow(account)
                }
            } header: {
                SectionHeader(entry.group.rawValue)
            }
        }
        Section {
            Button {
                showAddAccount = true
            } label: {
                Label("Add account", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.coral)
            }
            .listRowBackground(FinTheme.paper)
        } footer: {
            Text("Deleting an account also deletes its transactions.")
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink400)
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.symbol)
                .font(.system(size: 17))
                .foregroundStyle(FinTheme.ink600)
                .frame(width: 28)
            Text(account.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink)
            Spacer()
            if account.type == .creditCard {
                Text(CurrencyFormatter.string(account.spent))
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(account.spent > 0 ? FinTheme.red : FinTheme.ink400)
                    .monospacedDigit()
            } else {
                Text(CurrencyFormatter.string(account.currentBalance))
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(account.currentBalance >= 0 ? FinTheme.green : FinTheme.red)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(FinTheme.paper)
        .listRowSeparatorTint(FinTheme.lineSoft)
        .contentShape(Rectangle())
        .onTapGesture { editingAccount = account }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.delete(account)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var categoriesSection: some View {
        Section {
            ForEach(categories) { category in
                HStack(spacing: 12) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Color(hex: category.colorHex),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    Text(category.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinTheme.ink)
                    Spacer()
                    Text(category.type.label)
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
                }
                .padding(.vertical, 2)
                .listRowBackground(FinTheme.paper)
                .listRowSeparatorTint(FinTheme.lineSoft)
                .contentShape(Rectangle())
                .onTapGesture { editingCategory = category }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        store.delete(category)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
                showAddCategory = true
            } label: {
                Label("Add category", systemImage: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.coral)
            }
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Categories")
        }
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
                        store.delete(rule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            Button {
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
