//
//  BudgetEditorView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct BudgetEditorView: View {
    var budget: Budget?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var budgets: [Budget]

    @State private var selectedCategoryID: UUID?
    @State private var limitText = ""

    private var expenseCategories: [Category] {
        let budgetedIDs = Set(budgets.compactMap { $0.category?.id })
        return categories.filter { category in
            guard category.type == .expense else { return false }
            // A category can hold only one budget; keep the current one selectable.
            return !budgetedIDs.contains(category.id) || category.id == budget?.category?.id
        }
    }

    private var canSave: Bool {
        guard let limit = Double(limitText), limit > 0 else { return false }
        return selectedCategoryID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Select category").tag(UUID?.none)
                        ForEach(expenseCategories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(UUID?.some(category.id))
                        }
                    }
                    HStack {
                        Text(CurrencyFormatter.symbol())
                            .foregroundStyle(.secondary)
                        TextField("Monthly limit", text: $limitText)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    Text("The limit applies every month.")
                }
            }
            .navigationTitle(budget == nil ? "New Budget" : "Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .fontDesign(.rounded)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard let budget else { return }
                selectedCategoryID = budget.category?.id
                limitText = String(format: "%g", budget.limit)
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let limit = Double(limitText) else { return }
        let category = categories.first { $0.id == selectedCategoryID }
        store.saveBudget(budget, category: category, limit: limit)
        dismiss()
    }
}
