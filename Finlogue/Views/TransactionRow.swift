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
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.name)
                    .font(.headline)
                Text(transaction.category)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(transaction.type == .income ? "+" : "-")\(String(format: "%.2f", transaction.amount))")
                .foregroundStyle(transaction.type == .income ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}
