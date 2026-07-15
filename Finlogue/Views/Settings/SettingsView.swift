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
                currencySection
                accountsSection
                categoriesSection
                recurringSection
                syncSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        PhoneSyncEngine.shared.pushSnapshot()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel("Sync with Watch now")
                }
            }
            .sheet(isPresented: $showAddAccount) { AccountEditorView() }
            .sheet(item: $editingAccount) { AccountEditorView(account: $0) }
            .sheet(isPresented: $showAddCategory) { CategoryEditorView() }
            .sheet(item: $editingCategory) { CategoryEditorView(category: $0) }
            .sheet(isPresented: $showAddRule) { RecurringRuleEditorView() }
            .sheet(item: $editingRule) { RecurringRuleEditorView(rule: $0) }
        }
    }

    private var currencySection: some View {
        Section {
            Picker("Currency", selection: $currencyCode) {
                ForEach(AppSettings.supportedCurrencyCodes, id: \.self) { code in
                    Text("\(code) (\(CurrencyFormatter.symbol(code: code)))").tag(code)
                }
            }
            .onChange(of: currencyCode) {
                store.persist()
            }
        } header: {
            SectionHeader("Display currency")
        }
    }

    /// One real list section per account group, so separators and card
    /// boundaries come from the system instead of fake in-card label rows.
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
            }
        } footer: {
            Text("Deleting an account also deletes its transactions.")
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            Image(systemName: account.type.symbol)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(account.name)
            Spacer()
            if account.type == .creditCard {
                Text(CurrencyFormatter.string(account.spent))
                    .foregroundStyle(account.spent > 0 ? .red : .secondary)
                    .monospacedDigit()
            } else {
                Text(CurrencyFormatter.string(account.currentBalance))
                    .foregroundStyle(account.currentBalance >= 0 ? .green : .red)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
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
                HStack {
                    Image(systemName: category.symbol)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: category.colorHex), in: RoundedRectangle(cornerRadius: 8))
                    Text(category.name)
                    Spacer()
                    Text(category.type.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            }
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
                        HStack(spacing: 4) {
                            Text(rule.frequency.label)
                            if let remaining = rule.remainingInstallments {
                                Text("· \(remaining) installments left")
                            }
                            if !rule.isActive {
                                Text("· Finished")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(rule.amount))
                        .monospacedDigit()
                        .foregroundStyle(rule.isActive ? .primary : .secondary)
                }
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
            }
        } header: {
            SectionHeader("Recurring payments & mandates")
        } footer: {
            Text("Subscriptions, EMIs and loan auto-pay. Due payments are logged when you open the app.")
        }
    }

    private var syncSection: some View {
        Section {
            Button {
                PhoneSyncEngine.shared.pushSnapshot()
            } label: {
                Label("Sync with Watch now", systemImage: "applewatch")
            }
        } header: {
            SectionHeader("Apple Watch")
        } footer: {
            if let lastPush = syncEngine.lastPushDate {
                Text("Last synced \(lastPush.formatted(.relative(presentation: .named)))")
            } else {
                Text("Data syncs automatically whenever it changes.")
            }
        }
    }
}
