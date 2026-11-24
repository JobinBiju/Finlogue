//
//  SplitEditorView.swift
//  Finlogue
//
//  Exact amounts, equal portions, or weighted shares including your own.
//

import SwiftUI
import SwiftData

struct SplitEditorView: View {
    @Binding private var savedPlan: SplitPlan
    let total: Double

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.name) private var people: [Person]

    @State private var plan: SplitPlan
    @State private var showNewPerson = false
    @State private var newPersonName = ""

    init(plan: Binding<SplitPlan>, total: Double) {
        _savedPlan = plan
        _plan = State(initialValue: plan.wrappedValue)
        self.total = total
    }

    private var amounts: [Double]? { plan.amounts(total: total) }
    private var canApply: Bool { amounts != nil }
    private var availablePeople: [Person] {
        let used = Set(plan.participants.map(\.personID))
        return people.filter { !used.contains($0.id) }
    }
    private var totalShares: Double {
        plan.ownShares + plan.participants.reduce(0) { $0 + $1.shares }
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(FinTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 2)

            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(FinTheme.ink600)
                Spacer()
                Text("Split")
                    .fontWeight(.bold)
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Done") {
                    guard canApply else { return }
                    savedPlan = plan
                    FinHaptics.tap()
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundStyle(canApply ? FinTheme.coral : FinTheme.ink400)
                .disabled(!canApply)
            }
            .font(.system(size: 16, weight: .medium))
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    totalHeader
                    methodPicker
                    participantsCard
                    addPersonRow
                    if !plan.participants.isEmpty {
                        Button("Clear split") {
                            FinHaptics.tap()
                            plan = SplitPlan()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FinTheme.coral)
                        .frame(minHeight: 44)
                    }
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
                let trimmed = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let created = store.savePerson(nil, name: trimmed, colorHex: "")
                addSplit(for: created)
                FinHaptics.success()
            }
        } message: {
            Text("Add a friend or family member to split with.")
        }
    }

    private var totalHeader: some View {
        VStack(spacing: 12) {
            amountRow(label: "Bill total", value: total, emphasized: false)
            Divider().overlay(FinTheme.lineSoft)
            if let ownAmount = amounts?.first {
                amountRow(label: "Your share", value: ownAmount, emphasized: true)
            } else {
                HStack {
                    Text("Your share")
                    Spacer()
                    Text("—")
                }
                .foregroundStyle(FinTheme.red)
            }
            if !canApply {
                Text(plan.method == .exact
                     ? "Enter valid amounts that add up to no more than the bill."
                     : "Use zero or more shares per person, with at least one share in total.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FinTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if total == 0 {
                Text("Set up the split now. Amounts will update when you enter the bill total.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .finCard(radius: 16)
    }

    private func amountRow(label: String, value: Double, emphasized: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink600)
            Spacer()
            Text(CurrencyFormatter.string(value))
                .font(.system(size: emphasized ? 24 : 17, weight: .bold))
                .foregroundStyle(emphasized ? FinTheme.coral : FinTheme.ink)
                .monospacedDigit()
        }
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Split by").finSectionLabel()
            Picker("Split method", selection: Binding(
                get: { plan.method },
                set: { method in
                    FinHaptics.selection()
                    plan.select(method, total: total)
                }
            )) {
                ForEach(SplitMethod.allCases) { method in
                    Text(method.label).tag(method)
                }
            }
            .pickerStyle(.segmented)
            Text(methodDescription)
                .font(.system(size: 13))
                .foregroundStyle(FinTheme.ink400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var methodDescription: String {
        switch plan.method {
        case .exact: "Enter each person's amount. You pay the remainder."
        case .equal: "Everyone included pays an equal portion of the bill."
        case .shares: "Use + and − or enter a count. More shares means a larger portion."
        }
    }

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("People").finSectionLabel()
                Spacer()
                if plan.method == .shares, canApply {
                    Text("\(totalShares.formatted(.number.grouping(.never))) total shares")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FinTheme.ink400)
                }
            }
            VStack(spacing: 0) {
                ownRow
                ForEach($plan.participants) { $draft in
                    if let person = people.first(where: { $0.id == draft.personID }) {
                        Divider().overlay(FinTheme.lineSoft)
                        participantRow(person: person, draft: $draft)
                    }
                }
            }
            .padding(.horizontal, 14)
            .finCard(radius: 16)
            if plan.participants.isEmpty {
                Text("Add someone to share this bill with.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
            } else if plan.method != .exact {
                Text("Any rounding difference is distributed so the amounts match the bill total.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var ownRow: some View {
        if plan.method == .shares {
            weightedRow(name: "You", initials: nil, color: FinTheme.coral,
                        shares: $plan.ownShares, amount: amounts?.first)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FinTheme.coral)
                    .frame(width: 32, height: 32)
                    .background(FinTheme.tintCoral, in: Circle())
                Text("You")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                Spacer(minLength: 8)
                calculatedAmount(amounts?.first)
                if plan.method == .equal {
                    Button {
                        plan.ownShares = plan.ownShares > 0 ? 0 : 1
                        FinHaptics.selection()
                    } label: {
                        Image(systemName: plan.ownShares > 0 ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(plan.ownShares > 0 ? FinTheme.coral : FinTheme.ink400)
                            .font(.system(size: 21))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Include yourself")
                    .accessibilityValue(plan.ownShares > 0 ? "Included" : "Excluded")
                } else {
                    Color.clear.frame(width: 44, height: 1)
                }
            }
            .frame(minHeight: 44)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func participantRow(person: Person, draft: Binding<SplitDraft>) -> some View {
        if plan.method == .shares {
            weightedRow(name: person.name, initials: person.initials, color: Color(hex: person.colorHex),
                        shares: draft.shares, amount: amount(for: draft.wrappedValue.id)) {
                plan.participants.removeAll { $0.id == draft.wrappedValue.id }
            }
        } else {
            HStack(spacing: 10) {
                Text(person.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: person.colorHex), in: Circle())
                Text(person.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if plan.method == .exact {
                    HStack(spacing: 3) {
                        Text(CurrencyFormatter.symbol()).foregroundStyle(FinTheme.ink400)
                        SplitNumberField(value: draft.amount, label: "Amount for \(person.name)")
                    }
                } else {
                    calculatedAmount(amount(for: draft.wrappedValue.id))
                }
                Button {
                    FinHaptics.tap()
                    plan.participants.removeAll { $0.id == draft.wrappedValue.id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(FinTheme.ink400)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(person.name)")
            }
            .frame(minHeight: 44)
            .padding(.vertical, 10)
        }
    }

    private func amount(for id: UUID) -> Double? {
        guard let index = plan.participants.firstIndex(where: { $0.id == id }), let amounts else { return nil }
        return amounts[index + 1]
    }

    private func calculatedAmount(_ amount: Double?) -> some View {
        Text(amount.map { CurrencyFormatter.string($0) } ?? "—")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(FinTheme.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func weightedRow(
        name: String, initials: String?, color: Color, shares: Binding<Double>,
        amount: Double?, remove: (() -> Void)? = nil
    ) -> some View {
        let fraction = canApply && totalShares > 0 ? max(0, shares.wrappedValue / totalShares) : 0
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Group {
                    if let initials {
                        Text(initials).font(.system(size: 12, weight: .bold))
                    } else {
                        Image(systemName: "person.fill").font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: Circle())
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(amount.map { CurrencyFormatter.string($0) } ?? "—")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let remove {
                    Button {
                        FinHaptics.tap()
                        remove()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(FinTheme.ink400)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(name)")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            HStack(spacing: 12) {
                shareStepper(value: shares, name: name)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(fraction.formatted(.percent.precision(.fractionLength(0...1))))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                    Text(canApply
                         ? "\(shares.wrappedValue.formatted(.number.grouping(.never))) of \(totalShares.formatted(.number.grouping(.never))) shares"
                         : "Enter shares")
                        .font(.system(size: 11))
                        .foregroundStyle(FinTheme.ink400)
                        .lineLimit(1)
                }
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(color).frame(width: proxy.size.width * min(1, fraction))
                    }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 16)
    }

    private func shareStepper(value: Binding<Double>, name: String) -> some View {
        HStack(spacing: 0) {
            Button {
                value.wrappedValue = max(0, value.wrappedValue - 1)
                FinHaptics.selection()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!value.wrappedValue.isFinite || value.wrappedValue <= 0)
            .accessibilityLabel("Decrease shares for \(name)")
            SplitNumberField(value: value, label: name == "You" ? "Your shares" : "Shares for \(name)", centered: true)
                .frame(width: 48)
            Button {
                value.wrappedValue = value.wrappedValue.isFinite && value.wrappedValue >= 0 ? value.wrappedValue + 1 : 1
                FinHaptics.selection()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Increase shares for \(name)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(FinTheme.coral)
        .frame(width: 136, height: 48)
        .fixedSize(horizontal: true, vertical: false)
        .background(FinTheme.canvas, in: Capsule())
    }

    private var addPersonRow: some View {
        Menu {
            ForEach(availablePeople) { person in
                Button(person.name) { addSplit(for: person) }
            }
            Button {
                newPersonName = ""
                showNewPerson = true
            } label: {
                Label("New person…", systemImage: "plus")
            }
        } label: {
            Label("Add person", systemImage: "person.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FinTheme.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .finCard(radius: 16)
        }
    }

    private func addSplit(for person: Person) {
        guard !plan.participants.contains(where: { $0.personID == person.id }) else { return }
        plan.participants.append(SplitDraft(personID: person.id))
    }
}

/// Keep text while typing so a trailing decimal separator is not lost.
private struct SplitNumberField: View {
    @Binding var value: Double
    let label: String
    var centered = false
    @State private var text: String
    @FocusState private var focused: Bool

    init(value: Binding<Double>, label: String, centered: Bool = false) {
        _value = value
        self.label = label
        self.centered = centered
        _text = State(initialValue: value.wrappedValue > 0 ? AmountInput.string(value.wrappedValue) : "")
    }

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(FinTheme.ink)
            .multilineTextAlignment(centered ? .center : .trailing)
            .frame(width: centered ? 44 : 62, height: 30)
            .accessibilityLabel(label)
            .onChange(of: text) { _, newValue in
                value = newValue.isEmpty ? 0 : (AmountInput.parse(newValue) ?? -1)
            }
            .onChange(of: value) { _, newValue in
                guard AmountInput.parse(text) != newValue else { return }
                text = newValue > 0 ? AmountInput.string(newValue) : ""
            }
    }
}
