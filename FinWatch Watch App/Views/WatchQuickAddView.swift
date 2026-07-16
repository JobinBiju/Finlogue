//
//  WatchQuickAddView.swift
//  FinWatch Watch App
//
//  Three quick steps: amount → category → account, then save.
//

import SwiftUI
import SwiftData
import WatchKit

struct WatchQuickAddView: View {
    @EnvironmentObject private var syncEngine: WatchSyncEngine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var recentTransactions: [Transaction]

    @AppStorage(AppSettings.lastAccountIDKey) private var lastAccountID = ""

    @State private var type: TransactionType = .expense
    @State private var amount: Double = 0
    @State private var crownValue: Double = 0
    @State private var step: Step = Self.initialStep
    @State private var selectedCategory: Category?

    /// Test hook: `-quickAddAccountStep` opens directly on the account step.
    private static var initialStep: Step {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-quickAddAccountStep") {
            return .account
        }
        #endif
        return .amount
    }

    private enum Step {
        case amount, category, account
    }

    private let presets: [Double] = [50, 100, 500, 2000]

    /// Categories of the current type, most recently used first.
    private var orderedCategories: [Category] {
        let typed = categories.filter { $0.type == type }
        var recentIDs: [UUID] = []
        for transaction in recentTransactions.prefix(30) {
            if let id = transaction.category?.id, transaction.type == type, !recentIDs.contains(id) {
                recentIDs.append(id)
            }
        }
        return typed.sorted { a, b in
            let ai = recentIDs.firstIndex(of: a.id) ?? Int.max
            let bi = recentIDs.firstIndex(of: b.id) ?? Int.max
            return ai == bi ? a.sortOrder < b.sortOrder : ai < bi
        }
    }

    var body: some View {
        Group {
            switch step {
            case .amount: amountStep
            case .category: categoryStep
            case .account: accountStep
            }
        }
    }

    // MARK: Step 1 — amount

    private var amountStep: some View {
        VStack(spacing: 8) {
            Text(CurrencyFormatter.string(amount))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(amount > 0 ? .primary : Color.secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
                .focusable()
                .digitalCrownRotation(
                    $crownValue,
                    from: 0, through: 100_000, by: 10,
                    sensitivity: .high,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: crownValue) { _, newValue in
                    withAnimation(.snappy) {
                        amount = (newValue / 10).rounded() * 10
                    }
                }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)],
                spacing: 4
            ) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        withAnimation(.snappy) {
                            amount = preset
                            crownValue = preset
                        }
                    } label: {
                        Text(CurrencyFormatter.string(preset))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(amount == preset ? FinTheme.coral : .gray)
                }
            }
        }
        .padding(.horizontal, 4)
        .containerBackground(Color.black, for: .navigation)
        .navigationTitle(type.label)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    type = (type == .expense) ? .income : .expense
                    selectedCategory = nil
                } label: {
                    Image(systemName: type == .expense
                          ? "arrow.up.right.circle"
                          : "arrow.down.left.circle")
                }
                .tint(type == .expense ? .red : .green)
                Spacer()
                Button {
                    step = .category
                } label: {
                    Image(systemName: "chevron.right")
                }
                .controlSize(.large)
                .background(amount > 0 ? FinTheme.coral : Color.gray.opacity(0.4), in: Circle())
                .disabled(amount <= 0)
            }
        }
    }

    // MARK: Step 2 — category

    private var categoryStep: some View {
        List {
            ForEach(orderedCategories) { category in
                Button {
                    selectedCategory = category
                    step = .account
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: category.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color(hex: category.colorHex), in: Circle())
                        Text(category.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
            Button {
                selectedCategory = nil
                step = .account
            } label: {
                Label("Skip", systemImage: "arrow.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Category")
    }

    // MARK: Step 3 — account

    private var accountStep: some View {
        List {
            ForEach(orderedAccounts.grouped, id: \.group) { entry in
                Section {
                    ForEach(entry.accounts) { account in
                        Button {
                            save(account: account)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: account.type.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(
                                        account.type == .creditCard
                                            ? FinTheme.coral
                                            : FinTheme.blue.opacity(0.85),
                                        in: Circle()
                                    )
                                Text(account.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                    }
                } header: {
                    Text(entry.group.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if accounts.isEmpty {
                Text("No accounts yet. Add one on your iPhone first.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Account")
    }

    /// Last-used account first.
    private var orderedAccounts: [Account] {
        guard let lastID = UUID(uuidString: lastAccountID),
              let index = accounts.firstIndex(where: { $0.id == lastID }) else { return accounts }
        var ordered = accounts
        ordered.insert(ordered.remove(at: index), at: 0)
        return ordered
    }

    private func save(account: Account) {
        let transaction = Transaction(
            type: type,
            name: selectedCategory?.name ?? (type == .income ? "Income" : "Payment"),
            amount: amount,
            date: .now,
            account: account,
            category: selectedCategory
        )
        context.insert(transaction)
        try? context.save()
        syncEngine.send(transaction: TransactionDTO(from: transaction))
        lastAccountID = account.id.uuidString
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}
