//
//  WatchHomeView.swift
//  FinWatch Watch App
//

import SwiftUI
import SwiftData

struct WatchHomeView: View {
    @EnvironmentObject private var syncEngine: WatchSyncEngine

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    private var netWorth: Double {
        accounts.reduce(0) { total, account in
            account.type == .creditCard ? total - account.spent : total + account.currentBalance
        }
    }

    private var monthSpent: Double {
        guard let interval = Calendar.current.dateInterval(of: .month, for: .now) else { return 0 }
        return transactions
            .filter { $0.type == .expense && $0.date >= interval.start && $0.date < interval.end }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Balance")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Text(CurrencyFormatter.string(netWorth))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.5), value: netWorth)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.red400)
                Text(CurrencyFormatter.string(monthSpent))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.5), value: monthSpent)
                Text("this month")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .minimumScaleFactor(0.7)
            .lineLimit(1)

            Spacer(minLength: 0)

            Group {
                if let lastSync = syncEngine.lastSyncDate {
                    Label(
                        lastSync.formatted(.relative(presentation: .named)),
                        systemImage: "checkmark.icloud"
                    )
                } else {
                    Label("Waiting for iPhone", systemImage: "iphone")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 8)
        .containerBackground(
            LinearGradient(
                colors: [Color(hex: "#1D4ED8").opacity(0.55), .black],
                startPoint: .top, endPoint: .bottom
            ),
            for: .navigation
        )
        .toolbar {
            // Matched 38pt circles, per the design's watch home spec.
            ToolbarItemGroup(placement: .bottomBar) {
                NavigationLink(destination: WatchTransactionListView()) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                NavigationLink(destination: WatchQuickAddView()) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(FinTheme.coral, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
