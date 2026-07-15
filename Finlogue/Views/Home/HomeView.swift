//
//  HomeView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject private var store: TransactionStore
    @Environment(\.modelContext) private var context

    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var recurringRules: [RecurringRule]

    @State private var searchText = ""
    @State private var filter = TransactionFilter()
    @State private var showFilter = false
    @State private var editingTransaction: Transaction?
    @State private var showAddTransaction = Self.launchIntoAddSheet

    /// Test hook: `-showAddTransaction` opens the new-transaction sheet on launch.
    private static var launchIntoAddSheet: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showAddTransaction")
        #else
        return false
        #endif
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Good night"
        }
    }

    private var netWorth: Double {
        accounts.reduce(0) { total, account in
            account.type == .creditCard ? total - account.spent : total + account.currentBalance
        }
    }

    private var monthTransactions: [Transaction] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: .now) else { return [] }
        return transactions.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    private var monthIncome: Double {
        monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var monthExpense: Double {
        monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var visibleTransactions: [Transaction] {
        transactions.filter { transaction in
            guard filter.matches(transaction) else { return false }
            guard !searchText.isEmpty else { return true }
            let query = searchText.localizedLowercase
            return transaction.name.localizedLowercase.contains(query)
                || (transaction.category?.name.localizedLowercase.contains(query) ?? false)
                || (transaction.note?.localizedLowercase.contains(query) ?? false)
        }
    }

    private var groupedTransactions: [(day: Date, items: [Transaction])] {
        let groups = Dictionary(grouping: visibleTransactions) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private var upcoming: [(rule: RecurringRule, dueDate: Date)] {
        RecurringEngine.upcomingRules(in: context)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                if !accounts.isEmpty { accountsSection }
                if !upcoming.isEmpty { upcomingSection }
                transactionsSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .animation(.smooth(duration: 0.4), value: visibleTransactions.map(\.id))
            .navigationTitle(greeting)
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                            .contentTransition(.symbolEffect(.replace))
                            .animation(.snappy, value: filter.isActive)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                TransactionEditorView()
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(transaction: transaction)
            }
            .sheet(isPresented: $showFilter) {
                TransactionFilterView(filter: $filter)
            }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net worth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.string(netWorth))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.5), value: netWorth)
                }
                HStack(spacing: 12) {
                    summaryChip(
                        title: "Income", amount: monthIncome,
                        symbol: "arrow.down.circle.fill", tint: .green
                    )
                    summaryChip(
                        title: "Spent", amount: monthExpense,
                        symbol: "arrow.up.circle.fill", tint: .red
                    )
                }
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Income and spent are for \(Date.now.formatted(.dateTime.month(.wide)))")
        }
    }

    private func summaryChip(title: String, amount: Double, symbol: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.string(amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: amount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // The carousel lives in the section HEADER: inset-grouped rows apply a
    // rounded-corner mask that clips cards mid-scroll; headers don't.
    private var accountsSection: some View {
        Section {
        } header: {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader("Accounts")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Banks first, then cards, then others.
                        ForEach(accounts.grouped.flatMap(\.accounts)) { account in
                            AccountCardView(account: account)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }

    private var upcomingSection: some View {
        Section {
            ForEach(upcoming, id: \.rule.id) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.rule.name)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 4) {
                            Text(entry.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                            if let remaining = entry.rule.remainingInstallments {
                                Text("· \(remaining) left")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(entry.rule.amount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if !entry.rule.autoPost && entry.dueDate <= .now {
                        Button("Pay") {
                            store.postOccurrence(of: entry.rule, on: entry.dueDate)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        } header: {
            SectionHeader("Upcoming payments")
        }
    }

    @ViewBuilder
    private var transactionsSection: some View {
        if groupedTransactions.isEmpty {
            Section {
                ContentUnavailableView(
                    transactions.isEmpty ? "No transactions yet" : "No matches",
                    systemImage: transactions.isEmpty ? "creditcard" : "magnifyingglass",
                    description: Text(
                        transactions.isEmpty
                        ? "Tap + to log your first payment."
                        : "Try changing your search or filters."
                    )
                )
            }
        } else {
            ForEach(groupedTransactions, id: \.day) { group in
                Section {
                    ForEach(group.items) { transaction in
                        TransactionRowView(transaction: transaction)
                            .contentShape(Rectangle())
                            .onTapGesture { editingTransaction = transaction }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(transaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingTransaction = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                } header: {
                    SectionHeader(sectionTitle(for: group.day))
                }
            }
        }
    }

    private func sectionTitle(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
