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
    var personID: UUID?
    var startDate: Date?
    var endDate: Date?

    var isActive: Bool {
        type != nil || accountID != nil || categoryID != nil
            || personID != nil || startDate != nil || endDate != nil
    }

    func matches(_ transaction: Transaction) -> Bool {
        if let type, transaction.type != type { return false }
        if let accountID, transaction.account?.id != accountID { return false }
        if let categoryID, transaction.category?.id != categoryID { return false }
        if let personID {
            // Match when the person is a settlement payer or shares the expense.
            let inSplits = (transaction.splits ?? []).contains { $0.person?.id == personID }
            if transaction.person?.id != personID && !inSplits { return false }
        }
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
    @Query(sort: \Person.name) private var people: [Person]

    @State private var filterByDate = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FinTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 2)

            HStack {
                Button("Clear") {
                    FinHaptics.tap()
                    filter = TransactionFilter()
                    filterByDate = false
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(filter.isActive || filterByDate ? FinTheme.coral : FinTheme.ink400)
                .disabled(!(filter.isActive || filterByDate))
                Spacer()
                Text("Filter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Done") { applyAndDismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.coral)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)

            ScrollView {
                VStack(spacing: 24) {
                    typeSegments
                    detailsCard
                    dateCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
        .onAppear {
            if let start = filter.startDate { startDate = start; filterByDate = true }
            if let end = filter.endDate { endDate = end; filterByDate = true }
        }
    }

    // MARK: Type segments (pill, with "All")

    private var typeSegments: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type")
                .finSectionLabel()
                .padding(.leading, 4)
            HStack(spacing: 0) {
                segment(label: "All", isSelected: filter.type == nil) { filter.type = nil }
                ForEach(TransactionType.allCases) { candidate in
                    segment(label: candidate.label, isSelected: filter.type == candidate) {
                        filter.type = candidate
                    }
                }
            }
            .padding(3)
            .background(FinTheme.paper, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segment(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            FinHaptics.selection()
            withAnimation(.snappy(duration: 0.25)) { action() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : FinTheme.ink400)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(FinTheme.coral)
                            .shadow(color: FinTheme.coral.opacity(0.28), radius: 8, x: 0, y: 5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Account + Category menus

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "Account") {
                Menu {
                    Button("All accounts") { filter.accountID = nil }
                    ForEach(accounts.grouped, id: \.group) { entry in
                        Section(entry.group.rawValue) {
                            ForEach(entry.accounts) { account in
                                Button(account.name) { filter.accountID = account.id }
                            }
                        }
                    }
                } label: {
                    detailValue(accounts.first { $0.id == filter.accountID }?.name ?? "All accounts")
                }
            }
            Divider().overlay(FinTheme.lineSoft)
            detailRow(label: "Category") {
                Menu {
                    Button("All categories") { filter.categoryID = nil }
                    ForEach(categories) { category in
                        Button {
                            filter.categoryID = category.id
                        } label: {
                            Label(category.name, systemImage: category.symbol)
                        }
                    }
                } label: {
                    detailValue(categories.first { $0.id == filter.categoryID }?.name ?? "All categories")
                }
            }
            if !people.isEmpty {
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Person") {
                    Menu {
                        Button("Anyone") { filter.personID = nil }
                        ForEach(people) { person in
                            Button(person.name) { filter.personID = person.id }
                        }
                    } label: {
                        detailValue(people.first { $0.id == filter.personID }?.name ?? "Anyone")
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .finCard(radius: 16)
    }

    // MARK: Date range

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date range")
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                Toggle("Filter by date", isOn: $filterByDate.animation(.snappy(duration: 0.25)))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                    .tint(FinTheme.coral)
                    .padding(.vertical, 8)
                if filterByDate {
                    Divider().overlay(FinTheme.lineSoft)
                    detailRow(label: "From") {
                        ThemedDateField(date: $startDate)
                    }
                    Divider().overlay(FinTheme.lineSoft)
                    detailRow(label: "To") {
                        ThemedDateField(date: $endDate)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Building blocks

    private func detailRow(label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
            Spacer()
            value()
        }
        .padding(.vertical, 12)
    }

    private func detailValue(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FinTheme.ink)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FinTheme.ink400)
        }
    }

    private func applyAndDismiss() {
        filter.startDate = filterByDate ? startDate : nil
        filter.endDate = filterByDate ? endDate : nil
        dismiss()
    }
}
