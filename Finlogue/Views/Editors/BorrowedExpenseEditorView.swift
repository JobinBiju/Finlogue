//
//  BorrowedExpenseEditorView.swift
//  Finlogue
//
//  Logs an expense a person paid on your behalf: it's your spending, so it
//  gets a category and counts toward insights and budgets, but it touches no
//  account — and it adds to what you owe that person.
//

import SwiftUI
import SwiftData

struct BorrowedExpenseEditorView: View {
    let person: Person

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var amountText = ""
    @State private var name = ""
    @State private var selectedCategoryID: UUID?
    @State private var date = Date.now
    @State private var note = ""
    @FocusState private var amountFocused: Bool

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }

    private var amount: Double? {
        let groupSeparator = Locale.current.groupingSeparator ?? ","
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let raw = amountText
            .replacingOccurrences(of: groupSeparator, with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Double(raw)
    }

    private var canSave: Bool { (amount ?? 0) > 0 }

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
                Text("\(person.name) paid for you")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
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
                    Text("Counts as your spending — you owe it back")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)

                    HStack(alignment: .center, spacing: 4) {
                        Text(CurrencyFormatter.symbol())
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(FinTheme.ink400)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.system(size: 64, weight: .heavy))
                            .kerning(-0.5)
                            .foregroundStyle(FinTheme.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture { amountFocused = true }

                    detailsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .onAppear { amountFocused = true }
    }

    private var selectedCategory: Category? {
        expenseCategories.first { $0.id == selectedCategoryID }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                detailRow(label: "Name") {
                    TextField("e.g. Lunch", text: $name)
                        .font(.system(size: 15))
                        .foregroundStyle(FinTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Category") {
                    Menu {
                        ForEach(expenseCategories) { category in
                            Button {
                                selectedCategoryID = category.id
                            } label: {
                                Label(category.name, systemImage: category.symbol)
                            }
                        }
                    } label: {
                        detailValue(selectedCategory?.name ?? "Select")
                    }
                }
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Date") {
                    ThemedDateField(date: $date, components: [.date, .hourAndMinute])
                }
                Divider().overlay(FinTheme.lineSoft)
                detailRow(label: "Note") {
                    TextField("Optional", text: $note)
                        .font(.system(size: 15))
                        .foregroundStyle(FinTheme.ink)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
        }
    }

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

    private func save() {
        guard let amount else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        store.recordBorrowedExpense(
            person: person,
            name: trimmedName.isEmpty ? (selectedCategory?.name ?? "Borrowed") : trimmedName,
            amount: amount,
            category: selectedCategory,
            date: date,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        FinHaptics.success()
        dismiss()
    }
}
