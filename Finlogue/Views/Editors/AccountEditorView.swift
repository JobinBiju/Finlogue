//
//  AccountEditorView.swift
//  Finlogue
//
//  Design-system account sheet: cream canvas, pill type segments,
//  paper detail cards.
//

import SwiftUI
import SwiftData

struct AccountEditorView: View {
    var account: Account?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CreditGroup.name) private var creditGroups: [CreditGroup]

    @State private var name = ""
    @State private var type: AccountType = .bank
    @State private var openingBalanceText = ""
    @State private var creditLimitText = ""
    @State private var outstandingText = ""
    @State private var statementDay: Int?
    // Shared credit limit
    @State private var useSharedLimit = false
    @State private var selectedGroupID: UUID?
    @State private var groupName = ""
    @State private var sharedLimitText = ""

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if type == .creditCard, useSharedLimit {
            guard !groupName.trimmingCharacters(in: .whitespaces).isEmpty,
                  (AmountInput.parse(sharedLimitText) ?? 0) > 0 else { return false }
        }
        return true
    }

    private func selectGroup(_ group: CreditGroup) {
        selectedGroupID = group.id
        groupName = group.name
        sharedLimitText = AmountInput.string(group.sharedLimit)
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
            .padding(.top, 12)
            .padding(.bottom, 32)

            ScrollView {
                VStack(spacing: 20) {
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
                    HStack(spacing: 4) {
                        Image(systemName: candidate.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(candidate.label)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(type == candidate ? .white : FinTheme.ink400)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
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
        .padding(4)
        .background(FinTheme.paper, in: Capsule())
    }

    private var balanceCard: some View {
        labeledCard("Starting balance") {
            amountRow(label: "Opening balance", text: $openingBalanceText)
        }
        .padding(.top, 12)
    }

    private var selectedGroup: CreditGroup? {
        creditGroups.first { $0.id == selectedGroupID }
    }

    private var creditLimitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledCard("Credit limit") {
                limitTypeSegments
                    .padding(.vertical, 8)
                if useSharedLimit {
                    Divider().overlay(FinTheme.lineSoft)
                    if !creditGroups.isEmpty {
                        HStack {
                            Text("Group")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(FinTheme.ink600)
                            Spacer()
                            Menu {
                                ForEach(creditGroups) { group in
                                    Button(group.name) { selectGroup(group) }
                                }
                                Button {
                                    selectedGroupID = nil
                                    groupName = ""
                                    sharedLimitText = ""
                                } label: {
                                    Label("New group…", systemImage: "plus")
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(selectedGroup?.name ?? "New group")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(FinTheme.ink)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(FinTheme.ink400)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                        Divider().overlay(FinTheme.lineSoft)
                    }
                    HStack {
                        Text("Group name")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FinTheme.ink600)
                        Spacer()
                        TextField("e.g. Axis", text: $groupName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FinTheme.ink)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 160)
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(FinTheme.lineSoft)
                    amountRow(label: "Shared limit", text: $sharedLimitText)
                } else {
                    Divider().overlay(FinTheme.lineSoft)
                    amountRow(label: "Credit limit", text: $creditLimitText)
                }
            }
            if useSharedLimit, let group = selectedGroup {
                Text("Currently \(CurrencyFormatter.string(group.available)) available across \(group.cards?.count ?? 0) card\((group.cards?.count ?? 0) == 1 ? "" : "s").")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                    .padding(.leading, 4)
            } else if useSharedLimit {
                Text("Cards in a group share one limit; any card can use whatever's left in the pool.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                    .padding(.leading, 4)
            }
        }
        .padding(.top, 12)
    }

    private var limitTypeSegments: some View {
        HStack(spacing: 0) {
            limitSegment(title: "Own limit", selected: !useSharedLimit) { useSharedLimit = false }
            limitSegment(title: "Shared", selected: useSharedLimit) { useSharedLimit = true }
        }
        .padding(3)
        .background(FinTheme.paperInset, in: Capsule())
    }

    private func limitSegment(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            FinHaptics.selection()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : FinTheme.ink400)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background { if selected { Capsule().fill(FinTheme.coral) } }
        }
        .buttonStyle(.plain)
    }

    private var creditCardCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            creditLimitCard
            labeledCard("Credit card") {
                amountRow(label: "Current outstanding", text: $outstandingText)
                Divider().overlay(FinTheme.lineSoft)
                HStack {
                    Text("Statement day")
                        .font(.system(size: 14, weight: .medium))
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
                                .font(.system(size: 14, weight: .semibold))
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
        .padding(.top, 12)
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
        if let group = account.creditGroup {
            useSharedLimit = true
            selectedGroupID = group.id
            groupName = group.name
            sharedLimitText = AmountInput.string(group.sharedLimit)
        }
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

        // Resolve or create the shared-limit group when in shared mode.
        var resolvedGroup: CreditGroup?
        if type == .creditCard, useSharedLimit {
            let trimmedGroupName = groupName.trimmingCharacters(in: .whitespaces)
            let sharedLimit = AmountInput.parse(sharedLimitText) ?? 0
            if !trimmedGroupName.isEmpty, sharedLimit > 0 {
                resolvedGroup = store.saveCreditGroup(
                    selectedGroup, name: trimmedGroupName, sharedLimit: sharedLimit
                )
            }
        }

        store.saveAccount(
            account,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            openingBalance: type == .creditCard ? cardOpening : opening,
            creditLimit: type == .creditCard ? limit : nil,
            statementDay: statementDay,
            creditGroup: resolvedGroup
        )
        FinHaptics.success()
        dismiss()
    }
}
