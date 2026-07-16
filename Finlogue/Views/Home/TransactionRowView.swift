//
//  TransactionRowView.swift
//  Finlogue
//
//  Design-system list row: soft-tinted circular category chip, semibold
//  name over a muted "Category · Account" line, signed bold amount.
//

import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconSymbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 46, height: 46)
                .background(iconColor.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                    .lineLimit(1)
            }

            Spacer()

            Text(amountText)
                .font(.system(size: 15, weight: .bold))
                .kerning(-0.3)
                .foregroundStyle(amountColor)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private var isTransfer: Bool { transaction.type == .transfer }

    private var iconSymbol: String {
        if isTransfer { return "arrow.left.arrow.right" }
        if transaction.type == .income {
            return transaction.category?.symbol ?? "briefcase"
        }
        return transaction.category?.symbol ?? "questionmark"
    }

    private var iconColor: Color {
        if isTransfer { return FinTheme.ink600 }
        if transaction.type == .income { return FinTheme.green }
        return Color(hex: transaction.category?.colorHex ?? "#8C877B")
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
        switch transaction.type {
        case .income: "+\(CurrencyFormatter.string(transaction.amount))"
        case .expense: "-\(CurrencyFormatter.string(transaction.amount))"
        case .transfer: CurrencyFormatter.string(transaction.amount)
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: FinTheme.green
        case .expense: FinTheme.ink
        case .transfer: FinTheme.ink400
        }
    }
}
