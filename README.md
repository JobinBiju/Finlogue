# Finlogue

A modern, intuitive expense tracking app built with **SwiftUI** and **SwiftData**. Finlogue helps you manage your income and expenses, categorize transactions, and track multiple accounts seamlessly. Perfect for personal finance management on iOS.

---

## Table of Contents

- Features
- Screenshots
- Installation
- Usage
- Project Structure
- Contributing
- License

---

## Features

- **Transaction Management**:

  - Categorize transactions as Income or Expense.
  - Predefined categories (e.g., Salary, Food, Transport) with custom category creation.
  - Swipe to delete transactions with automatic account balance updates.

- **Account Management**:

  - Add and manage multiple bank accounts and credit cards.
  - Support for negative balances.
  - Track account balances updated with each transaction.

- **Intuitive UI**:

  - Home screen with a calendar-based list view of transactions (latest to oldest).
  - Persistent "Add Transaction" button with a bottom sheet for quick entry.
  - Settings view to manage accounts and categories via bottom sheets.

- **Data Persistence**:

  - Built with SwiftData for seamless data storage and retrieval.
  - Robust data models for transactions, accounts, and categories.

- **Customizable**:

  - Edit or delete categories in the Settings view.
  - Flexible date picker for transaction entries.

---
<!---
## Screenshots

| Home Screen | Add Transaction | Settings |
| --- | --- | --- |
|  |  |  |

---
-->

## Installation

### Prerequisites

- Xcode 16 or later
- iOS 17.0 or later
- Swift 5.9 or later

### Steps

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/JobinBiju/Finlogue.git
   cd Finlogue
   ```

2. **Open in Xcode**:

   - Open `Finlogue.xcodeproj` in Xcode.
   - Ensure the target is set to an iOS simulator or a connected device.

3. **Build and Run**:

   - Press `Cmd + R` to build and run the app.
   - No additional dependencies are required as Finlogue uses native SwiftUI and SwiftData.

---

## Usage

1. **Home Screen**:

   - View all transactions grouped by date, sorted from latest to oldest.
   - Swipe left on a transaction to delete it.
   - Tap the gear icon (top-right) to access Settings.
   - Tap the blue "+" button (bottom) to add a new transaction.

2. **Adding a Transaction**:

   - In the bottom sheet, select Income or Expense.
   - Choose a category, enter an amount, select an account, and pick a date.
   - Tap "Save" to record the transaction (account balance updates automatically).

3. **Settings**:

   - **Accounts**: Add new accounts with a name and initial balance (supports negative values).
   - **Categories**: Add new categories, specify Income or Expense type, or delete existing ones.
   - Use the respective bottom sheets for adding accounts or categories.

---

## Project Structure

```
Finlogue/
├── FinlogueApp.swift                  # Main app entry point
├── Models/
│   ├── Transaction.swift              # Transaction data model
│   ├── Account.swift                  # Account data model
│   ├── Category.swift                 # Category data model
├── Views/
│   ├── HomeView.swift                 # Main transaction list view
│   ├── TransactionRow.swift           # Transaction row component
│   ├── AddTransactionView.swift       # Transaction entry sheet
│   ├── SettingsView.swift             # Settings view
│   ├── AddAccountView.swift           # Account entry sheet
│   ├── AddCategoryView.swift          # Category entry sheet
├── ViewModels/
│   ├── ExpenseTrackerViewModel.swift  # View model for transaction logic
├── Preview Content/                   # SwiftUI previews
```

---

## Contributing

Contributions are welcome! Follow these steps to contribute to Finlogue:

1. **Fork the Repository**:

   - Click the "Fork" button on GitHub to create your own copy.

2. **Create a Branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make Changes**:

   - Implement your feature or bug fix.
   - Ensure code follows Swift best practices and includes appropriate tests.

4. **Submit a Pull Request**:

   - Push your changes to your fork.
   - Open a pull request with a clear description of your changes.

Please read our Contributing Guidelines for more details.

---

## License

This project is licensed under the MIT License. See the LICENSE file for details.

---

*Built with 💻 by Jobin. Powered by SwiftUI and SwiftData.*
