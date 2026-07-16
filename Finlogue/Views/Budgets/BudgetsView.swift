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
                headerSection
                if budgets.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No budgets yet",
                            systemImage: "gauge.with.needle",
                            description: Text("Set a monthly limit per category and track your spending against it.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(progress, id: \.budget.id) { entry in
                            BudgetProgressRow(budget: entry.budget, spent: entry.spent)
                                .listRowBackground(FinTheme.paper)
                                .listRowSeparatorTint(FinTheme.lineSoft)
                                .contentShape(Rectangle())
                                .onTapGesture { editingBudget = entry.budget }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        FinHaptics.warning()
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddBudget) {
                BudgetEditorView()
            }
            .sheet(item: $editingBudget) { budget in
                BudgetEditorView(budget: budget)
            }
        }
    }

    private var headerSection: some View {
        Section {
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Budgets")
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(FinTheme.ink)
                    Spacer()
                    Button {
                        FinHaptics.tap()
                        showAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(FinTheme.coral, in: Circle())
                            .shadow(color: FinTheme.coral.opacity(0.28), radius: 12, x: 0, y: 8)
                    }
                    .buttonStyle(.plain)
                }
                Text("Progress is for \(Date.now.formatted(.dateTime.month(.wide))).")
                    .font(.system(size: 13))
                    .foregroundStyle(FinTheme.ink400)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
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

    private var fillColor: Color {
        if isOver { return FinTheme.red }
        if fraction > 0.85 { return FinTheme.amber }
        return FinTheme.lime400
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: budget.category?.symbol ?? "tag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        Color(hex: budget.category?.colorHex ?? "#8C877B"),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                Text(budget.category?.name ?? "Unknown category")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Text("\(CurrencyFormatter.string(spent)) / \(CurrencyFormatter.string(budget.limit))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FinTheme.ink400)
                    .monospacedDigit()
            }
            Capsule()
                .fill(FinTheme.paperInset)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(proxy.size.width * min(fraction, 1), fraction > 0 ? 8 : 0))
                    }
                }
                .animation(.smooth(duration: 0.6), value: fraction)
            if isOver {
                Text("Over by \(CurrencyFormatter.string(spent - budget.limit))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FinTheme.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .animation(.smooth(duration: 0.4), value: isOver)
    }
}
