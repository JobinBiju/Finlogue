//
//  PeopleSettingsView.swift
//  Finlogue
//
//  People management sub-screen: friends/family that transactions can be
//  tagged to. Spending on their behalf is excluded from insights and budgets.
//

import SwiftUI
import SwiftData

struct PeopleSettingsView: View {
    @EnvironmentObject private var store: TransactionStore
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Person.name) private var people: [Person]

    @State private var showAddPerson = Self.launchIntoAddPerson
    @State private var selectedPerson: Person?

    /// Test hook: `-showAddPerson` opens the person editor on launch.
    private static var launchIntoAddPerson: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showAddPerson")
        #else
        return false
        #endif
    }

    var body: some View {
        List {
            headerSection
            if people.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No people yet",
                        systemImage: "person.2",
                        description: Text("Add a friend or family member, then tag a transaction to them when you spend on their behalf.")
                    )
                    .listRowBackground(Color.clear)
                }
                .padding(.vertical, 40)
            } else {
                Section {
                    ForEach(people) { person in
                        personRow(person)
                    }
                } footer: {
                    Text("Split expenses still move your balance, but only your share counts toward insights and budgets — you'll be paid back for the rest.")
                        .font(.system(size: 12))
                        .foregroundStyle(FinTheme.ink400)
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
        .onDisappear {
            // Only reveal the tab bar when leaving back to Settings — not when
            // pushing into a person's detail (selectedPerson set).
            if selectedPerson == nil {
                tabBarVisibility.isHidden = false
            }
        }
        .sheet(isPresented: $showAddPerson) { PersonEditorView() }
        .navigationDestination(item: $selectedPerson) { person in
            PersonDetailView(person: person)
        }
    }

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
                Text("People")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .padding(.leading, 8)
                Spacer()
                Button {
                    FinHaptics.tap()
                    showAddPerson = true
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
            .textCase(nil)
            .finHeaderAligned()
            .padding(.top, 8)
        }
    }

    private func personRow(_ person: Person) -> some View {
        Button {
            FinHaptics.tap()
            selectedPerson = person
        } label: {
            HStack(spacing: 12) {
                Text(person.initials)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color(hex: person.colorHex), in: Circle())
                Text(person.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                outstandingLabel(person)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FinTheme.ink400.opacity(0.6))
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(FinTheme.paper)
        .listRowSeparatorTint(FinTheme.lineSoft)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                FinHaptics.warning()
                store.delete(person)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func outstandingLabel(_ person: Person) -> some View {
        let balance = person.outstanding
        if abs(balance) < 0.005 {
            Text("Settled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FinTheme.ink400)
        } else {
            Text("\(balance < 0 ? "−" : "")\(CurrencyFormatter.string(abs(balance)))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(balance < 0 ? FinTheme.red : FinTheme.green)
                .monospacedDigit()
        }
    }
}
