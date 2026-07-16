//
//  TransactionFilterView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct TransactionFilter: Equatable {
    var type: TransactionType?
    var accountID: UUID?
    var categoryID: UUID?
    var startDate: Date?
    var endDate: Date?

    var isActive: Bool {
        type != nil || accountID != nil || categoryID != nil || startDate != nil || endDate != nil
    }

    func matches(_ transaction: Transaction) -> Bool {
        if let type, transaction.type != type { return false }
        if let accountID, transaction.account?.id != accountID { return false }
        if let categoryID, transaction.category?.id != categoryID { return false }
        if let startDate, transaction.date < Calendar.current.startOfDay(for: startDate) { return false }
        if let endDate {
            let endOfDay = Calendar.current.date(
                byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)
            ) ?? endDate
            if transaction.date >= endOfDay { return false }
        }
        return true
    }
}

struct TransactionFilterView: View {
    @Binding var filter: TransactionFilter
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var filterByDate = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Type", selection: $filter.type) {
                        Text("All").tag(TransactionType?.none)
                        ForEach(TransactionType.allCases) { type in
                            Text(type.label).tag(TransactionType?.some(type))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Account") {
                    Picker("Account", selection: $filter.accountID) {
                        Text("All accounts").tag(UUID?.none)
                        ForEach(accounts.grouped, id: \.group) { entry in
                            Section(entry.group.rawValue) {
                                ForEach(entry.accounts) { account in
                                    Text(account.name).tag(UUID?.some(account.id))
                                }
                            }
                        }
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $filter.categoryID) {
                        Text("All categories").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }
                }

                Section("Date range") {
                    Toggle("Filter by date", isOn: $filterByDate)
                    if filterByDate {
                        DatePicker("From", selection: $startDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Clear filters", role: .destructive) {
                        filter = TransactionFilter()
                        filterByDate = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .fontDesign(.rounded)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        filter.startDate = filterByDate ? startDate : nil
                        filter.endDate = filterByDate ? endDate : nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let start = filter.startDate { startDate = start; filterByDate = true }
                if let end = filter.endDate { endDate = end; filterByDate = true }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
