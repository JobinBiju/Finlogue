//
//  BudgetEditorView.swift
//  Finlogue
//
//  Design-system budget sheet: cream canvas, big monthly-limit amount,
//  paper category card.
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
        guard let limit = AmountInput.parse(limitText), limit > 0 else { return false }
        return selectedCategoryID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FinTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 2)

            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                Spacer()
                Text(budget == nil ? "New budget" : "Edit budget")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Save") { save() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSave ? FinTheme.coral : FinTheme.ink400)
                    .disabled(!canSave)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 24) {
                    amountEntry
                    categoryCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
        .onAppear {
            guard let budget else { return }
            selectedCategoryID = budget.category?.id
            limitText = AmountInput.string(budget.limit)
        }
    }

    // MARK: Pieces

    private var amountEntry: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Text(CurrencyFormatter.symbol())
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(FinTheme.ink400)
                TextField("0", text: $limitText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onChange(of: limitText) { _, newValue in
                        let formatted = AmountInput.reformat(newValue)
                        if formatted != newValue {
                            limitText = formatted
                        }
                    }
            }
            Text("per month")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FinTheme.ink400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .finSectionLabel()
                .padding(.leading, 4)
            HStack {
                Text("Category")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                Spacer()
                Menu {
                    ForEach(expenseCategories) { category in
                        Button {
                            selectedCategoryID = category.id
                        } label: {
                            Label(category.name, systemImage: category.symbol)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(categories.first { $0.id == selectedCategoryID }?.name ?? "Select")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FinTheme.ink)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FinTheme.ink400)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
            Text("The limit applies every month.")
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink400)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Logic (unchanged)

    private func save() {
        guard let limit = AmountInput.parse(limitText) else { return }
        let category = categories.first { $0.id == selectedCategoryID }
        store.saveBudget(budget, category: category, limit: limit)
        FinHaptics.success()
        dismiss()
    }
}
