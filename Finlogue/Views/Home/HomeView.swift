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

    @State private var searchText = Self.initialSearchText

    /// Test hook: `-searchText <query>` pre-fills the home search field.
    private static var initialSearchText: String {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-searchText"),
           arguments.indices.contains(index + 1) {
            return arguments[index + 1]
        }
        #endif
        return ""
    }
    @State private var filter = TransactionFilter()

    /// Test hook: `-showFilter` opens the filter sheet on launch.
    private static var launchIntoFilter: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showFilter")
        #else
        return false
        #endif
    }
    @State private var showFilter = Self.launchIntoFilter
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

    /// Settlement (repayment) transactions are reimbursements, not real income,
    /// so they're left out of the tiles (they still move the account balance).
    private var monthIncome: Double {
        monthTransactions
            .filter { $0.type == .income && !$0.isSettlement }
            .reduce(0) { $0 + $1.amount }
    }

    /// Only your own share of each expense counts as spending; amounts split out
    /// to friends are excluded.
    private var monthExpense: Double {
        monthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.myShare }
    }

    /// Net-worth movement this month, as a percentage of where the month started.
    private var monthTrendPercent: Double? {
        let change = monthIncome - monthExpense
        let base = netWorth - change
        guard base > 0, change != 0 else { return nil }
        return change / base * 100
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

    /// While searching, everything above the transaction list gets out of the way.
    private var isSearching: Bool {
        !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                if !isSearching {
                    if !accounts.isEmpty { accountsSection }
                    if !upcoming.isEmpty { upcomingSection }
                }
                transactionsSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .animation(.smooth(duration: 0.4), value: visibleTransactions.map(\.id))
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: Header (greeting + actions + search + net worth)

    private var headerSection: some View {
        Section {
        } header: {
            VStack(spacing: 20) {
                HStack {
                    Button {
                        FinHaptics.tap()
                        showFilter = true
                    } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "slider.horizontal.3")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(filter.isActive ? FinTheme.coral : FinTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(FinTheme.paper, in: Circle())
                            .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 3) {
                        Text(greeting)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(FinTheme.ink)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(size: 12))
                            .foregroundStyle(FinTheme.ink400)
                    }

                    Spacer()

                    Button {
                        FinHaptics.tap()
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(FinTheme.coral, in: Circle())
                            .shadow(color: FinTheme.coral.opacity(0.28), radius: 12, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                    TextField("Search transactions", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundStyle(FinTheme.ink)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(FinTheme.ink400)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(FinTheme.paper, in: Capsule())
                .shadow(color: FinTheme.shadowTint.opacity(0.05), radius: 4, x: 0, y: 2)

                if !isSearching {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                    Text(CurrencyFormatter.string(netWorth))
                        .font(.system(size: 40, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(FinTheme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.5), value: netWorth)
                    if let trend = monthTrendPercent {
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: trend >= 0
                                      ? "chart.line.uptrend.xyaxis"
                                      : "chart.line.downtrend.xyaxis")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("\(trend >= 0 ? "+" : "")\(trend, specifier: "%.1f")%")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(trend >= 0 ? FinTheme.green : FinTheme.red)
                            Text("this month")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(FinTheme.ink600)
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .finCard()
                .transition(.opacity)

                HStack(spacing: 14) {
                    summaryTile(
                        title: "Income", amount: monthIncome,
                        symbol: "arrow.down.left", chipBackground: FinTheme.lime100,
                        chipForeground: FinTheme.green
                    )
                    summaryTile(
                        title: "Spent", amount: monthExpense,
                        symbol: "arrow.up.right", chipBackground: FinTheme.tintPeach,
                        chipForeground: FinTheme.red
                    )
                }
                // Match the 14pt tile gap: the header stack's 20pt spacing minus 6.
                .padding(.top, -6)
                .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: isSearching)
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 4)
        }
    }

    // MARK: Income / Spent tiles

    private func summaryTile(
        title: String, amount: Double, symbol: String,
        chipBackground: Color, chipForeground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(chipForeground)
                .frame(width: 40, height: 40)
                .background(chipBackground, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FinTheme.ink400)
                Text(CurrencyFormatter.string(amount))
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundStyle(FinTheme.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: amount)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .finCard()
    }

    // MARK: Accounts carousel

    private var accountsSection: some View {
        Section {
        } header: {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accounts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Banks first, then cards, then others.
                        ForEach(Array(accounts.grouped.flatMap(\.accounts).enumerated()),
                                id: \.element.id) { index, account in
                            AccountCardView(account: account, paletteIndex: index)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
            .textCase(nil)
            .finHeaderAligned()
        }
    }

    // MARK: Upcoming payments

    private var upcomingSection: some View {
        Section {
            ForEach(upcoming, id: \.rule.id) { entry in
                HStack(spacing: 12) {
                    Image(systemName: entry.rule.category?.symbol ?? "calendar")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(FinTheme.amber500)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.tintAmber, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.rule.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FinTheme.ink)
                        HStack(spacing: 4) {
                            Text(entry.dueDate.formatted(.dateTime.day().month(.abbreviated)))
                            if let remaining = entry.rule.remainingInstallments {
                                Text("· \(remaining) left")
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
                    }
                    Spacer()
                    Text(CurrencyFormatter.string(entry.rule.amount))
                        .font(.system(size: 15, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(FinTheme.ink)
                        .monospacedDigit()
                    if !entry.rule.autoPost && entry.dueDate <= .now {
                        Button {
                            FinHaptics.success()
                            store.postOccurrence(of: entry.rule, on: entry.dueDate)
                        } label: {
                            Text("Pay")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 34)
                                .background(FinTheme.coral, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(FinTheme.paper)
                .listRowSeparatorTint(FinTheme.lineSoft)
            }
        } header: {
            Text("Upcoming payments")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FinTheme.ink)
                .textCase(nil)
                .finHeaderAligned()
                .padding(.bottom, 4)
        }
    }

    // MARK: Transactions

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
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(groupedTransactions, id: \.day) { group in
                Section {
                    ForEach(group.items) { transaction in
                        TransactionRowView(transaction: transaction)
                            .listRowBackground(FinTheme.paper)
                            .listRowSeparatorTint(FinTheme.lineSoft)
                            .contentShape(Rectangle())
                            .onTapGesture { editingTransaction = transaction }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    FinHaptics.warning()
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
