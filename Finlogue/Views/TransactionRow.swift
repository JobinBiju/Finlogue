//
//  TransactionRow.swift
//  ExpenseTracker
//
//  Created by Jobin Biju on 18/04/25.
//

import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 40, height: 40)
                .background(Color.green9.opacity(0.1))
                .cornerRadius(6)
            VStack(alignment: .leading) {
                Text(transaction.name)
                    .font(.headline)
                Text(transaction.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(transaction.type == .income ? "+" : "-")\(String(format: "%.2f", transaction.amount))")
                    .foregroundStyle(transaction.type == .income ? .green : .red)
                    .font(.headline)
                Text("\(transaction.account.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .padding(.trailing, 12)
        .background(.white)
        .overlay(RoundedRectangle(cornerRadius: 12).inset(by: 0.5).stroke(Color.gray500.opacity(0.3), lineWidth: 1))
    }
}
