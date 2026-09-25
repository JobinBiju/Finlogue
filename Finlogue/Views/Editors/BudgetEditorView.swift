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

    @State private var selectedCategoryIDs: Set<UUID> = []
    @State private var limitText = ""

    private var expenseCategories: [Category] {
        // A category can belong to only one budget; keep this budget's own
        // categories selectable when editing.
        let ownIDs = Set(budget?.effectiveCategories.map(\.id) ?? [])
        let budgetedIDs = Set(
            budgets.filter { $0.id != budget?.id }
                .flatMap { $0.effectiveCategories.map(\.id) }
        )
        return categories.filter { category in
            guard category.type == .expense else { return false }
            return !budgetedIDs.contains(category.id) || ownIDs.contains(category.id)
        }
    }

    private var canSave: Bool {
        guard let limit = AmountInput.parse(limitText), limit > 0 else { return false }
        return !selectedCategoryIDs.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 32)

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
            selectedCategoryIDs = Set(budget.effectiveCategories.map(\.id))
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
            Text("Categories")
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(expenseCategories) { category in
                    let isSelected = selectedCategoryIDs.contains(category.id)
                    Button {
                        FinHaptics.selection()
                        if isSelected {
                            selectedCategoryIDs.remove(category.id)
                        } else {
                            selectedCategoryIDs.insert(category.id)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(
                                    Color(hex: category.colorHex),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            Text(category.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(FinTheme.ink)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(isSelected ? FinTheme.coral : FinTheme.ink400.opacity(0.4))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if category.id != expenseCategories.last?.id {
                        Divider().overlay(FinTheme.lineSoft).padding(.leading, 54)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
            Text("Pick one or more categories — their combined spending counts against this limit, every month.")
                .font(.system(size: 12))
                .foregroundStyle(FinTheme.ink400)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Logic (unchanged)

    private func save() {
        guard let limit = AmountInput.parse(limitText) else { return }
        let selected = categories.filter { selectedCategoryIDs.contains($0.id) }
        store.saveBudget(budget, categories: selected, limit: limit)
        FinHaptics.success()
        dismiss()
    }
}
