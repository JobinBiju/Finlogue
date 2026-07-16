//
//  AccountEditorView.swift
//  Finlogue
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
        NavigationStack {
            Form {
                Section {
                    TextField("Account name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases) { type in
                            Label(type.label, systemImage: type.symbol).tag(type)
                        }
                    }
                }

                if type == .creditCard {
                    Section {
                        HStack {
                            Text("Credit limit")
                            Spacer()
                            Text(CurrencyFormatter.symbol())
                                .foregroundStyle(.secondary)
                            TextField("0", text: $creditLimitText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                        HStack {
                            Text("Current outstanding")
                            Spacer()
                            Text(CurrencyFormatter.symbol())
                                .foregroundStyle(.secondary)
                            TextField("0", text: $outstandingText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                        Picker("Statement day", selection: $statementDay) {
                            Text("Not set").tag(Int?.none)
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(Int?.some(day))
                            }
                        }
                    } header: {
                        Text("Credit card")
                    } footer: {
                        Text(account == nil
                             ? "Current outstanding is what you owe on this card right now. With a statement day set, billed and unbilled amounts are shown separately."
                             : "Adjusting current outstanding rebases what you owed before transactions logged in the app. With a statement day set, billed and unbilled amounts are shown separately.")
                    }
                } else {
                    Section("Starting balance") {
                        HStack {
                            Text(CurrencyFormatter.symbol())
                                .foregroundStyle(.secondary)
                            TextField("Opening balance", text: $openingBalanceText)
                                .keyboardType(.numbersAndPunctuation)
                        }
                    }
                }
            }
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .fontDesign(.rounded)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard let account else { return }
                name = account.name
                type = account.type
                openingBalanceText = String(format: "%g", account.openingBalance)
                if let limit = account.creditLimit {
                    creditLimitText = String(format: "%g", limit)
                }
                if account.type == .creditCard {
                    outstandingText = String(format: "%g", account.spent)
                }
                statementDay = account.statementDay
            }
        }
    }

    private func save() {
        let opening = Double(openingBalanceText.replacingOccurrences(of: ",", with: "")) ?? 0
        let limit = Double(creditLimitText.replacingOccurrences(of: ",", with: ""))
        let outstanding = Double(outstandingText.replacingOccurrences(of: ",", with: "")) ?? 0

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
        dismiss()
    }
}
