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
    @Query(sort: \Account.balance, order: .reverse) private var accounts: [Account]
    @StateObject private var viewModel = ExpenseTrackerViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    ZStack {
                        VStack {
                            Image("home_rect")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                            Spacer()
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Good Morning")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Jobin Biju")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                NavigationLink(destination: SettingsView()) {
                                    Image(systemName: "gear")
                                        .resizable()
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .padding(8)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 64)
                            .padding(.bottom, 24)

                            ZStack {
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .foregroundStyle(.clear)
                                        .frame(maxWidth: .infinity, maxHeight: 83)
                                        .background(.green10)
                                        .blur(radius: 24)
                                        .opacity(0.8)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Total Balance")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(totalBalance, format: .currency(code: "INR"))
                                        .font(.system(size: 30, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.bottom, 30)
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Income")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white)
                                            Text(0, format: .currency(code: "INR"))
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("Expense")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundStyle(.white)
                                            Text(0, format: .currency(code: "INR"))
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .padding(20)
                                .background(.green8)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 360)
                    .padding(.bottom, 32)
                    
                    if(!groupedTransactions.isEmpty){
                        Text("Transactions")
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    
                    if(!groupedTransactions.isEmpty) {
                        VStack(alignment: .leading) {
                            ForEach(groupedTransactions, id: \.0) { date, transactions in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(date, style: .date)
                                        .padding(.bottom, 12)
                                    
                                    ForEach(transactions) { transaction in
                                        TransactionRow(transaction: transaction)
                                            .padding(.bottom, 12)
                                    }
//                                    .onDelete { indexSet in
//                                        deleteTransactions(at: indexSet, in: transactions)
//                                    }
                                }
                                .padding(.bottom, 16)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "indianrupeesign.bank.building")
                                .resizable()
                                .frame(width: 56, height: 56)
                                .foregroundStyle(.green8)
                            Text("Add some transactions \nto get started!")
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 64)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddTransaction) {
                AddTransactionView(viewModel: viewModel)
                    .presentationDetents([.large, .height(460)])
                    .presentationDragIndicator(.visible)
            }
            .overlay {
                Button(action: { viewModel.showAddTransaction = true }) {
                    HStack {
                        Image(systemName: "plus")
                            .resizable()
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                        Text("ADD")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(.green8)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()
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
    
    private var totalBalance: Double {
        return accounts.reduce(0) { result, account in
            result + account.balance
        }
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
