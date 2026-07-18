//
//  WatchTransactionListView.swift
//  FinWatch Watch App
//
//  Recent transactions, grouped by day like the iPhone list.
//

import SwiftUI
import SwiftData

struct WatchTransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var groupedTransactions: [(day: Date, items: [Transaction])] {
        let recent = transactions.prefix(50)
        let groups = Dictionary(grouping: recent) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        Group {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No transactions",
                    systemImage: "creditcard",
                    description: Text("Add one here or on your iPhone.")
                ).padding(.vertical, 16)
            } else {
                List {
                    ForEach(groupedTransactions, id: \.day) { group in
                        Section {
                            ForEach(group.items) { transaction in
                                row(transaction)
                            }
                        } header: {
                            Text(sectionTitle(for: group.day))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Transactions")
    }

    private func row(_ transaction: Transaction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: transaction.type == .transfer
                  ? "arrow.left.arrow.right"
                  : (transaction.category?.symbol ?? "questionmark"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(
                    transaction.type == .transfer
                        ? FinTheme.slate
                        : Color(hex: transaction.category?.colorHex ?? "#94A3B8"),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.name)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                // The day now lives in the section header; show where it hit.
                Text(transaction.account?.name ?? transaction.category?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(transaction.type == .transfer
                 ? CurrencyFormatter.string(transaction.amount)
                 : CurrencyFormatter.signedString(transaction.signedAmount))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(transaction.type == .income
                                 ? .green
                                 : (transaction.type == .transfer ? .secondary : .primary))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func sectionTitle(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
