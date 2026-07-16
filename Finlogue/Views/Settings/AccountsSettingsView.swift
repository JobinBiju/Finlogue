//
//  AccountsSettingsView.swift
//  Finlogue
//
//  Accounts management sub-screen: grouped Banks / Cards / Others.
//

import SwiftUI
import SwiftData

struct AccountsSettingsView: View {
    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var editingAccount: Account?
    @State private var showAddAccount = false

    var body: some View {
        List {
            headerSection
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
            } footer: {
                Text("Tap an account to edit it. Deleting an account also deletes its transactions.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(FinTheme.canvas)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .contentMargins(.bottom, 88, for: .scrollContent)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddAccount) { AccountEditorView() }
        .sheet(item: $editingAccount) { AccountEditorView(account: $0) }
    }

    private var headerSection: some View {
        Section {
        } header: {
            HStack {
                Button {
                    FinHaptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FinTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.paper, in: Circle())
                        .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                Text("Accounts")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .padding(.leading, 8)
                Spacer()
                Button {
                    FinHaptics.tap()
                    showAddAccount = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.coral, in: Circle())
                        .shadow(color: FinTheme.coral.opacity(0.28), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
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
                FinHaptics.warning()
                store.delete(account)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
