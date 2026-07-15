//
//  InsightsView.swift
//  Finlogue
//

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var context

    // Only used to trigger recomputation when data changes.
    @Query private var transactions: [Transaction]

    @State private var selectedMonth = Date.now

    private var calendar: Calendar { .current }

    private var canGoForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return false }
        return calendar.compare(next, to: .now, toGranularity: .month) != .orderedDescending
    }

    private var categoryTotals: [CategoryTotal] {
        InsightsService.categoryTotals(in: context, month: selectedMonth)
    }

    private var monthlySeries: [MonthlyTotal] {
        InsightsService.monthlySeries(in: context, months: 6, endingAt: selectedMonth)
    }

    private var dailySpend: [DailyTotal] {
        InsightsService.dailySpend(in: context, month: selectedMonth)
    }

    private var monthExpenseTotal: Double {
        categoryTotals.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                if categoryTotals.isEmpty && dailySpend.isEmpty {
                    ContentUnavailableView(
                        "No data for this month",
                        systemImage: "chart.pie",
                        description: Text("Log some transactions to see insights.")
                    )
                } else {
                    categoryBreakdownSection
                    trendSection
                }
                incomeExpenseSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = previous
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Text(selectedMonth.formatted(.dateTime.month(.abbreviated).year()))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.4), value: selectedMonth)
                        .frame(minWidth: 72)
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)
                }
            }
        }
    }

    private var categoryBreakdownSection: some View {
        Section {
            VStack(spacing: 16) {
                Chart(categoryTotals) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: item.colorHex))
                }
                .frame(height: 200)
                .animation(.smooth(duration: 0.5), value: selectedMonth)
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(CurrencyFormatter.string(monthExpenseTotal))
                            .font(.headline)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.5), value: monthExpenseTotal)
                    }
                }

                // Rows keep their position across month changes; the content
                // crossfades in place and amounts roll numerically.
                VStack(spacing: 8) {
                    ForEach(Array(categoryTotals.prefix(6).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Image(systemName: item.symbol)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color(hex: item.colorHex), in: RoundedRectangle(cornerRadius: 8))
                                .contentTransition(.opacity)
                            Text(item.name)
                                .font(.subheadline)
                                .contentTransition(.opacity)
                            Spacer()
                            Text(CurrencyFormatter.string(item.total))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(monthExpenseTotal > 0
                                 ? "\(Int((item.total / monthExpenseTotal * 100).rounded()))%"
                                 : "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.5), value: selectedMonth)
            }
            .padding(.vertical, 8)
        } header: {
            SectionHeader("Spending by category")
        }
    }

    private var trendSection: some View {
        Section {
            // Crossfade between months — a fresh identity per month avoids the
            // ugly mark-morphing when the x-domain changes.
            ZStack {
                Chart(dailySpend) { item in
                    AreaMark(
                        x: .value("Day", item.day),
                        y: .value("Cumulative", item.expense)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor.opacity(0.35), .accentColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", item.day),
                        y: .value("Cumulative", item.expense)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 160)
                .id(selectedMonth)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.4), value: selectedMonth)
            .padding(.vertical, 8)
        } header: {
            SectionHeader("Spending through the month")
        }
    }

    private var incomeExpenseSection: some View {
        Section {
            // Crossfade — morphing bars while the 6-month window shifts reads badly.
            ZStack {
                Chart(monthlySeries) { item in
                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", item.income)
                    )
                    .foregroundStyle(.green.opacity(0.85))
                    .position(by: .value("Kind", "Income"))

                    BarMark(
                        x: .value("Month", item.month, unit: .month),
                        y: .value("Amount", item.expense)
                    )
                    .foregroundStyle(.red.opacity(0.75))
                    .position(by: .value("Kind", "Expense"))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .chartForegroundStyleScale([
                    "Income": Color.green.opacity(0.85),
                    "Expense": Color.red.opacity(0.75),
                ])
                .frame(height: 184)
                .id(selectedMonth)
                .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.4), value: selectedMonth)
            .padding(.vertical, 8)
        } header: {
            SectionHeader("Income vs expense — last 6 months")
        }
    }
}
