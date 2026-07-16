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
                headerSection
                if categoryTotals.isEmpty && dailySpend.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No data for this month",
                            systemImage: "chart.pie",
                            description: Text("Log some transactions to see insights.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    categoryBreakdownSection
                    trendSection
                }
                incomeExpenseSection
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: Header (title + month switcher pill)

    private var headerSection: some View {
        Section {
        } header: {
            HStack {
                Text("Insights")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                HStack(spacing: 4) {
                    Button {
                        if let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
                            selectedMonth = previous
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FinTheme.ink600)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    Text(selectedMonth.formatted(.dateTime.month(.abbreviated).year()))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FinTheme.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.4), value: selectedMonth)
                        .frame(minWidth: 68)
                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
                            selectedMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canGoForward ? FinTheme.ink600 : FinTheme.ink400.opacity(0.5))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoForward)
                }
                .padding(4)
                .background(FinTheme.paper, in: Capsule())
                .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: Category donut

    private var categoryBreakdownSection: some View {
        Section {
            VStack(spacing: 24) {
                Text("Spending by category")
                    .finSectionLabel()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Chart(categoryTotals) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.64),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: item.colorHex))
                }
                .frame(height: 190)
                .animation(.smooth(duration: 0.5), value: selectedMonth)
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text("Spent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                        Text(CurrencyFormatter.string(monthExpenseTotal))
                            .font(.system(size: 24, weight: .heavy))
                            .kerning(-0.5)
                            .foregroundStyle(FinTheme.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.5), value: monthExpenseTotal)
                    }
                }

                // Rows keep their position across month changes; content
                // crossfades in place and amounts roll numerically.
                VStack(spacing: 12) {
                    ForEach(Array(categoryTotals.prefix(6).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(
                                    Color(hex: item.colorHex),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .contentTransition(.opacity)
                            Text(item.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(FinTheme.ink)
                                .contentTransition(.opacity)
                            Spacer()
                            Text(CurrencyFormatter.string(item.total))
                                .font(.system(size: 14, weight: .semibold))
                                .kerning(-0.3)
                                .foregroundStyle(FinTheme.ink)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text(monthExpenseTotal > 0
                                 ? "\(Int((item.total / monthExpenseTotal * 100).rounded()))%"
                                 : "")
                                .font(.system(size: 12))
                                .foregroundStyle(FinTheme.ink400)
                                .frame(width: 36, alignment: .trailing)
                                .contentTransition(.numericText())
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.5), value: selectedMonth)
            }
            .padding(20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }

    // MARK: Daily trend

    private var trendSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Spending through the month")
                    .finSectionLabel()
                // Crossfade between months — a fresh identity per month avoids
                // ugly mark-morphing when the x-domain changes.
                ZStack {
                    Chart(dailySpend) { item in
                        AreaMark(
                            x: .value("Day", item.day),
                            y: .value("Cumulative", item.expense)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FinTheme.coral.opacity(0.32), FinTheme.coral.opacity(0.02)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Day", item.day),
                            y: .value("Cumulative", item.expense)
                        )
                        .foregroundStyle(FinTheme.coral)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(FinTheme.lineSoft)
                            AxisValueLabel()
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                        }
                    }
                    .frame(height: 150)
                    .id(selectedMonth)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.4), value: selectedMonth)
            }
            .padding(20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }

    // MARK: Income vs expense

    private var incomeExpenseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Income vs expense · 6 months")
                    .finSectionLabel()
                ZStack {
                    Chart(monthlySeries) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Amount", item.income),
                            width: 14
                        )
                        .cornerRadius(4)
                        .foregroundStyle(FinTheme.green.opacity(0.85))
                        .position(by: .value("Kind", "Income"))

                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Amount", item.expense),
                            width: 14
                        )
                        .cornerRadius(4)
                        .foregroundStyle(FinTheme.red.opacity(0.8))
                        .position(by: .value("Kind", "Expense"))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.narrow))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(FinTheme.lineSoft)
                            AxisValueLabel()
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 160)
                    .id(selectedMonth)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.4), value: selectedMonth)

                HStack(spacing: 16) {
                    legendChip(color: FinTheme.green, label: "Income")
                    legendChip(color: FinTheme.red, label: "Expense")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
        }
    }
}
