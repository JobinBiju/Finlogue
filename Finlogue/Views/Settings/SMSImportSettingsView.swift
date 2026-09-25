//
//  SMSImportSettingsView.swift
//  Finlogue
//
//  Setup for bank-message import: review inbox, Shortcuts automation steps,
//  recognised account digits and the auto-confirm switch.
//

import SwiftUI
import SwiftData

struct SMSImportSettingsView: View {
    @EnvironmentObject private var store: TransactionStore
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @Query private var pending: [PendingTransaction]
    @Query(sort: \AccountIdentifier.createdAt) private var identifiers: [AccountIdentifier]

    var body: some View {
        List {
            headerSection
            inboxSection
            automationSection
            identifiersSection
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(FinTheme.canvas)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { tabBarVisibility.isHidden = true }
        .onDisappear { tabBarVisibility.isHidden = false }
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
                Text("Bank Messages")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .padding(.leading, 8)
                Spacer()
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    // MARK: Inbox

    private var inboxSection: some View {
        Section {
            NavigationLink {
                SMSInboxView()
            } label: {
                HStack {
                    Label("Review Inbox", systemImage: "tray")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinTheme.ink)
                    Spacer()
                    if !pending.isEmpty {
                        Text("\(pending.count)")
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(FinTheme.cream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(FinTheme.coral, in: Capsule())
                    }
                }
            }
            .listRowBackground(FinTheme.paper)
        }
    }

    // MARK: Automation setup

    private var automationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                step(1, "Open Shortcuts › Automation › New Automation.")
                step(2, "Choose Message as the trigger.")
                step(3, "Leave Sender empty and set Message Contains to Rs. Sender only matches a whole header, and yours rotate their prefix (JM-HDFCBK-S, VM-HDFCBK-S), so listing them never matches reliably.")
                step(4, "Set Automation to Run Immediately.")
                step(5, "On the next screen choose New Blank Automation. Do not pick the suggested Log Transaction from Message tile — that shortcut has no editable fields and will ask you to type the message every time.")
                step(6, "Tap Add Action and search for Log Transaction from Message.")
                step(7, "Put the Shortcut Input variable into its Message field, choosing it from the bar above the keyboard.")
                step(8, "Leave Sender blank — every message routes to the review inbox for you to confirm.")
            }
            .padding(.vertical, 4)
            .listRowBackground(FinTheme.paper)
        } header: {
            SectionHeader("Automatic import")
        } footer: {
            Text("iOS gives apps no way to read your messages, so Shortcuts has to hand each one over. Everything is parsed on your device. Triggering on a broad term is fine — one-time passwords, promotions, balances and reminders are all discarded before anything reaches your ledger.")
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FinTheme.cream)
                .frame(width: 20, height: 20)
                .background(FinTheme.ink, in: Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(FinTheme.ink600)
        }
    }

    // MARK: Learned identifiers

    private var identifiersSection: some View {
        Section {
            if identifiers.isEmpty {
                Text("None yet. Add card and account digits when editing an account, or answer the prompt in the review inbox once.")
                    .font(.system(size: 13))
                    .foregroundStyle(FinTheme.ink400)
                    .listRowBackground(FinTheme.paper)
            } else {
                ForEach(identifiers) { identifier in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("•• \(identifier.last4)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(FinTheme.ink)
                                .monospacedDigit()
                            Text(identifier.kind.label)
                                .font(.system(size: 11))
                                .foregroundStyle(FinTheme.ink400)
                        }
                        Spacer()
                        Text(identifier.account?.name ?? "Unassigned")
                            .font(.system(size: 13))
                            .foregroundStyle(FinTheme.ink600)
                    }
                    .listRowBackground(FinTheme.paper)
                }
                .onDelete(perform: deleteIdentifiers)
            }
        } header: {
            SectionHeader("Recognised digits")
        } footer: {
            Text("A savings account and its debit card quote different last-4 digits, so one account can own several.")
        }
    }

    private func deleteIdentifiers(at offsets: IndexSet) {
        for index in offsets {
            store.context.delete(identifiers[index])
        }
        store.persist()
    }
}
