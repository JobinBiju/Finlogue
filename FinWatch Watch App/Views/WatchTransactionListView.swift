//
//  WatchTransactionListView.swift
//  FinWatch Watch App
//

import SwiftUI
import SwiftData

struct WatchTransactionListView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    var body: some View {
        Group {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No transactions",
                    systemImage: "creditcard",
                    description: Text("Add one here or on your iPhone.")
                )
            } else {
                List {
                    ForEach(transactions.prefix(50)) { transaction in
                        HStack(spacing: 8) {
                            Image(systemName: transaction.type == .transfer
                                  ? "arrow.left.arrow.right"
                                  : (transaction.category?.symbol ?? "questionmark"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    transaction.type == .transfer
                                        ? Color(hex: "#64748B")
                                        : Color(hex: transaction.category?.colorHex ?? "#94A3B8"),
                                    in: Circle()
                                )
                            VStack(alignment: .leading, spacing: 0) {
                                Text(transaction.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Text(transaction.date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
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
                }
            }
        }
        .navigationTitle("Transactions")
    }
}
