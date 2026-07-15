//
//  RecurringRuleEditorView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct RecurringRuleEditorView: View {
    var rule: RecurringRule?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var name = ""
    @State private var amountText = ""
    @State private var type: TransactionType = .expense
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate = Date.now
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var isLoan = false
    @State private var installmentsText = ""
    @State private var autoPost = true

    private var typeCategories: [Category] {
        categories.filter { $0.type == type }
    }

    private var canSave: Bool {
        guard let amount = Double(amountText), amount > 0 else { return false }
        if isLoan, Int(installmentsText) == nil { return false }
        if type == .transfer,
           selectedToAccountID == nil || selectedToAccountID == selectedAccountID {
            return false
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Netflix, Car EMI, Card bill)", text: $name)
                    HStack {
                        Text(CurrencyFormatter.symbol())
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }

                Section("Schedule") {
                    Picker("Repeats", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }
                    DatePicker("First payment", selection: $startDate, displayedComponents: .date)
                }

                Section {
                    Toggle("Fixed number of installments", isOn: $isLoan)
                    if isLoan {
                        TextField("Installments remaining", text: $installmentsText)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text("Loan / EMI")
                } footer: {
                    Text("For loans and EMIs the mandate stops automatically after the last installment.")
                }

                Section {
                    Picker(type == .transfer ? "From account" : "Account",
                           selection: $selectedAccountID) {
                        Text("None").tag(UUID?.none)
                        ForEach(accounts.grouped, id: \.group) { entry in
                            Section(entry.group.rawValue) {
                                ForEach(entry.accounts) { account in
                                    Text(account.name).tag(UUID?.some(account.id))
                                }
                            }
                        }
                    }
                    if type == .transfer {
                        Picker("To account", selection: $selectedToAccountID) {
                            Text("Select account").tag(UUID?.none)
                            ForEach(accounts.filter { $0.id != selectedAccountID }.grouped,
                                    id: \.group) { entry in
                                Section(entry.group.rawValue) {
                                    ForEach(entry.accounts) { account in
                                        Text(account.name).tag(UUID?.some(account.id))
                                    }
                                }
                            }
                        }
                    } else {
                        Picker("Category", selection: $selectedCategoryID) {
                            Text("None").tag(UUID?.none)
                            ForEach(typeCategories) { category in
                                Label(category.name, systemImage: category.symbol)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                    }
                    Toggle("Post automatically", isOn: $autoPost)
                } header: {
                    Text("Posting")
                } footer: {
                    Text(autoPost
                         ? "Payments are logged automatically when due."
                         : "You'll get an Upcoming reminder and confirm each payment.")
                }
            }
            .navigationTitle(rule == nil ? "New Recurring Payment" : "Edit Recurring Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let rule else {
            selectedAccountID = accounts.first?.id
            return
        }
        name = rule.name
        amountText = String(format: "%g", rule.amount)
        type = rule.type
        frequency = rule.frequency
        startDate = rule.dayAnchor
        selectedAccountID = rule.account?.id
        selectedToAccountID = rule.toAccount?.id
        selectedCategoryID = rule.category?.id
        if let remaining = rule.remainingInstallments {
            isLoan = true
            installmentsText = "\(remaining)"
        }
        autoPost = rule.autoPost
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        store.saveRecurringRule(
            rule,
            name: name.trimmingCharacters(in: .whitespaces),
            amount: amount,
            type: type,
            account: accounts.first { $0.id == selectedAccountID },
            toAccount: accounts.first { $0.id == selectedToAccountID },
            category: categories.first { $0.id == selectedCategoryID },
            frequency: frequency,
            dayAnchor: startDate,
            remainingInstallments: isLoan ? Int(installmentsText) : nil,
            autoPost: autoPost
        )
        dismiss()
    }
}
