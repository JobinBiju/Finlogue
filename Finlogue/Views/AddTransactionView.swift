//
//  AddTransactionView.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ExpenseTrackerViewModel
    @Query private var categories: [Category]
    @Query private var accounts: [Account]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add Transaction")
                    .font(Font.system(size: 28, weight: .bold))
                    .padding(.horizontal)
                    .padding(.top, 32)
                List {
                    Picker("Type", selection: $viewModel.selectedTransactionType) {
                        Text("Income").tag(TransactionType.income)
                        Text("Expense").tag(TransactionType.expense)
                    }
                    
                    Picker("Category", selection: $viewModel.selectedCategory) {
                        Text("Select Category").tag("")
                        ForEach(categories.filter { $0.type == viewModel.selectedTransactionType }) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $viewModel.name)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", text: $viewModel.amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Account", selection: $viewModel.selectedAccount) {
                        Text("Select Account").tag(nil as Account?)
                        ForEach(accounts) { account in
                            Text(account.name).tag(account as Account?)
                        }
                    }
                    
                    DatePicker("Date", selection: $viewModel.transactionDate, displayedComponents: [.date])
                        .padding(.vertical, 2)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .padding(.bottom, 12)
                .padding(.top, 16)
                HStack(spacing: 4) {
                    Button {
                        viewModel.saveTransaction(context: modelContext, categories: categories, accounts: accounts)
                        dismiss()
                    } label: {
                        Text("SAVE")
                            .font(Font.system(size: 18, weight: .medium))
                            .kerning(0.96)
                            .foregroundStyle(.white)
                            .disabled(viewModel.selectedCategory.isEmpty || viewModel.amount.isEmpty || viewModel.selectedAccount == nil)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity)
                            .background((viewModel.selectedCategory.isEmpty || viewModel.amount.isEmpty || viewModel.selectedAccount == nil) ? .gray : .black)
                            .cornerRadius(30)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("CANCEL")
                            .font(Font.system(size: 18, weight: .medium))
                            .kerning(0.96)
                            .foregroundStyle(.black)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity)
                            .background(.white)
                            .cornerRadius(30)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
