//
//  TransactionRowView.swift
//  Finlogue
//

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(amountText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(amountColor)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    private var isTransfer: Bool { transaction.type == .transfer }

    private var iconSymbol: String {
        isTransfer ? "arrow.left.arrow.right" : (transaction.category?.symbol ?? "questionmark")
    }

    private var iconColor: Color {
        isTransfer ? Color(hex: "#64748B") : Color(hex: transaction.category?.colorHex ?? "#94A3B8")
    }

    private var subtitle: String {
        if isTransfer {
            let from = transaction.account?.name ?? "?"
            let to = transaction.toAccount?.name ?? "?"
            return "\(from) → \(to)"
        }
        var parts = [transaction.category?.name ?? "Uncategorized"]
        if let account = transaction.account {
            parts.append(account.name)
        }
        return parts.joined(separator: " · ")
    }

    private var amountText: String {
        isTransfer
            ? CurrencyFormatter.string(transaction.amount)
            : CurrencyFormatter.signedString(transaction.signedAmount)
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: .green
        case .expense: .primary
        case .transfer: .secondary
        }
    }
}
