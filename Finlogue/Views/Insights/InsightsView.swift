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
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var selectedMonth = Self.initialMonth

    private enum PeriodMode: String, CaseIterable {
        case billing, monthly
        var label: String {
            switch self {
            case .monthly: "Calendar month"
            case .billing: "Card cycle"
            }
        }
    }

    @State private var periodMode: PeriodMode = .billing

    /// 0 → 1 the first time Insights is on screen: the donut sweeps round and
    /// the total counts up with it. Switching month or period afterwards uses
    /// the plain crossfades and rolling digits below, not this entrance.
    @State private var sweep: Double = 0
    /// Set once the entrance count-up has landed; the total then rolls its
    /// digits on changes instead of counting.
    @State private var hasCounted = false
    /// The trend line draws itself once; later periods crossfade in drawn.
    @State private var trendDrawn = false

    /// Test hook: `-insightsMonthOffset -N` opens N months back.
    private static var initialMonth: Date {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-insightsMonthOffset"),
           arguments.indices.contains(index + 1),
           let offset = Int(arguments[index + 1]),
           let month = Calendar.current.date(byAdding: .month, value: offset, to: .now) {
            return month
        }
        #endif
        return .now
    }

    private var calendar: Calendar { .current }

    private var canGoForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return false }
        return calendar.compare(next, to: .now, toGranularity: .month) != .orderedDescending
    }

    /// Credit cards that have a statement day set — the only ones a cycle can
    /// be computed for.
    private var billableCards: [Account] {
        accounts.filter { $0.type == .creditCard && $0.statementDay != nil }
    }

    private var selectedCard: Account? {
        billableCards.first
    }

    /// The billing cycle overlapping `selectedMonth` — see
    /// `BillingCycle.cycle(statementDay:overlapping:)`, which the spending
    /// coach shares so both agree on the dates.
    private var billingInterval: DateInterval? {
        guard let statementDay = selectedCard?.statementDay else { return nil }
        return BillingCycle.cycle(statementDay: statementDay, overlapping: selectedMonth, calendar: calendar)
    }

    private var isBillingMode: Bool { periodMode == .billing && billingInterval != nil }

    /// Identity for chart crossfades — changes when the month, mode or card changes.
    private var periodKey: String {
        "\(selectedMonth.timeIntervalSinceReferenceDate)-\(periodMode.rawValue)-\(selectedCard?.id.uuidString ?? "")"
    }

    private var categoryTotals: [CategoryTotal] {
        if isBillingMode, let interval = billingInterval {
            return InsightsService.categoryTotals(in: context, interval: interval)
        }
        return InsightsService.categoryTotals(in: context, month: selectedMonth)
    }

    private var monthlySeries: [MonthlyTotal] {
        InsightsService.monthlySeries(in: context, months: 6, endingAt: selectedMonth)
    }

    private var dailySpend: [DailyTotal] {
        if isBillingMode, let interval = billingInterval {
            return InsightsService.dailySpend(in: context, interval: interval)
        }
        return InsightsService.dailySpend(in: context, month: selectedMonth)
    }

    var body: some View {
        NavigationStack {
            List {
                headerSection
                if !billableCards.isEmpty {
                    periodSection
                }
                // Fetched once per body and handed to the sections: chart
                // closures re-run during layout while the list scrolls, and
                // reading the computed properties there re-ran the SwiftData
                // fetch on every pass — the scroll stutter.
                let totals = categoryTotals
                let daily = dailySpend
                if totals.isEmpty && daily.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No data for this month",
                            systemImage: "chart.pie",
                            description: Text("Log some transactions to see insights.")
                        )
                        .listRowBackground(Color.clear)
                    }
                    .padding(.vertical, 64)
                } else {
                    coachSection
                    categoryBreakdownSection(totals)
                    trendSection(daily)
                    incomeExpenseSection
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(20)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .contentMargins(.bottom, 88, for: .scrollContent)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .toolbar(.hidden, for: .navigationBar)
            .onFirstTabActivation {
                withAnimation(FinMotion.reveal) { sweep = 1 }
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    hasCounted = true
                }
            }
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
                            FinHaptics.selection()
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
                            FinHaptics.selection()
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

    // MARK: Period switcher (calendar month vs card billing cycle)

    private var periodSection: some View {
        Section {
            VStack(spacing: 12) {
                LiquidSegmentedControl(
                    items: PeriodMode.allCases,
                    selection: periodMode,
                    spacing: 4,
                    onSelect: { mode in
                        FinHaptics.selection()
                        withAnimation(.smooth(duration: 0.35)) {
                            periodMode = mode
                        }
                    },
                    segment: { mode, _, onPill in
                        Text(mode.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(onPill ? FinTheme.cream : FinTheme.ink600)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    },
                    pill: { shape in
                        shape.fill(FinTheme.ink)
                    }
                )
                .padding(4)
                .background(FinTheme.paperInset, in: Capsule())

                if periodMode == .billing, let interval = billingInterval {
                    Text(
                        "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(interval.end.formatted(.dateTime.day().month(.abbreviated)))"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FinTheme.ink400)
                    .monospacedDigit()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(14)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        } footer: {
            if periodMode == .billing {
                Text("All spending between statement dates.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
            }
        }
    }

    // MARK: Spending coach

    /// The coach reads card cycles — the period alerts follow too — so it
    /// sits out the calendar-month view. Months only when no card has a
    /// statement day.
    private var coachPeriod: SpendingPeriod? {
        guard let statementDay = selectedCard?.statementDay, billingInterval != nil else {
            return .month(containing: selectedMonth)
        }
        guard isBillingMode else { return nil }
        return .cycle(statementDay: statementDay, overlapping: selectedMonth)
    }

    @ViewBuilder
    private var coachSection: some View {
        if let period = coachPeriod,
           let digest = SpendingAnalyzer.digest(in: context, period: period),
           digest.transactionCount > 0 {
            Section {
                SpendingCoachCard(digest: digest)
                    .finEntrance(sweep > 0, index: 1)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(FinTheme.paper)
            }
        }
    }

    // MARK: Category donut

    private func categoryBreakdownSection(_ totals: [CategoryTotal]) -> some View {
        let spent = totals.reduce(0) { $0 + $1.total }
        return Section {
            VStack(spacing: 24) {
                Text("Spending by category")
                    .finSectionLabel()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Chart {
                    ForEach(totals) { item in
                        SectorMark(
                            angle: .value("Amount", item.total * sweep),
                            innerRadius: .ratio(0.64),
                            angularInset: 1.5
                        )
                        .cornerRadius(4)
                        .foregroundStyle(Color(hex: item.colorHex))
                    }
                    // Invisible remainder: while `sweep` < 1 it holds the
                    // unswept part of the ring, so the sectors grow clockwise
                    // instead of just rescaling.
                    SectorMark(
                        angle: .value("Amount", spent * (1 - sweep)),
                        innerRadius: .ratio(0.64)
                    )
                    .foregroundStyle(Color.clear)
                }
                .frame(height: 190)
                .animation(.smooth(duration: 0.5), value: periodKey)
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text("Spent")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                        Group {
                            if hasCounted {
                                Text(CurrencyFormatter.string(spent))
                                    .contentTransition(.numericText())
                                    .animation(.smooth(duration: 0.5), value: spent)
                            } else {
                                CountingCurrencyText(spent * sweep)
                                    .animation(FinMotion.count, value: spent)
                                    .animation(FinMotion.count, value: sweep)
                            }
                        }
                        .font(.system(size: 24, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(FinTheme.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    }
                    // Keep the label inside the donut hole (0.64 inner ratio
                    // of the 190pt chart, minus breathing room).
                    .frame(maxWidth: 104)
                }

                // Rows keep their position across month changes; content
                // crossfades in place and amounts roll numerically.
                VStack(spacing: 12) {
                    ForEach(Array(totals.prefix(8).enumerated()), id: \.offset) { index, item in
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
                            Text(spent > 0
                                 ? "\(Int((item.total / spent * 100).rounded()))%"
                                 : "")
                                .font(.system(size: 12))
                                .foregroundStyle(FinTheme.ink400)
                                .frame(width: 36, alignment: .trailing)
                                .contentTransition(.numericText())
                        }
                        .finEntrance(sweep > 0, index: 2 + min(index, 6))
                        .transition(.opacity)
                    }
                }
                .animation(.smooth(duration: 0.5), value: periodKey)
            }
            .padding(20)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }

    // MARK: Daily trend

    private func trendSection(_ daily: [DailyTotal]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                Text("Spending through the month")
                    .finSectionLabel()
                // Crossfade between months — a fresh identity per month avoids
                // ugly mark-morphing when the x-domain changes.
                ZStack {
                    SpendingTrendChart(data: daily, hasDrawn: $trendDrawn)
                        .frame(height: 150)
                        .id(periodKey)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.4), value: periodKey)
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
                    // Bars rise out of the baseline on first appearance.
                    .chartPlotStyle { plot in
                        plot.mask(alignment: .bottom) {
                            Rectangle()
                                .padding(.top, -40)
                                .scaleEffect(y: sweep, anchor: .bottom)
                        }
                    }
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

// MARK: - Spending trend

/// Cumulative spend line that draws itself left to right the first time it's
/// on screen, with a scrub bubble that follows the finger.
private struct SpendingTrendChart: View {
    let data: [DailyTotal]
    /// Shared across the per-period identities, so only the first one draws in.
    @Binding var hasDrawn: Bool

    @State private var progress: CGFloat
    @State private var scrubDate: Date?

    init(data: [DailyTotal], hasDrawn: Binding<Bool>) {
        self.data = data
        _hasDrawn = hasDrawn
        _progress = State(initialValue: hasDrawn.wrappedValue ? 1 : 0)
    }

    /// The data point nearest the finger.
    private var scrubbed: DailyTotal? {
        guard let scrubDate else { return nil }
        return data.min {
            abs($0.day.timeIntervalSince(scrubDate)) < abs($1.day.timeIntervalSince(scrubDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(data) { item in
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
            if let scrubbed {
                RuleMark(x: .value("Day", scrubbed.day))
                    .foregroundStyle(FinTheme.ink400.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .plot), y: .disabled)
                    ) {
                        scrubBubble(for: scrubbed)
                    }
                PointMark(
                    x: .value("Day", scrubbed.day),
                    y: .value("Cumulative", scrubbed.expense)
                )
                .symbolSize(70)
                .foregroundStyle(FinTheme.coral)
            }
        }
        .chartXSelection(value: $scrubDate)
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
        // Draw-on: a mask sweeping left to right over the plot. It overhangs
        // vertically so the scrub bubble above the plot isn't clipped.
        .chartPlotStyle { plot in
            plot.mask(alignment: .leading) {
                Rectangle()
                    .padding(.vertical, -60)
                    .scaleEffect(x: progress, anchor: .leading)
            }
        }
        .sensoryFeedback(.selection, trigger: scrubbed?.day)
        .onFirstTabActivation(after: .milliseconds(160)) {
            guard progress == 0 else { return }
            hasDrawn = true
            withAnimation(FinMotion.reveal) { progress = 1 }
        }
    }

    private func scrubBubble(for point: DailyTotal) -> some View {
        VStack(spacing: 1) {
            Text(CurrencyFormatter.string(point.expense))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: point.expense))
            Text("by \(point.day.formatted(.dateTime.day().month(.abbreviated)))")
                .font(.system(size: 10, weight: .medium))
                .opacity(0.7)
        }
        .foregroundStyle(FinTheme.cream)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FinTheme.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(FinMotion.press, value: point.day)
    }
}
