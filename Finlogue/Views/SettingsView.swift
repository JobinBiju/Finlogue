//
//  SettingsView.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @State private var showAddAccountSheet = false
    @State private var showAddCategorySheet = false
    @State private var newAccountName = ""
    @State private var newAccountBalance = ""
    @State private var newCategoryName = ""
    @State private var newCategoryType: TransactionType = .expense
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Accounts")) {
                    ForEach(accounts) { account in
                        HStack {
                            Text(account.name)
                            Spacer()
                            Text(String(format: "%.2f", account.balance))
                                .foregroundStyle(account.balance >= 0 ? .green : .red)
                        }
                    }
                    Button("Add Account") {
                        newAccountName = ""
                        newAccountBalance = ""
                        showAddAccountSheet = true
                    }
                }
                
                Section(header: Text("Categories")) {
                    ForEach(categories) { category in
                        HStack {
                            Text("\(category.name) (\(category.type.rawValue))")
                            Spacer()
                            Button(action: {
                                modelContext.delete(category)
                                try? modelContext.save()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    Button("Add Category") {
                        newCategoryName = ""
                        newCategoryType = .expense
                        showAddCategorySheet = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showAddAccountSheet) {
                AddAccountView(
                    newAccountName: $newAccountName,
                    newAccountBalance: $newAccountBalance,
                    onSave: { name, balance in
                        let account = Account(name: name, balance: balance)
                        modelContext.insert(account)
                        try? modelContext.save()
                        showAddAccountSheet = false
                    },
                    onCancel: { showAddAccountSheet = false }
                )
                .presentationDetents([.medium, .height(300)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddCategorySheet) {
                AddCategoryView(
                    newCategoryName: $newCategoryName,
                    newCategoryType: $newCategoryType,
                    onSave: { name, type in
                        let category = Category(name: name, type: type)
                        modelContext.insert(category)
                        try? modelContext.save()
                        showAddCategorySheet = false
                    },
                    onCancel: { showAddCategorySheet = false }
                )
                .presentationDetents([.medium, .height(300)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}
