//
//  TransactionEditorView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct TransactionEditorView: View {
    var transaction: Transaction?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var type: TransactionType = .expense
    @State private var name = ""
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedCategoryID: UUID?

    @AppStorage(AppSettings.lastAccountIDKey) private var lastAccountID = ""

    private var typeCategories: [Category] {
        categories.filter { $0.type == type }
    }

    /// Most recently used categories of the current type, for quick pick.
    private var recentCategories: [Category] {
        var seen: Set<UUID> = []
        var recents: [Category] = []
        for transaction in allTransactions.prefix(30) {
            guard let category = transaction.category,
                  category.type == type,
                  !seen.contains(category.id) else { continue }
            seen.insert(category.id)
            recents.append(category)
            if recents.count == 4 { break }
        }
        return recents
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ""))
    }

    /// Previously used names matching what's typed so far, most recent first.
    private var nameSuggestions: [Transaction] {
        let query = name.trimmingCharacters(in: .whitespaces).localizedLowercase
        guard !query.isEmpty else { return [] }
        var seen: Set<String> = []
        var suggestions: [Transaction] = []
        for candidate in allTransactions {
            let lower = candidate.name.localizedLowercase
            guard lower.contains(query), lower != query, seen.insert(lower).inserted else {
                continue
            }
            suggestions.append(candidate)
            if suggestions.count == 5 { break }
        }
        return suggestions
    }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty, selectedAccountID != nil else {
            return false
        }
        if type == .transfer {
            return selectedToAccountID != nil && selectedToAccountID != selectedAccountID
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    HStack {
                        Text(CurrencyFormatter.symbol())
                            .foregroundStyle(.secondary)
                        TextField("Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                    }

                    TextField("Name", text: $name)
                    if !nameSuggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(nameSuggestions) { suggestion in
                                    Button {
                                        apply(suggestion: suggestion)
                                    } label: {
                                        Text(suggestion.name)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray5), in: Capsule())
                                            .foregroundStyle(.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }

                if type != .transfer {
                    Section("Category") {
                        if !recentCategories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recentCategories) { category in
                                        categoryChip(category)
                                    }
                                }
                            }
                            .listRowSeparator(.hidden)
                        }
                        Picker("Category", selection: $selectedCategoryID) {
                            Text("None").tag(UUID?.none)
                            ForEach(typeCategories) { category in
                                Label(category.name, systemImage: category.symbol)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                    }
                }

                Section("Details") {
                    Picker(type == .transfer ? "From account" : "Account",
                           selection: $selectedAccountID) {
                        Text("Select account").tag(UUID?.none)
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
                    }
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
            }
            .navigationTitle(transaction == nil ? "New Transaction" : "Edit Transaction")
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
            .onChange(of: type) { _, newType in
                // Keep the category consistent with the selected type.
                if let id = selectedCategoryID,
                   categories.first(where: { $0.id == id })?.type != newType {
                    selectedCategoryID = nil
                }
                if newType == .transfer {
                    selectedCategoryID = nil
                    if name.isEmpty { name = "Transfer" }
                } else {
                    selectedToAccountID = nil
                }
            }
        }
    }

    private func categoryChip(_ category: Category) -> some View {
        let isSelected = selectedCategoryID == category.id
        return Button {
            withAnimation(.snappy) {
                selectedCategoryID = category.id
            }
            if name.isEmpty { name = category.name }
        } label: {
            Label(category.name, systemImage: category.symbol)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color(hex: category.colorHex) : Color(.systemGray5),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    /// Fills the name and, where still unset, borrows the suggestion's
    /// category and account so a repeat payment is a two-tap entry.
    private func apply(suggestion: Transaction) {
        name = suggestion.name
        if selectedCategoryID == nil,
           let category = suggestion.category, category.type == type {
            selectedCategoryID = category.id
        }
        if let account = suggestion.account {
            selectedAccountID = account.id
        }
        if amountText.isEmpty {
            amountText = String(format: "%g", suggestion.amount)
        }
    }

    private func populate() {
        guard let transaction else {
            if let uuid = UUID(uuidString: lastAccountID),
               accounts.contains(where: { $0.id == uuid }) {
                selectedAccountID = uuid
            } else {
                selectedAccountID = accounts.first?.id
            }
            return
        }
        type = transaction.type
        name = transaction.name
        amountText = String(format: "%g", transaction.amount)
        date = transaction.date
        note = transaction.note ?? ""
        selectedAccountID = transaction.account?.id
        selectedToAccountID = transaction.toAccount?.id
        selectedCategoryID = transaction.category?.id
    }

    private func save() {
        guard let amount else { return }
        let account = accounts.first { $0.id == selectedAccountID }
        let toAccount = accounts.first { $0.id == selectedToAccountID }
        let category = categories.first { $0.id == selectedCategoryID }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transaction {
            store.updateTransaction(
                transaction, type: type, name: name.trimmingCharacters(in: .whitespaces),
                amount: amount, date: date, note: trimmedNote.isEmpty ? nil : trimmedNote,
                account: account, toAccount: toAccount, category: category
            )
        } else {
            store.addTransaction(
                type: type, name: name.trimmingCharacters(in: .whitespaces),
                amount: amount, date: date, note: trimmedNote.isEmpty ? nil : trimmedNote,
                account: account, toAccount: toAccount, category: category
            )
        }
        if let account {
            lastAccountID = account.id.uuidString
        }
        dismiss()
    }
}
