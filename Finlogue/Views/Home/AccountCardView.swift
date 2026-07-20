//
//  AccountCardView.swift
//  Finlogue
//
//  Design-system account cards: banks/cash cycle warm brand colors
//  (amber, coral, green, blue); credit cards are dark ink with a cream
//  figure, utilization bar, and billed/unbilled caption.
//

import SwiftUI

struct AccountCardView: View {
    let account: Account
    var paletteIndex: Int = 0

    private struct Palette {
        let background: Color
        let text: Color
        let secondaryText: Color
        let chipBackground: Color
        let glow: Color
    }

    private static let brightPalettes: [Palette] = [
        Palette(
            background: FinTheme.amber, text: FinTheme.ink,
            secondaryText: FinTheme.ink.opacity(0.55),
            chipBackground: FinTheme.ink.opacity(0.14),
            glow: FinTheme.amber.opacity(0.30)
        ),
        Palette(
            background: FinTheme.coral, text: .white,
            secondaryText: .white.opacity(0.8),
            chipBackground: .white.opacity(0.2),
            glow: FinTheme.coral.opacity(0.28)
        ),
        Palette(
            background: FinTheme.green, text: .white,
            secondaryText: .white.opacity(0.8),
            chipBackground: .white.opacity(0.2),
            glow: FinTheme.green.opacity(0.28)
        ),
        Palette(
            background: FinTheme.blue, text: .white,
            secondaryText: .white.opacity(0.8),
            chipBackground: .white.opacity(0.2),
            glow: FinTheme.blue.opacity(0.28)
        ),
    ]

    private static let darkPalette = Palette(
        background: FinTheme.ink, text: FinTheme.cream,
        secondaryText: FinTheme.cream.opacity(0.6),
        chipBackground: FinTheme.cream.opacity(0.16),
        glow: FinTheme.shadowTint.opacity(0.22)
    )

    /// Brand-tinted card for known banks, on white text.
    private static func brandPalette(background: Color) -> Palette {
        Palette(
            background: background, text: .white,
            secondaryText: .white.opacity(0.8),
            chipBackground: .white.opacity(0.2),
            glow: background.opacity(0.28)
        )
    }

    private var palette: Palette {
        if account.type == .creditCard {
            return Self.darkPalette
        }
        let name = account.name.localizedLowercase
        if name.contains("hdfc") {
            return Self.brandPalette(background: FinTheme.blue)
        }
        if name.contains("federal") {
            return Self.brandPalette(background: Color(hex: "#1D3FA6"))
        }
        if name.contains("axis") {
            return Self.brandPalette(background: Color(hex: "#AA1C41"))
        }
        return Self.brightPalettes[paletteIndex % Self.brightPalettes.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: account.type.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 26, height: 26)
                    .background(palette.chipBackground, in: Circle())
                Text(account.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if account.type == .creditCard {
                Text(CurrencyFormatter.string(account.spent))
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: account.spent)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                // Grouped cards share a limit, so the per-card gauge/available
                // are omitted here (the shared pool shows in Accounts settings).
                if account.creditGroup == nil, let limit = account.creditLimit, limit > 0 {
                    Capsule()
                        .fill(palette.chipBackground)
                        .frame(height: 6)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(FinTheme.amber)
                                    .frame(width: proxy.size.width * min(account.spent / limit, 1))
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .animation(.smooth(duration: 0.6), value: account.spent)
                }
                if let billed = account.billedOutstanding,
                   let unbilled = account.unbilledOutstanding {
                    Text("Billed \(CurrencyFormatter.string(billed)) · Unbilled \(CurrencyFormatter.string(unbilled))")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if account.creditGroup == nil, let limit = account.creditLimit, limit > 0 {
                    Text("Available \(CurrencyFormatter.string(max(limit - account.spent, 0)))")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                } else {
                    Text("Outstanding")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondaryText)
                }
            } else {
                Text(CurrencyFormatter.string(account.currentBalance))
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(palette.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: account.currentBalance)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Balance")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 212, height: 132, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.background)
                .overlay(alignment: .topTrailing) {
                    // Faint tone-on-tone motif, per the design's balance card.
                    Image(systemName: "sun.max")
                        .font(.system(size: 88, weight: .light))
                        .foregroundStyle(palette.text.opacity(0.10))
                        .offset(x: 24, y: -24)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .shadow(color: palette.glow, radius: 14, x: 0, y: 10)
    }
}
