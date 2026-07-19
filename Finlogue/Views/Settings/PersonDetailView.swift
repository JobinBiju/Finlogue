//
//  PersonDetailView.swift
//  Finlogue
//
//  A person's ledger: outstanding balance, their shares of shared transactions,
//  and repayments — with a button to record a new repayment.
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    let person: Person

    @EnvironmentObject private var store: TransactionStore
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @State private var showRepayment = false
    @State private var showEdit = false

    private enum LedgerEntry: Identifiable {
        case share(TransactionSplit)
        case repayment(Transaction)

        var id: UUID {
            switch self {
            case .share(let s): s.id
            case .repayment(let t): t.id
            }
        }
        var date: Date {
            switch self {
            case .share(let s): s.transaction?.date ?? s.createdAt
            case .repayment(let t): t.date
            }
        }
    }

    private var ledger: [LedgerEntry] {
        let shares = (person.splits ?? []).map(LedgerEntry.share)
        let repayments = (person.transactions ?? [])
            .filter { $0.isSettlement }
            .map(LedgerEntry.repayment)
        return (shares + repayments).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            headerSection
            balanceSection
            if !ledger.isEmpty {
                Section {
                    ForEach(ledger) { entry in
                        ledgerRow(entry)
                    }
                } header: {
                    SectionHeader("Activity")
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .background(FinTheme.canvas)
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { tabBarVisibility.isHidden = true }
        .sheet(isPresented: $showRepayment) {
            RepaymentEditorView(person: person)
        }
        .sheet(isPresented: $showEdit) {
            PersonEditorView(person: person)
        }
    }

    // MARK: Header

    private var headerSection: some View {
        Section {
        } header: {
            HStack {
                Button {
                    FinHaptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FinTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.paper, in: Circle())
                        .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                Text(person.name)
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
                    .padding(.leading, 8)
                Spacer()
                Button {
                    FinHaptics.tap()
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FinTheme.ink)
                        .frame(width: 44, height: 44)
                        .background(FinTheme.paper, in: Circle())
                        .shadow(color: FinTheme.shadowTint.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    // MARK: Outstanding balance + action

    private var balanceSection: some View {
        Section {
            VStack(spacing: 16) {
                Text(person.initials)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(Color(hex: person.colorHex), in: Circle())

                VStack(spacing: 4) {
                    Text(balanceCaption)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                    Text(CurrencyFormatter.string(abs(person.outstanding)))
                        .font(.system(size: 34, weight: .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(balanceColor)
                        .monospacedDigit()
                    if person.owed > 0 {
                        Text("\(CurrencyFormatter.string(person.repaid)) of \(CurrencyFormatter.string(person.owed)) repaid")
                            .font(.system(size: 12))
                            .foregroundStyle(FinTheme.ink400)
                    }
                }

                Button {
                    FinHaptics.tap()
                    showRepayment = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Record repayment")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FinTheme.coral, in: Capsule())
                    .shadow(color: FinTheme.coral.opacity(0.28), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(FinTheme.paper)
        }
    }

    private var balanceCaption: String {
        if person.outstanding > 0.005 { return "\(person.name) owes you" }
        if person.outstanding < -0.005 { return "You owe \(person.name)" }
        return "All settled up"
    }

    private var balanceColor: Color {
        if person.outstanding > 0.005 { return FinTheme.green }
        if person.outstanding < -0.005 { return FinTheme.red }
        return FinTheme.ink400
    }

    // MARK: Ledger rows

    @ViewBuilder
    private func ledgerRow(_ entry: LedgerEntry) -> some View {
        switch entry {
        case .share(let split):
            row(
                symbol: split.transaction?.category?.symbol ?? "cart",
                tint: Color(hex: split.transaction?.category?.colorHex ?? "#8C877B"),
                title: split.transaction?.name ?? "Shared expense",
                date: entry.date,
                breakdown: billBreakdown(split.transaction),
                amount: split.shareAmount,
                positive: true
            )
        case .repayment(let transaction):
            row(
                symbol: "arrow.down.left",
                tint: FinTheme.green,
                title: "Repayment",
                date: entry.date,
                breakdown: nil,
                amount: transaction.amount,
                positive: false
            )
        }
    }

    /// "Bill ₹4,500 + ₹90 fee" — amount and charges shown separately.
    private func billBreakdown(_ transaction: Transaction?) -> String? {
        guard let transaction else { return nil }
        var text = "Bill \(CurrencyFormatter.string(transaction.amount))"
        if transaction.charges > 0 {
            text += " + \(CurrencyFormatter.string(transaction.charges)) fee"
        }
        return text
    }

    private func row(
        symbol: String, tint: Color, title: String, date: Date,
        breakdown: String?, amount: Double, positive: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                if let breakdown {
                    Text(breakdown)
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
                        .monospacedDigit()
                }
            }
            Spacer()
            Text("\(positive ? "+" : "−")\(CurrencyFormatter.string(amount))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(positive ? FinTheme.ink : FinTheme.green)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .listRowBackground(FinTheme.paper)
        .listRowSeparatorTint(FinTheme.lineSoft)
    }
}
