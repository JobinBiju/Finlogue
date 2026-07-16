//
//  CategoryEditorView.swift
//  Finlogue
//

import SwiftUI

struct CategoryEditorView: View {
    var category: Category?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var type: TransactionType = .expense
    @State private var symbol = "tag"
    @State private var colorHex = "#4F8EF7"

    private static let symbols = [
        "tag", "fork.knife", "cart", "car", "bag", "bolt", "film", "cross.case",
        "house", "airplane", "gift", "book", "gamecontroller", "pawprint",
        "graduationcap", "wrench.and.screwdriver", "briefcase", "banknote",
        "indianrupeesign.circle", "arrow.uturn.backward.circle", "plus.circle",
        "wifi", "phone", "tram", "fuelpump", "pills", "tshirt", "scissors",
    ]

    private static let colors = [
        "#F97316", "#EF4444", "#EC4899", "#8B5CF6", "#3B82F6", "#0EA5E9",
        "#14B8A6", "#22C55E", "#EAB308", "#64748B", "#A855F7", "#F43F5E",
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.categorizable) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(Self.symbols, id: \.self) { candidate in
                            Button {
                                symbol = candidate
                            } label: {
                                Image(systemName: candidate)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        symbol == candidate ? Color(hex: colorHex) : Color(.systemGray5),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .foregroundStyle(symbol == candidate ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(Self.colors, id: \.self) { candidate in
                            Button {
                                colorHex = candidate
                            } label: {
                                Circle()
                                    .fill(Color(hex: candidate))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorHex == candidate {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(FinTheme.canvas)
            .fontDesign(.rounded)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                guard let category else { return }
                name = category.name
                type = category.type
                symbol = category.symbol
                colorHex = category.colorHex
            }
        }
    }

    private func save() {
        store.saveCategory(
            category,
            name: name.trimmingCharacters(in: .whitespaces),
            type: type,
            symbol: symbol,
            colorHex: colorHex
        )
        FinHaptics.success()
        dismiss()
    }
}
