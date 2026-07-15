# Finlogue

A personal finance tracker for **iPhone and Apple Watch**, built with **SwiftUI**, **SwiftData**, and **WatchConnectivity**. Log payments from bank accounts, credit cards, and cash; categorize spending; set budgets; automate recurring payments and EMIs — and do quick entry right from your wrist, with transactions syncing both ways between phone and watch.

---

## Features

### iOS app

- **Transactions** — add, edit, delete; income vs expense; notes; grouped by day with search and filters (type, account, category, date range).
- **Accounts** — bank, credit card, and cash accounts. Balances are *computed* from transactions (no drift). Credit cards track outstanding spend and available credit against the limit.
- **Categories** — customizable with SF Symbol icons and colors; sensible defaults seeded on first launch.
- **Insights** — Swift Charts: spending-by-category donut, cumulative daily spend trend, and income vs expense across the last 6 months, with a month selector.
- **Budgets** — monthly limit per category with progress bars and over-budget warnings.
- **Recurring payments & mandates** — subscriptions, EMIs, and loan auto-pay. Auto-post rules log the transaction when due (with catch-up for missed periods, each posted exactly once); confirm-first rules appear as Upcoming reminders on Home. Loans stop automatically after the last installment.
- **Display currency** — INR by default, configurable in Settings.
- Full **dark mode** support.

### Watch app

- Balance and this-month spend at a glance, plus the recent transaction list.
- **Quick add** in three taps: amount (preset chips or digital crown) → category (recently used first) → account (last used first). Saves locally and syncs to the phone.

### Sync (WatchConnectivity)

- **Phone → Watch**: full snapshot via `updateApplicationContext` (durable, survives unreachability, deletions propagate) plus an instant `sendMessage` when reachable.
- **Watch → Phone**: new transactions via `sendMessage` with a queued `transferUserInfo` fallback; the phone dedupes by UUID, so double delivery is harmless.
- The phone is the source of truth; the watch keeps its own local SwiftData store so it works offline.

---

## Installation

### Prerequisites

- Xcode 16 or later
- iOS 17.6+ / watchOS 11+

### Steps

1. Clone and open:

   ```bash
   git clone https://github.com/JobinBiju/Finlogue.git
   cd Finlogue
   open Finlogue.xcodeproj
   ```

2. Select the **Finlogue** scheme and run (`Cmd + R`). The watch app is embedded and installs with the iOS app on a paired watch.

3. To test sync in simulators, use a paired iPhone + Watch simulator pair (`xcrun simctl list pairs`).

### Debug launch arguments

- `-seedSampleData` — fills the store with two months of sample data (accounts, transactions, budgets, recurring rules).
- `-initialTab <0-3>` — opens the app on a specific tab.

---

## Project Structure

```
Finlogue/
├── Shared/                      # Compiled into BOTH targets
│   ├── Models/                  # SwiftData @Models: Transaction, Account, Category,
│   │                            # Budget, RecurringRule (+ enums)
│   ├── Sync/                    # Codable DTOs, SnapshotBuilder,
│   │                            # PhoneSyncEngine (iOS), WatchSyncEngine (watchOS)
│   └── Support/                 # AppSettings, CurrencyFormatter, Color(hex:)
├── Finlogue/                    # iOS app
│   ├── FinlogueApp.swift
│   ├── Services/                # TransactionStore (single mutation point),
│   │                            # RecurringEngine, InsightsService
│   └── Views/                   # Home, Editors, Insights, Budgets, Settings
└── FinWatch Watch App/          # watchOS app
    ├── FinWatchApp.swift
    └── Views/                   # WatchHome, WatchTransactionList, WatchQuickAdd
```

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

*Built with 💻 by Jobin. Powered by SwiftUI, SwiftData, and WatchConnectivity.*
