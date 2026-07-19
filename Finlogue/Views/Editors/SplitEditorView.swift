//
//  SplitEditorView.swift
//  Finlogue
//
//  Split a transaction among friends with exact amounts. "You" are never a row —
//  your share is the remainder shown live at the bottom.
//

import SwiftUI
import SwiftData

/// One friend's editable share while composing a transaction.
struct SplitDraft: Identifiable {
    let id: UUID
    var personID: UUID
    var amount: Double

    init(id: UUID = UUID(), personID: UUID, amount: Double) {
        self.id = id
        self.personID = personID
        self.amount = amount
    }
}

struct SplitEditorView: View {
    @Binding var splits: [SplitDraft]
    /// The full outlay (amount + charges) being divided.
    let total: Double

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Person.name) private var people: [Person]

    @State private var showNewPerson = false
    @State private var newPersonName = ""

    private var othersTotal: Double {
        splits.reduce(0) { $0 + max(0, $1.amount) }
    }

    private var myShare: Double { total - othersTotal }

    /// People not already added as a row.
    private var availablePeople: [Person] {
        let used = Set(splits.map(\.personID))
        return people.filter { !used.contains($0.id) }
    }

    private func person(_ id: UUID) -> Person? {
        people.first { $0.id == id }
    }

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
                    withAnimation(.snappy(duration: 0.2)) { splits = [] }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(splits.isEmpty ? FinTheme.ink400 : FinTheme.coral)
                .disabled(splits.isEmpty)
                Spacer()
                Text("Split")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Done") {
                    splits.removeAll { $0.amount <= 0 }
                    dismiss()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FinTheme.coral)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 16) {
                    totalHeader
                    if !splits.isEmpty {
                        splitRows
                    }
                    addPersonRow
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .alert("New person", isPresented: $showNewPerson) {
            TextField("Name", text: $newPersonName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let trimmed = newPersonName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let created = store.savePerson(nil, name: trimmed, colorHex: "")
                addSplit(for: created)
                FinHaptics.success()
            }
        } message: {
            Text("Add a friend or family member to split with.")
        }
    }

    // MARK: Total + your share

    private var totalHeader: some View {
        VStack(spacing: 12) {
            row(label: "Total", value: total, weight: .semibold, color: FinTheme.ink)
            Divider().overlay(FinTheme.lineSoft)
            row(
                label: "Your share",
                value: myShare,
                weight: .bold,
                color: myShare < 0 ? FinTheme.red : FinTheme.coral
            )
            if myShare < 0 {
                Text("Others' shares exceed the total.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FinTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .finCard(radius: 16)
    }

    private func row(label: String, value: Double, weight: Font.Weight, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
            Spacer()
            Text(CurrencyFormatter.string(value))
                .font(.system(size: 17, weight: weight))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    // MARK: Per-person rows

    private var splitRows: some View {
        VStack(spacing: 0) {
            ForEach($splits) { $draft in
                if let person = person(draft.personID) {
                    HStack(spacing: 12) {
                        Text(person.initials)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: person.colorHex), in: Circle())
                        Text(person.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FinTheme.ink)
                        Spacer()
                        HStack(spacing: 3) {
                            Text(CurrencyFormatter.symbol())
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(FinTheme.ink400)
                            TextField("0", value: $draft.amount, format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FinTheme.ink)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 44)
                                .fixedSize()
                        }
                        Button {
                            FinHaptics.tap()
                            withAnimation(.snappy(duration: 0.2)) {
                                splits.removeAll { $0.id == draft.id }
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(FinTheme.ink400)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 10)
                    if draft.id != splits.last?.id {
                        Divider().overlay(FinTheme.lineSoft)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .finCard(radius: 16)
    }

    // MARK: Add a person

    private var addPersonRow: some View {
        Menu {
            if !availablePeople.isEmpty {
                Section("Add someone") {
                    ForEach(availablePeople) { person in
                        Button(person.name) { addSplit(for: person) }
                    }
                }
            }
            Button {
                newPersonName = ""
                showNewPerson = true
            } label: {
                Label("New person…", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("Add person")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(FinTheme.coral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .finCard(radius: 16)
        }
    }

    /// Adds a row for a person; you enter their exact amount.
    private func addSplit(for person: Person) {
        withAnimation(.snappy(duration: 0.2)) {
            splits.append(SplitDraft(personID: person.id, amount: 0))
        }
    }
}
