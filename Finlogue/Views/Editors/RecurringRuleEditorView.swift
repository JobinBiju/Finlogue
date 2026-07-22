//
//  RecurringRuleEditorView.swift
//  Finlogue
//
//  Design-system recurring payment sheet, matching the transaction editor:
//  cream canvas, pill segments, big amount, paper detail cards.
//

import SwiftUI
import SwiftData

struct RecurringRuleEditorView: View {
    var rule: RecurringRule?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Person.name) private var people: [Person]

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
    @State private var splitDrafts: [SplitDraft] = []
    @State private var showSplitEditor = false

    private var typeCategories: [Category] {
        categories.filter { $0.type == type }
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

    private var showsSplit: Bool { type == .expense }
    private var splitTotalValue: Double { amount ?? 0 }
    private var othersShareDraft: Double {
        splitDrafts.reduce(0) { $0 + max(0, $1.amount) }
    }
    private var myShareDraft: Double { max(0, splitTotalValue - othersShareDraft) }

    private var splitSummary: String {
        guard !splitDrafts.isEmpty else { return "Just me" }
        let count = splitDrafts.count
        return "\(count) \(count == 1 ? "person" : "people") · you \(CurrencyFormatter.string(myShareDraft))"
    }

    private var canSave: Bool {
        guard let amount, amount > 0 else { return false }
        if isLoan, Int(installmentsText) == nil { return false }
        if type == .transfer,
           selectedToAccountID == nil || selectedToAccountID == selectedAccountID {
            return false
        }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                Text(rule == nil ? "New recurring payment" : "Edit recurring payment")
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
                    scheduleCard
                    loanCard
                    postingCard
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
        .sheet(isPresented: $showSplitEditor) {
            SplitEditorView(splits: $splitDrafts, total: splitTotalValue)
        }
        .onAppear(perform: populate)
        .onChange(of: type) { _, newType in
            if let id = selectedCategoryID,
               categories.first(where: { $0.id == id })?.type != newType {
                selectedCategoryID = nil
            }
            if newType == .transfer {
                selectedCategoryID = nil
            } else {
                selectedToAccountID = nil
            }
        }
    }

    // MARK: Pieces

    private var amountEntry: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(CurrencyFormatter.symbol())
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(FinTheme.ink400)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 48, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(FinTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize()
                .onChange(of: amountText) { _, newValue in
                    reformatAmount(newValue)
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var nameEntry: some View {
        TextField("Name (e.g. Netflix, Car EMI, Card bill)", text: $name)
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

    private var scheduleCard: some View {
        labeledCard("Schedule") {
            detailRow(label: "Repeats") {
                Menu {
                    ForEach(RecurrenceFrequency.allCases) { candidate in
                        Button(candidate.label) { frequency = candidate }
                    }
                } label: {
                    detailValue(frequency.label)
                }
            }
            Divider().overlay(FinTheme.lineSoft)
            detailRow(label: "First payment") {
                ThemedDateField(date: $startDate)
            }
        }
    }

    private var loanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledCard("Loan / EMI") {
                Toggle("Fixed number of installments", isOn: $isLoan)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                    .tint(FinTheme.coral)
                    .padding(.vertical, 8)
                if isLoan {
                    Divider().overlay(FinTheme.lineSoft)
                    detailRow(label: "Installments left") {
                        TextField("0", text: $installmentsText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FinTheme.ink)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }
            }
            footnote("For loans and EMIs the mandate stops automatically after the last installment.")
        }
    }

    private var postingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledCard("Posting") {
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
                } else {
                    detailRow(label: "Category") {
                        Menu {
                            Button("None") { selectedCategoryID = nil }
                            ForEach(typeCategories) { category in
                                Button {
                                    selectedCategoryID = category.id
                                } label: {
                                    Label(category.name, systemImage: category.symbol)
                                }
                            }
                        } label: {
                            detailValue(
                                categories.first { $0.id == selectedCategoryID }?.name ?? "None"
                            )
                        }
                    }
                }
                if showsSplit {
                    Divider().overlay(FinTheme.lineSoft)
                    Button {
                        FinHaptics.tap()
                        showSplitEditor = true
                    } label: {
                        detailRow(label: "Split") {
                            detailValue(splitSummary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Divider().overlay(FinTheme.lineSoft)
                Toggle("Post automatically", isOn: $autoPost)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                    .tint(FinTheme.coral)
                    .padding(.vertical, 8)
            }
            footnote(autoPost
                     ? "Payments are logged automatically when due."
                     : "You'll get an Upcoming reminder and confirm each payment.")
        }
    }

    // MARK: Building blocks

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

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(FinTheme.ink400)
            .padding(.leading, 4)
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

    private func populate() {
        guard let rule else {
            selectedAccountID = accounts.first?.id
            return
        }
        name = rule.name
        amountText = Self.formattedAmountString(rule.amount)
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
        splitDrafts = (rule.splits ?? []).compactMap { split in
            guard let personID = split.person?.id else { return nil }
            return SplitDraft(personID: personID, amount: split.shareAmount)
        }
    }

    private func save() {
        guard let amount else { return }
        let splits: [TransactionStore.SplitShare] = showsSplit
            ? splitDrafts.compactMap { draft in
                guard draft.amount > 0, let person = people.first(where: { $0.id == draft.personID })
                else { return nil }
                return (person: person, amount: draft.amount)
            }
            : []
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
            autoPost: autoPost,
            splits: splits
        )
        FinHaptics.success()
        dismiss()
    }
}
