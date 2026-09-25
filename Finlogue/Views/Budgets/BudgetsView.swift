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
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var editingBudget: Budget?
    @State private var showAddBudget = false

    private enum PeriodMode: String, CaseIterable {
        case monthly, billing
        var label: String {
            switch self {
            case .monthly: "Calendar month"
            case .billing: "Card cycle"
            }
        }
    }

    @State private var periodMode: PeriodMode = .monthly
    @Namespace private var periodPillNamespace

    private var billableCards: [Account] {
        accounts.filter { $0.type == .creditCard && $0.statementDay != nil }
    }

    /// The billing cycle containing today, anchored on the first billable
    /// card's statement day (same anchor Insights uses). The cycle rolls over
    /// only *after* the statement day — with a statement on the 15th, through
    /// Sep 15 you're still in the Aug 15 – Sep 15 cycle; Sep 15 – Oct 15
    /// starts on the 16th — hence the statement lookup as of yesterday.
    private var billingInterval: DateInterval? {
        let calendar = Calendar.current
        guard let card = billableCards.first,
              let statementDay = card.statementDay,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: .now),
              let start = card.lastStatementDate(asOf: yesterday)
        else { return nil }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let monthInterval = calendar.dateInterval(of: .month, for: nextMonth),
              let dayCount = calendar.range(of: .day, in: .month, for: nextMonth)?.count,
              let end = calendar.date(
                byAdding: .day, value: min(statementDay, dayCount) - 1, to: monthInterval.start
              )
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    private var isBillingMode: Bool { periodMode == .billing && billingInterval != nil }

    private var progress: [(budget: Budget, spent: Double)] {
        if isBillingMode, let interval = billingInterval {
            return InsightsService.budgetProgress(in: context, interval: interval)
        }
        return InsightsService.budgetProgress(in: context)
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                if !billableCards.isEmpty {
                    periodSection
                }
                if budgets.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No budgets yet",
                            systemImage: "gauge.with.needle",
                            description: Text("Set a monthly limit per category and track your spending against it.")
                        )
                        .listRowBackground(Color.clear)
                    }
                    .padding(.vertical, 56)
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
                Text(progressCaption)
                    .font(.system(size: 13))
                    .foregroundStyle(FinTheme.ink400)
                    .contentTransition(.opacity)
                    .animation(.smooth(duration: 0.35), value: periodMode)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    private var progressCaption: String {
        if isBillingMode, let interval = billingInterval {
            return "Progress is for \(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(interval.end.formatted(.dateTime.day().month(.abbreviated)))."
        }
        return "Progress is for \(Date.now.formatted(.dateTime.month(.wide)))."
    }

    // MARK: Period switcher (same pill as Insights)

    private var periodSection: some View {
        Section {
            HStack(spacing: 4) {
                ForEach(PeriodMode.allCases, id: \.self) { mode in
                    let isSelected = periodMode == mode
                    Button {
                        FinHaptics.selection()
                        withAnimation(.smooth(duration: 0.35)) {
                            periodMode = mode
                        }
                    } label: {
                        Text(mode.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? FinTheme.cream : FinTheme.ink600)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(FinTheme.ink)
                                        .matchedGeometryEffect(id: "periodPill", in: periodPillNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(FinTheme.paperInset, in: Capsule())
            .padding(14)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }
}

struct BudgetProgressRow: View {
    let budget: Budget
    let spent: Double

    private var categoriesLabel: String {
        let names = budget.effectiveCategories.map(\.name)
        return names.isEmpty ? "Unknown category" : names.joined(separator: " + ")
    }

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
                // Overlapping icon stack when the budget spans several categories.
                HStack(spacing: -10) {
                    ForEach(budget.effectiveCategories.prefix(3)) { category in
                        Image(systemName: category.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Color(hex: category.colorHex),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(FinTheme.paper, lineWidth: 1.5)
                            )
                    }
                    if budget.effectiveCategories.isEmpty {
                        Image(systemName: "tag")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Color(hex: "#8C877B"),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                }
                Text(categoriesLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(2)
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
