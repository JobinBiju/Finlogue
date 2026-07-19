//
//  CategoryEditorView.swift
//  Finlogue
//
//  Design-system category sheet: cream canvas, pill type segments,
//  paper cards for icon and color pickers.
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
        // Food & drink
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill", "birthday.cake.fill", "carrot.fill",
        // Shopping
        "cart", "bag", "handbag.fill", "gift.fill", "tshirt", "giftcard.fill",
        // Transport
        "car", "bus.fill", "tram", "bicycle", "airplane", "fuelpump", "parkingsign.circle.fill",
        // Home & bills
        "house", "bolt.fill", "drop.fill", "flame.fill", "lightbulb.fill", "wifi",
        "phone", "trash.fill", "wrench.and.screwdriver",
        // Health & fitness
        "cross.case", "pills", "heart.fill", "stethoscope", "figure.run", "dumbbell.fill",
        // Entertainment
        "film", "gamecontroller", "music.note", "tv", "headphones", "ticket.fill",
        // Money & finance
        "banknote", "creditcard.fill", "building.columns.fill", "indianrupeesign.circle",
        "chart.line.uptrend.xyaxis", "percent", "arrow.uturn.backward.circle",
        // Work & study
        "briefcase", "book", "graduationcap", "laptopcomputer", "pencil", "newspaper.fill",
        // Travel & personal
        "suitcase.fill", "beach.umbrella.fill", "map.fill", "pawprint", "scissors",
        "eyeglasses", "leaf.fill", "gift", "star.fill", "sparkles", "tag", "plus.circle",
    ]

    private static let colors = [
        "#F97316", "#EF4444", "#EC4899", "#8B5CF6", "#3B82F6", "#0EA5E9",
        "#14B8A6", "#22C55E", "#EAB308", "#64748B", "#A855F7", "#F43F5E",
    ]

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FinTheme.ink600)
                Spacer()
                Text(category == nil ? "New category" : "Edit category")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(FinTheme.ink)
                Spacer()
                Button("Save") { save() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSave ? FinTheme.coral : FinTheme.ink400)
                    .disabled(!canSave)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)

            ScrollView {
                VStack(spacing: 20) {
                    nameEntry
                    typeSegments
                    iconCard
                    colorCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .onAppear {
            guard let category else { return }
            name = category.name
            type = category.type
            symbol = category.symbol
            colorHex = category.colorHex
        }
    }

    // MARK: Pieces

    private var nameEntry: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    Color(hex: colorHex),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            TextField("Category name", text: $name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(FinTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .finCard(radius: 16)
        }
    }

    private var typeSegments: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.categorizable) { candidate in
                Button {
                    FinHaptics.selection()
                    withAnimation(.snappy(duration: 0.25)) {
                        type = candidate
                    }
                } label: {
                    Text(candidate.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(type == candidate ? .white : FinTheme.ink400)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if type == candidate {
                                Capsule()
                                    .fill(FinTheme.coral)
                                    .shadow(color: FinTheme.coral.opacity(0.28), radius: 8, x: 0, y: 5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(FinTheme.paper, in: Capsule())
    }

    private var iconCard: some View {
        labeledCard("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Self.symbols, id: \.self) { candidate in
                    Button {
                        FinHaptics.selection()
                        symbol = candidate
                    } label: {
                        Image(systemName: candidate)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 40, height: 40)
                            .background(
                                symbol == candidate ? FinTheme.coral : FinTheme.paperInset,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .foregroundStyle(symbol == candidate ? .white : FinTheme.ink600)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var colorCard: some View {
        labeledCard("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                ForEach(Self.colors, id: \.self) { candidate in
                    Button {
                        FinHaptics.selection()
                        colorHex = candidate
                    } label: {
                        Circle()
                            .fill(Color(hex: candidate))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if colorHex == candidate {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func labeledCard(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .finSectionLabel()
                .padding(.leading, 4)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .finCard(radius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Logic (unchanged)

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
