//
//  PersonEditorView.swift
//  Finlogue
//
//  Add / edit a person: name plus an avatar colour.
//

import SwiftUI

struct PersonEditorView: View {
    var person: Person?

    @EnvironmentObject private var store: TransactionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = Person.palette[0]
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)

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
                Text(person == nil ? "New person" : "Edit person")
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
                VStack(spacing: 24) {
                    Text(initials)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Color(hex: colorHex), in: Circle())
                        .shadow(color: Color(hex: colorHex).opacity(0.3), radius: 12, x: 0, y: 6)
                        .padding(.top, 8)

                    TextField("Name", text: $name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FinTheme.ink)
                        .multilineTextAlignment(.center)
                        .focused($nameFocused)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .finCard(radius: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colour")
                            .finSectionLabel()
                            .padding(.leading, 4)
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(Person.palette, id: \.self) { hex in
                                let isSelected = hex == colorHex
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(height: 32)
                                    .overlay {
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .overlay(
                                        Circle().strokeBorder(
                                            FinTheme.ink.opacity(isSelected ? 0.25 : 0), lineWidth: 2
                                        )
                                    )
                                    .onTapGesture {
                                        FinHaptics.selection()
                                        colorHex = hex
                                    }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .finCard(radius: 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(FinTheme.canvas)
        .fontDesign(.rounded)
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let person else {
            nameFocused = true
            return
        }
        name = person.name
        colorHex = person.colorHex
    }

    private func save() {
        store.savePerson(
            person, name: name.trimmingCharacters(in: .whitespaces), colorHex: colorHex
        )
        FinHaptics.success()
        dismiss()
    }
}
