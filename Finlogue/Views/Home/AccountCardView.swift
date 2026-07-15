//
//  AccountCardView.swift
//  Finlogue
//

import SwiftUI

struct AccountCardView: View {
    let account: Account

    /// Brand-matched gradients, detected from the account name.
    /// Bank accounts get the brighter blend; credit cards a deeper, darker one.
    private var gradient: LinearGradient {
        let name = account.name.localizedLowercase
        let colors: [Color]

        if name.contains("hdfc") {
            colors = account.type == .creditCard
                ? [Color(hex: "#101C52"), Color(hex: "#2563EB")]
                : [Color(hex: "#2563EB"), Color(hex: "#7C3AED")]
        } else if name.contains("axis") {
            colors = account.type == .creditCard
                ? [Color(hex: "#4A0C1E"), Color(hex: "#AA1C41")]
                : [Color(hex: "#AA1C41"), Color(hex: "#E5457A")]
        } else if name.contains("federal") {
            colors = [Color(hex: "#112E81"), Color(hex: "#3B62D8")]
        } else {
            switch account.type {
            case .bank:
                colors = [Color(hex: "#2563EB"), Color(hex: "#7C3AED")]
            case .creditCard:
                colors = [Color(hex: "#0F172A"), Color(hex: "#475569")]
            case .cash:
                colors = [Color(hex: "#059669"), Color(hex: "#14B8A6")]
            }
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: account.type.symbol)
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))

            Spacer(minLength: 0)

            if account.type == .creditCard {
                Text(CurrencyFormatter.string(account.spent))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: account.spent)
                if let limit = account.creditLimit, limit > 0 {
                    ProgressView(value: min(account.spent / limit, 1))
                        .tint(account.spent > limit ? .red : .white)
                        .animation(.smooth(duration: 0.6), value: account.spent)
                }
                if let billed = account.billedOutstanding,
                   let unbilled = account.unbilledOutstanding {
                    Text("Billed \(CurrencyFormatter.string(billed)) · Unbilled \(CurrencyFormatter.string(unbilled))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if let limit = account.creditLimit, limit > 0 {
                    Text("Available \(CurrencyFormatter.string(max(limit - account.spent, 0)))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Text("Outstanding")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                Text(CurrencyFormatter.string(account.currentBalance))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: account.currentBalance)
                Text("Balance")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(16)
        .frame(width: 192, height: 112, alignment: .leading)
        .background(gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
