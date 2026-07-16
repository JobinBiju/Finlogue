//
//  CategoriesSettingsView.swift
//  Finlogue
//
//  Categories management sub-screen: expense and income groups.
//

import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @EnvironmentObject private var store: TransactionStore
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var editingCategory: Category?
    @State private var showAddCategory = Self.launchIntoAddCategory

    /// Test hook: `-showAddCategory` opens the category editor on launch.
    private static var launchIntoAddCategory: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-showAddCategory")
        #else
        return false
        #endif
    }

    var body: some View {
        List {
            headerSection
            ForEach([TransactionType.expense, .income]) { categoryType in
                let members = categories.filter { $0.type == categoryType }
                if !members.isEmpty {
                    Section {
                        ForEach(members) { category in
                            categoryRow(category)
                        }
                    } header: {
                        SectionHeader("\(categoryType.label) categories")
                    }
                }
            }
            Section {
            } footer: {
                Text("Tap a category to edit its name, icon and color.")
                    .font(.system(size: 12))
                    .foregroundStyle(FinTheme.ink400)
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
        .onDisappear { tabBarVisibility.isHidden = false }
        .sheet(isPresented: $showAddCategory) { CategoryEditorView() }
        .sheet(item: $editingCategory) { CategoryEditorView(category: $0) }
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
                Text("Categories")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(FinTheme.ink)
                    .padding(.leading, 8)
                Spacer()
                Button {
                    FinHaptics.tap()
                    showAddCategory = true
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

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    Color(hex: category.colorHex),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            Text(category.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FinTheme.ink)
            Spacer()
        }
        .padding(.vertical, 2)
        .listRowBackground(FinTheme.paper)
        .listRowSeparatorTint(FinTheme.lineSoft)
        .contentShape(Rectangle())
        .onTapGesture { editingCategory = category }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                FinHaptics.warning()
                store.delete(category)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
