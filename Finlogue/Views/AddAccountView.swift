//
//  AddAccountView.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI

struct AddAccountView: View {
    @Binding var newAccountName: String
    @Binding var newAccountBalance: String
    let onSave: (String, Double) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Add Account")
                    .font(Font.system(size: 28, weight: .bold))
                    .padding(.horizontal)
                    .padding(.top, 32)
                List {
                    TextField("Account Name", text: $newAccountName)
                    TextField("Initial Balance", text: $newAccountBalance)
                        .keyboardType(.numbersAndPunctuation)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .padding(.bottom, 12)
                .padding(.top, 16)
                HStack(spacing: 4) {
                    Button {
                        if let balance = Double(newAccountBalance), !newAccountName.isEmpty {
                            onSave(newAccountName, balance)
                        }
                    } label: {
                        Text("ADD")
                            .font(Font.system(size: 18, weight: .medium))
                            .kerning(0.96)
                            .foregroundStyle(.white)
                            .disabled(newAccountName.isEmpty || Double(newAccountBalance) == nil)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity)
                            .background((newAccountName.isEmpty || Double(newAccountBalance) == nil) ? .gray : .black)
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
