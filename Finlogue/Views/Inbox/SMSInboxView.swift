//
//  SMSInboxView.swift
//  Finlogue
//
//  Review queue for transactions parsed out of bank messages. Nothing here has
//  touched the ledger yet — confirming is what books it.
//

import SwiftUI
import SwiftData

struct SMSInboxView: View {
    @EnvironmentObject private var store: TransactionStore
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PendingTransaction.date, order: .reverse)
    private var pending: [PendingTransaction]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var expandedID: UUID?
    @State private var pasteMessage: String?

    var body: some View {
        List {
            headerSection
            if let pasteMessage {
                Section {
                    Text(pasteMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FinTheme.ink600)
                        .listRowBackground(FinTheme.paper)
                }
            }
            if pending.isEmpty {
                emptyState
            } else {
                ForEach(pending) { item in
                    PendingTransactionRow(
                        pending: item,
                        accounts: accounts,
                        categories: categories,
                        isExpanded: expandedID == item.id,
                        onToggle: {
                            withAnimation(.snappy) {
                                expandedID = expandedID == item.id ? nil : item.id
                            }
                        },
                        onConfirm: { name, account, category in
                            confirm(item, name: name, account: account, category: category)
                        },
                        onDiscard: { discard(item) }
                    )
                    .listRowBackground(FinTheme.paper)
                    .listRowSeparatorTint(FinTheme.lineSoft)
                }
            }
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
                Text("Review Inbox")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .padding(.leading, 8)
                Spacer()
                // Messages offers no share sheet for a message bubble — Copy is
                // the only way out of it — so pasting is the manual capture
                // path. PasteButton reads the clipboard without the system
                // "pasted from" prompt.
                PasteButton(payloadType: String.self) { items in
                    guard let text = items.first else { return }
                    Task { @MainActor in ingestPasted(text) }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.circle)
                .tint(FinTheme.coral)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(FinTheme.ink400)
            Text("Nothing to review")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FinTheme.ink)
            Text("Transactions parsed from your bank messages show up here before they are added. In Messages, hold a bank message and tap Copy, then use the paste button above.")
                .font(.system(size: 13))
                .foregroundStyle(FinTheme.ink400)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .listRowBackground(FinTheme.paper)
    }

    private func confirm(
        _ item: PendingTransaction,
        name: String,
        account: Account?,
        category: Category?
    ) {
        // The edited name is what gets booked, and what the merchant rule
        // learns — so correcting it once fixes every later message.
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { item.name = trimmed }

        // Teach the resolver before booking, so the next message on this card
        // resolves without asking again.
        if let last4 = item.last4, let account, let kind = item.instrument {
            SMSImportService.learnIdentifier(
                last4: last4, kind: kind, account: account, store: store
            )
        }
        SMSImportService.confirm(
            item, store: store, overrideAccount: account, overrideCategory: category
        )
        FinHaptics.success()
    }

    /// Sender is blank for a pasted message, so it carries no trust tier and can
    /// only ever queue — never auto-confirm.
    private func ingestPasted(_ text: String) {
        let outcome = SMSImportService.ingest(text: text, sender: "", store: store)
        pasteMessage = outcome.userFacingSummary
        FinHaptics.success()
    }

    private func discard(_ item: PendingTransaction) {
        SMSImportService.discard(item, store: store)
        FinHaptics.tap()
    }
}

// MARK: - Row

private struct PendingTransactionRow: View {
    let pending: PendingTransaction
    let accounts: [Account]
    let categories: [Category]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onConfirm: (String, Account?, Category?) -> Void
    let onDiscard: () -> Void

    @State private var editedName = ""
    @State private var chosenAccount: Account?
    @State private var chosenCategory: Category?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded { detail }
            actions
        }
        .padding(.vertical, 8)
        .onAppear(perform: primeSelection)
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(editedName.isEmpty ? pending.name : editedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FinTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
                        .lineLimit(1)
                    // Explains why Add is disabled without making the user
                    // expand the row to find out.
                    if chosenAccount == nil {
                        Text("Tap to choose an account")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FinTheme.amber500)
                    }
                }

                Spacer()

                Text(CurrencyFormatter.string(pending.amount))
                    .font(.system(size: 15, weight: .bold))
                    .kerning(-0.3)
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Merchant strings from banks are frequently mangled; the corrected
            // name is what gets booked and what the merchant rule remembers.
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FinTheme.ink400)
                TextField("Transaction name", text: $editedName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(FinTheme.paperInset, in: RoundedRectangle(cornerRadius: 10))
            }

            Text(pending.rawText)
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink600)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FinTheme.paperInset, in: RoundedRectangle(cornerRadius: 10))

            if pending.needsAccountChoice {
                Label(
                    accountPromptText,
                    systemImage: "questionmark.circle"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FinTheme.amber500)
            }

            Picker("Account", selection: $chosenAccount) {
                Text("None").tag(Account?.none)
                ForEach(accounts) { account in
                    Text(account.name).tag(Account?.some(account))
                }
            }
            .pickerStyle(.menu)
            .tint(FinTheme.coral)

            if pending.type != .transfer {
                Picker("Category", selection: $chosenCategory) {
                    Text("Uncategorised").tag(Category?.none)
                    ForEach(categories.filter { $0.type == pending.type }) { category in
                        Text(category.name).tag(Category?.some(category))
                    }
                }
                .pickerStyle(.menu)
                .tint(FinTheme.coral)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(role: .destructive, action: onDiscard) {
                Text("Ignore")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                onConfirm(editedName, chosenAccount, chosenCategory)
            } label: {
                Text("Add")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FinTheme.coral)
            .disabled(chosenAccount == nil)
        }
    }

    // MARK: Helpers

    private func primeSelection() {
        if editedName.isEmpty { editedName = pending.name }
        if chosenAccount == nil {
            chosenAccount = accounts.first { $0.id == pending.resolvedAccountID }
        }
        if chosenCategory == nil {
            chosenCategory = categories.first { $0.id == pending.suggestedCategoryID }
        }
    }

    private var accountPromptText: String {
        if let masked = pending.maskedLast4 {
            return "Which account is \(masked)? Your choice is remembered."
        }
        return "No account number in this message — pick one."
    }

    /// Deliberately compact — the year and the sender header both overflowed the
    /// row, and both are visible in the raw message once expanded.
    private var subtitle: String {
        var parts = [
            pending.date.formatted(
                .dateTime.day().month(.abbreviated).hour().minute()
            )
        ]
        if let masked = pending.maskedLast4 { parts.append(masked) }
        return parts.joined(separator: " · ")
    }

    private var symbol: String {
        switch pending.type {
        case .income: "arrow.down.left"
        case .expense: "arrow.up.right"
        case .transfer: "arrow.left.arrow.right"
        }
    }

    private var tint: Color {
        switch pending.type {
        case .income: FinTheme.green
        case .expense: FinTheme.red
        case .transfer: FinTheme.slate
        }
    }
}
