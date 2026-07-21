//
//  AccountCardView.swift
//  Finlogue
//
//  Design-system account cards: banks/cash cycle warm brand colors
//  (amber, coral, green, blue); credit cards are dark ink with a cream
//  figure, utilization bar, and billed/unbilled caption.
//

import SwiftUI
import UIKit

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

    /// Theme accent backgrounds cards cycle through — so cards recolor with the
    /// active theme instead of fixed brand colors.
    private static var accentBackgrounds: [Color] {
        [FinTheme.amber, FinTheme.coral, FinTheme.green, FinTheme.blue]
    }

    /// Builds a card palette from a background, picking white or dark text by
    /// the background's luminance so it stays legible in every theme.
    private static func palette(background: Color, glowOpacity: Double = 0.28) -> Palette {
        let text = readableText(on: background)
        return Palette(
            background: background,
            text: text,
            secondaryText: text.opacity(0.7),
            chipBackground: text.opacity(0.16),
            glow: background.opacity(glowOpacity)
        )
    }

    /// Near-black on light backgrounds, white on dark ones.
    private static func readableText(on background: Color) -> Color {
        let ui = UIColor(background)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? Color(hex: "#161616") : .white
    }

    private var palette: Palette {
        if account.type == .creditCard {
            // The credit-card tile fills with `ink` (a cream figure in dark
            // themes, near-black in light ones); text follows by luminance.
            return Self.palette(background: FinTheme.ink, glowOpacity: 0.22)
        }
        let colors = Self.accentBackgrounds
        return Self.palette(background: colors[paletteIndex % colors.count])
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
