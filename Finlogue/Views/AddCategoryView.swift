//
//  AddCategoryView.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI

struct AddCategoryView: View {
    @Binding var newCategoryName: String
    @Binding var newCategoryType: TransactionType
    let onSave: (String, TransactionType) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Add Account")
                    .font(Font.system(size: 28, weight: .bold))
                    .padding(.horizontal)
                    .padding(.top, 32)
                List {
                    TextField("Category Name", text: $newCategoryName)
                    Picker("Type", selection: $newCategoryType) {
                        Text("Income").tag(TransactionType.income)
                        Text("Expense").tag(TransactionType.expense)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .padding(.bottom, 12)
                .padding(.top, 16)
                HStack(spacing: 4) {
                    Button {
                        if !newCategoryName.isEmpty {
                            onSave(newCategoryName, newCategoryType)
                        }
                    } label: {
                        Text("ADD")
                            .font(Font.system(size: 18, weight: .medium))
                            .kerning(0.96)
                            .foregroundStyle(.white)
                            .disabled(newCategoryName.isEmpty)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity)
                            .background(newCategoryName.isEmpty ? .gray : .black)
                            .cornerRadius(30)
                    }
                    Spacer()
                    Button {
                        onCancel()
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
                .padding(.bottom, 16)
            }
        }
    }
}
