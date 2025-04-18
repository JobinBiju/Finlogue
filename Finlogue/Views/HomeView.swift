//
//  HomeView.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @StateObject private var viewModel = ExpenseTrackerViewModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                // Calendar List View
                List {
                    ForEach(groupedTransactions, id: \.0) { date, transactions in
                        Section(header: Text(date, style: .date)) {
                            ForEach(transactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                            .onDelete { indexSet in
                                deleteTransactions(at: indexSet, in: transactions)
                            }
                        }
                    }
                    
                }
            }
            .navigationTitle("Expense Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddTransaction) {
                AddTransactionView(viewModel: viewModel)
                    .presentationDetents([.large, .height(480)])
                    .presentationDragIndicator(.visible)
            }
            .overlay {
                Button(action: { viewModel.showAddTransaction = true }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .preferredColorScheme(.light)
    }
    
    private func deleteTransactions(at indexSet: IndexSet, in transactions: [Transaction]) {
            for index in indexSet {
                let transaction = transactions[index]
                // Reverse the balance update
                transaction.account.balance += transaction.type == .income ? -transaction.amount : transaction.amount
                modelContext.delete(transaction)
            }
            try? modelContext.save()
        }
    
    private var groupedTransactions: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.map { (date, transactions) in
            (date, transactions.sorted { $0.date > $1.date })
        }.sorted { $0.0 > $1.0 }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Transaction.self, Account.self, Category.self], inMemory: true)
}
