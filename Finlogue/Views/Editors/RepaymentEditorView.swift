//
//  RepaymentEditorView.swift
//  Finlogue
//
//  Logs a repayment from a person: money returns to an account and their
//  outstanding drops. Recorded as a settlement income transaction, so it's kept
//  out of income stats and insights.
//

import SwiftUI
import SwiftData

struct RepaymentEditorView: View {
    let person: Person

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var amountText = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var selectedAccountID: UUID?
    @FocusState private var amountFocused: Bool

    @AppStorage(AppSettings.lastAccountIDKey) private var lastAccountID = ""

    private var amount: Double? {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let raw = amountText
            .replacingOccurrences(of: groupSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Double(raw)
    }

    private var canSave: Bool {
        (amount ?? 0) > 0 && selectedAccountID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FinTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 2)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                Spacer()
                Text("Repayment")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Save") { save() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSave ? FinTheme.coral : FinTheme.ink400)
                    .disabled(!canSave)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 24) {
                    Text("From \(person.name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)

                    HStack(alignment: .center, spacing: 4) {
                        Text(CurrencyFormatter.symbol())
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.system(size: 64, weight: .heavy))
                            .kerning(-0.5)
                            .foregroundStyle(FinTheme.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { amountFocused = true }

                    if person.outstanding > 0 {
                        Text("Outstanding \(CurrencyFormatter.string(person.outstanding))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                    }

                    detailsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .onAppear(perform: populate)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                detailRow(label: "Into account") {
                    Menu {
                        ForEach(accounts.grouped, id: \.group) { entry in
                            Section(entry.group.rawValue) {
                                ForEach(entry.accounts) { account in
                                    Button(account.name) { selectedAccountID = account.id }
                                }
                            }
                        }
                    } label: {
                        detailValue(accounts.first { $0.id == selectedAccountID }?.name ?? "Select")
                    }
                }
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Date") {
                    DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Note") {
                    TextField("Optional", text: $note)
                        .font(.system(size: 15))
                        .foregroundStyle(FinTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
        }
    }

    private func detailRow(label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
            Spacer()
            value()
        }
        .padding(.vertical, 12)
    }

    private func detailValue(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FinTheme.ink)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FinTheme.ink400)
        }
    }

    private func populate() {
        if let uuid = UUID(uuidString: lastAccountID),
           accounts.contains(where: { $0.id == uuid }) {
            selectedAccountID = uuid
        } else {
            selectedAccountID = accounts.first?.id
        }
        amountFocused = true
    }

    private func save() {
        guard let amount else { return }
        let account = accounts.first { $0.id == selectedAccountID }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.recordRepayment(
            person: person, amount: amount, date: date,
            account: account, note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        if let account { lastAccountID = account.id.uuidString }
        FinHaptics.success()
        dismiss()
    }
}
