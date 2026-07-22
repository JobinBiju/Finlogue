//
//  TransactionEditorView.swift
//  Finlogue
//
//  Design-system transaction sheet: cream canvas, pill segmented type
//  switch, big centered amount, paper cards, chip pickers.
//

import SwiftUI
import SwiftData

struct TransactionEditorView: View {
    var transaction: Transaction?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var type: TransactionType = .expense
    @State private var name = ""
    @State private var amountText = ""
    @State private var chargesText = ""
    @State private var date = Date.now
    @State private var note = ""
    @State private var selectedAccountID: UUID?
    @State private var selectedToAccountID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var splitDrafts: [SplitDraft] = []
    @State private var showSplitEditor = false

    @FocusState private var amountFocused: Bool

    @AppStorage(AppSettings.lastAccountIDKey) private var lastAccountID = ""

    private var typeCategories: [Category] {
        categories.filter { $0.type == type }
    }

    /// Categories of the current type, most recently used first — the chip row.
    private var orderedCategories: [Category] {
        var recentIDs: [UUID] = []
        for transaction in allTransactions.prefix(30) {
            if let id = transaction.category?.id, transaction.type == type,
               !recentIDs.contains(id) {
                recentIDs.append(id)
            }
        }
        return typeCategories.sorted { a, b in
            let ai = recentIDs.firstIndex(of: a.id) ?? Int.max
            let bi = recentIDs.firstIndex(of: b.id) ?? Int.max
            return ai == bi ? a.sortOrder < b.sortOrder : ai < bi
        }
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

    /// Locale-aware grouping for the amount field (e.g. 1,45,650 in en_IN).
    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func formattedAmountString(_ value: Double) -> String {
        amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%g", value)
    }

    private var amount: Double? {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let raw = amountText
            .replacingOccurrences(of: groupSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Double(raw)
    }

    /// Charges are optional and small — a plain lenient parse (no live grouping).
    private var chargesValue: Double {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let raw = chargesText
            .replacingOccurrences(of: groupSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return max(0, Double(raw) ?? 0)
    }

    /// Charges only apply to outflows; splitting is for expenses only.
    private var showsCharges: Bool { type != .income }
    private var showsSplit: Bool { type == .expense }

    /// The full outlay being divided when splitting.
    private var splitTotal: Double { (amount ?? 0) + chargesValue }

    /// Sum of friends' shares currently entered.
    private var othersShareDraft: Double {
        splitDrafts.reduce(0) { $0 + max(0, $1.amount) }
    }

    private var myShareDraft: Double { max(0, splitTotal - othersShareDraft) }

    /// Re-groups the typed amount live, preserving a partially typed fraction.
    private func reformatAmount(_ text: String) {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        var raw = text.replacingOccurrences(of: groupSeparator, with: "")
        raw = String(raw.filter { $0.isNumber || String($0) == decimalSeparator })

        let parts = raw.components(separatedBy: decimalSeparator)
        let integerPart = parts.first ?? ""
        let hasSeparator = parts.count > 1
        let fractionPart = String(parts.dropFirst().joined().prefix(2))

        var result = integerPart
        if !integerPart.isEmpty, let intValue = Double(integerPart) {
            result = Self.formattedAmountString(intValue)
        }
        if hasSeparator {
            result += decimalSeparator + fractionPart
        }
        if result != amountText {
            amountText = result
        }
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
                Text(transaction == nil ? "New transaction" : "Edit transaction")
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
            .padding(.top, 12)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 24) {
                    amountEntry
                    nameEntry
                    typeSegments
                    if type != .transfer {
                        categoryChips
                    }
                    detailsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .sheet(isPresented: $showSplitEditor) {
            SplitEditorView(splits: $splitDrafts, total: splitTotal)
        }
        .onAppear(perform: populate)
        .onChange(of: type) { _, newType in
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

    // MARK: Type segments (pill)

    private var typeSegments: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases) { candidate in
                Button {
                    FinHaptics.selection()
                    withAnimation(.snappy(duration: 0.25)) {
                        type = candidate
                    }
                } label: {
                    Text(candidate.label)
                        .font(.system(size: 14, weight: .semibold))
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

    // MARK: Amount

    private var amountEntry: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(CurrencyFormatter.symbol())
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(FinTheme.ink400)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .onChange(of: amountText) { _, newValue in
                    reformatAmount(newValue)
                }
                .font(.system(size: 64, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(FinTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = true }
    }

    // MARK: Name + suggestions

    private var nameEntry: some View {
        VStack(spacing: 10) {
            TextField("Name", text: $name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FinTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .finCard(radius: 16)
            if !nameSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(nameSuggestions) { suggestion in
                            Button {
                                FinHaptics.tap()
                                apply(suggestion: suggestion)
                            } label: {
                                Text(suggestion.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(FinTheme.ink600)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(FinTheme.paperInset, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Category chips

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .finSectionLabel()
                .padding(.leading, 4)
            FlowLayout(spacing: 8) {
                ForEach(orderedCategories) { category in
                    let isSelected = selectedCategoryID == category.id
                    Button {
                        FinHaptics.selection()
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedCategoryID = isSelected ? nil : category.id
                        }
                        if name.isEmpty { name = category.name }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 13, weight: .semibold))
                            Text(category.name)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(isSelected ? .white : FinTheme.ink600)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            isSelected ? Color(hex: category.colorHex) : FinTheme.paper,
                            in: Capsule()
                        )
                        .shadow(color: FinTheme.shadowTint.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Details card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                detailRow(label: type == .transfer ? "From account" : "Account") {
                    Menu {
                        accountMenuItems(selection: $selectedAccountID)
                    } label: {
                        detailValue(accounts.first { $0.id == selectedAccountID }?.name ?? "Select")
                    }
                }
                Divider().overlay(FinTheme.lineSoft)
                if type == .transfer {
                    detailRow(label: "To account") {
                        Menu {
                            accountMenuItems(
                                selection: $selectedToAccountID,
                                excluding: selectedAccountID
                            )
                        } label: {
                            detailValue(accounts.first { $0.id == selectedToAccountID }?.name ?? "Select")
                        }
                    }
                    Divider().overlay(FinTheme.lineSoft)
                }
                if showsCharges {
                    detailRow(label: "Charges") {
                        HStack(spacing: 3) {
                            Text(CurrencyFormatter.symbol())
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                            TextField("0", text: $chargesText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FinTheme.ink)
                                .multilineTextAlignment(.trailing)
                                .fixedSize()
                        }
                    }
                    Divider().overlay(FinTheme.lineSoft)
                }
                if showsSplit {
                    Button {
                        FinHaptics.tap()
                        showSplitEditor = true
                    } label: {
                        detailRow(label: "Split") {
                            detailValue(splitSummary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(FinTheme.lineSoft)
                }
                detailRow(label: "Date") {
                    ThemedDateField(date: $date, components: [.date, .hourAndMinute])
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

    /// Right-hand summary on the Split row.
    private var splitSummary: String {
        guard !splitDrafts.isEmpty else { return "Just me" }
        let count = splitDrafts.count
        return "\(count) \(count == 1 ? "person" : "people") · you \(CurrencyFormatter.string(myShareDraft))"
    }

    @ViewBuilder
    private func accountMenuItems(selection: Binding<UUID?>, excluding: UUID? = nil) -> some View {
        ForEach(accounts.filter { $0.id != excluding }.grouped, id: \.group) { entry in
            Section(entry.group.rawValue) {
                ForEach(entry.accounts) { account in
                    Button(account.name) {
                        selection.wrappedValue = account.id
                    }
                }
            }
        }
    }

    // MARK: Logic (unchanged)

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
            amountText = Self.formattedAmountString(suggestion.amount)
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
        amountText = Self.formattedAmountString(transaction.amount)
        chargesText = transaction.charges > 0 ? Self.formattedAmountString(transaction.charges) : ""
        date = transaction.date
        note = transaction.note ?? ""
        selectedAccountID = transaction.account?.id
        selectedToAccountID = transaction.toAccount?.id
        selectedCategoryID = transaction.category?.id
        splitDrafts = (transaction.splits ?? []).compactMap { split in
            guard let personID = split.person?.id else { return nil }
            return SplitDraft(personID: personID, amount: split.shareAmount)
        }
    }

    private func dismissKeyboard() {
        amountFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    private func save() {
        guard let amount else { return }
        let account = accounts.first { $0.id == selectedAccountID }
        let toAccount = accounts.first { $0.id == selectedToAccountID }
        let category = categories.first { $0.id == selectedCategoryID }
        let charges = showsCharges ? chargesValue : 0
        let splits: [TransactionStore.SplitShare] = showsSplit
            ? splitDrafts.compactMap { draft in
                guard draft.amount > 0, let person = people.first(where: { $0.id == draft.personID })
                else { return nil }
                return (person: person, amount: draft.amount)
            }
            : []
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let transaction {
            store.updateTransaction(
                transaction, type: type, name: name.trimmingCharacters(in: .whitespaces),
                amount: amount, charges: charges, date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                account: account, toAccount: toAccount, category: category, splits: splits
            )
        } else {
            store.addTransaction(
                type: type, name: name.trimmingCharacters(in: .whitespaces),
                amount: amount, charges: charges, date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                account: account, toAccount: toAccount, category: category, splits: splits
            )
        }
        if let account {
            lastAccountID = account.id.uuidString
        }
        FinHaptics.success()
        dismiss()
    }
}
