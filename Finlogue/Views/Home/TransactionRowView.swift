//
//  TransactionRowView.swift
//  Finlogue
//
//  Design-system list row: soft-tinted circular category chip, semibold
//  name over a muted "Category · Account" line, signed bold amount. Shared
//  expenses show a split badge and your share; repayments read as income.
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
                .overlay(alignment: .bottomTrailing) { badge }

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

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.system(size: 15, weight: .bold))
                    .kerning(-0.3)
                    .foregroundStyle(amountColor)
                    .monospacedDigit()
                if transaction.isSplit && transaction.myShare > 0 {
                    Text("your share \(CurrencyFormatter.string(transaction.myShare))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                        .monospacedDigit()
                } else if transaction.charges > 0 {
                    Text("+\(CurrencyFormatter.string(transaction.charges)) fee")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Badge (settlement payer, or split indicator)

    @ViewBuilder
    private var badge: some View {
        if transaction.isSettlement, let person = transaction.person {
            initialsBadge(person.initials, color: Color(hex: person.colorHex))
        } else if transaction.isSplit {
            Image(systemName: "person.2.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(FinTheme.coral, in: Circle())
                .overlay(Circle().strokeBorder(FinTheme.paper, lineWidth: 1.5))
                .offset(x: 3, y: 3)
        }
    }

    private func initialsBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(color, in: Circle())
            .overlay(Circle().strokeBorder(FinTheme.paper, lineWidth: 1.5))
            .offset(x: 3, y: 3)
    }

    private var isTransfer: Bool { transaction.type == .transfer }

    private var iconSymbol: String {
        if isTransfer { return "arrow.left.arrow.right" }
        if transaction.isSettlement { return "arrow.down.left" }
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
        if transaction.isSettlement {
            return "Repayment" + (transaction.account.map { " · \($0.name)" } ?? "")
        }
        if isTransfer {
            let from = transaction.account?.name ?? "?"
            let to = transaction.toAccount?.name ?? "?"
            return "\(from) → \(to)"
        }
        var parts = [transaction.category?.name ?? "Uncategorized"]
        if let account = transaction.account {
            parts.append(account.name)
        }
        if transaction.isSplit {
            let count = (transaction.splits ?? []).count
            parts.append("split \(count) \(count == 1 ? "way" : "ways")")
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
