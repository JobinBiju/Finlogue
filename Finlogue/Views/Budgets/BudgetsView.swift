//
//  BudgetsView.swift
//  Finlogue
//

import SwiftUI
import SwiftData

struct BudgetsView: View {
    @EnvironmentObject private var store: TransactionStore
    @Environment(\.modelContext) private var context

    @Query private var budgets: [Budget]
    // Recompute progress when transactions change.
    @Query private var transactions: [Transaction]

    @State private var editingBudget: Budget?
    @State private var showAddBudget = false

    private var progress: [(budget: Budget, spent: Double)] {
        InsightsService.budgetProgress(in: context)
    }

    var body: some View {
        NavigationStack {
            List {
                if budgets.isEmpty {
                    ContentUnavailableView(
                        "No budgets yet",
                        systemImage: "gauge.with.needle",
                        description: Text("Set a monthly limit per category and track your spending against it.")
                    )
                } else {
                    Section {
                        ForEach(progress, id: \.budget.id) { entry in
                            BudgetProgressRow(budget: entry.budget, spent: entry.spent)
                                .contentShape(Rectangle())
                                .onTapGesture { editingBudget = entry.budget }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        store.delete(entry.budget)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingBudget = entry.budget
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                    } footer: {
                        Text("Progress is for \(Date.now.formatted(.dateTime.month(.wide))).")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddBudget) {
                BudgetEditorView()
            }
            .sheet(item: $editingBudget) { budget in
                BudgetEditorView(budget: budget)
            }
        }
    }
}

struct BudgetProgressRow: View {
    let budget: Budget
    let spent: Double

    private var fraction: Double {
        budget.limit > 0 ? spent / budget.limit : 0
    }

    private var isOver: Bool { fraction > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: budget.category?.symbol ?? "tag")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Color(hex: budget.category?.colorHex ?? "#94A3B8"),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                Text(budget.category?.name ?? "Unknown category")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(CurrencyFormatter.string(spent)) / \(CurrencyFormatter.string(budget.limit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: min(fraction, 1))
                .tint(isOver ? .red : (fraction > 0.85 ? .orange : Color(hex: budget.category?.colorHex ?? "#4F8EF7")))
                .animation(.smooth(duration: 0.6), value: fraction)
            if isOver {
                Text("Over by \(CurrencyFormatter.string(spent - budget.limit))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.smooth(duration: 0.4), value: isOver)
    }
}
