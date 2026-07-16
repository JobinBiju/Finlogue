//
//  AccountEditorView.swift
//  Finlogue
//
//  Design-system account sheet: cream canvas, pill type segments,
//  paper detail cards.
//

import SwiftUI

struct AccountEditorView: View {
    var account: Account?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var openingBalanceText = ""
    @State private var creditLimitText = ""
    @State private var outstandingText = ""
    @State private var statementDay: Int?

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                Text(account == nil ? "New account" : "Edit account")
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
                    nameEntry
                    typeSegments
                    if type == .creditCard {
                        creditCardCard
                    } else {
                        balanceCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .onAppear(perform: populate)
    }

    // MARK: Pieces

    private var nameEntry: some View {
        TextField("Account name", text: $name)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(FinTheme.ink)
            .multilineTextAlignment(.center)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
    }

    private var typeSegments: some View {
        HStack(spacing: 0) {
            ForEach(AccountType.allCases) { candidate in
                Button {
                    FinHaptics.selection()
                    withAnimation(.snappy(duration: 0.25)) {
                        type = candidate
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: candidate.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(candidate.label)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(type == candidate ? .white : FinTheme.ink400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if type == candidate {
                            Capsule()
                                .fill(FinTheme.coral)
                                .shadow(color: FinTheme.coral.opacity(0.28), radius: 8, x: 0, y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(FinTheme.paper, in: Capsule())
    }

    private var balanceCard: some View {
        labeledCard("Starting balance") {
            amountRow(label: "Opening balance", text: $openingBalanceText)
        }
    }

    private var creditCardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledCard("Credit card") {
                amountRow(label: "Credit limit", text: $creditLimitText)
                Divider().overlay(FinTheme.lineSoft)
                amountRow(label: "Current outstanding", text: $outstandingText)
                Divider().overlay(FinTheme.lineSoft)
                HStack {
                    Text("Statement day")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinTheme.ink600)
                    Spacer()
                    Menu {
                        Button("Not set") { statementDay = nil }
                        ForEach(1...31, id: \.self) { day in
                            Button("\(day)") { statementDay = day }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(statementDay.map { "\($0)" } ?? "Not set")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FinTheme.ink)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(FinTheme.ink400)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            Text(account == nil
                 ? "Current outstanding is what you owe on this card right now. With a statement day set, billed and unbilled amounts are shown separately."
                 : "Adjusting current outstanding rebases what you owed before transactions logged in the app. With a statement day set, billed and unbilled amounts are shown separately.")
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink400)
                .padding(.leading, 4)
        }
    }

    private func amountRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
            Spacer()
            Text(CurrencyFormatter.symbol())
                .font(.system(size: 15))
                .foregroundStyle(FinTheme.ink400)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FinTheme.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 120)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let formatted = AmountInput.reformat(newValue)
                    if formatted != newValue {
                        text.wrappedValue = formatted
                    }
                }
        }
        .padding(.vertical, 12)
    }

    private func labeledCard(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Logic (unchanged)

    private func populate() {
        guard let account else { return }
        name = account.name
        type = account.type
        openingBalanceText = AmountInput.string(account.openingBalance)
        if let limit = account.creditLimit {
            creditLimitText = AmountInput.string(limit)
        }
        if account.type == .creditCard {
            outstandingText = AmountInput.string(account.spent)
        }
        statementDay = account.statementDay
    }

    private func save() {
        let opening = AmountInput.parse(openingBalanceText) ?? 0
        let limit = AmountInput.parse(creditLimitText)
        let outstanding = AmountInput.parse(outstandingText) ?? 0

        // For credit cards, openingBalance stores the opening outstanding.
        // Editing "current outstanding" rebases it so total owed matches,
        // without touching the transactions already logged in the app.
        let cardOpening: Double
        if let account, account.type == .creditCard, type == .creditCard {
            let transactionDelta = account.spent - account.openingBalance
            cardOpening = outstanding - transactionDelta
        } else {
            cardOpening = outstanding
        }

        store.saveAccount(
            account,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            openingBalance: type == .creditCard ? cardOpening : opening,
            creditLimit: type == .creditCard ? limit : nil,
            statementDay: statementDay
        )
        FinHaptics.success()
        dismiss()
    }
}
