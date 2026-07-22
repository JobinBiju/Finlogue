//
//  ThemedDateField.swift
//  Finlogue
//
//  A date/time field whose collapsed value uses the theme's ink color — the
//  system compact DatePicker forces white text in dark mode and can't be
//  recolored, so we show our own label and open a graphical picker in a popover.
//

import SwiftUI

struct ThemedDateField: View {
    @Binding var date: Date
    var components: DatePickerComponents = [.date]

    @State private var showPicker = false

    private var label: String {
        if components.contains(.hourAndMinute) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Button {
            FinHaptics.tap()
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FinTheme.ink)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FinTheme.ink400)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            DatePicker("", selection: $date, displayedComponents: components)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(FinTheme.coral)
                .padding()
                .frame(width: 340)
                .presentationCompactAdaptation(.popover)
        }
    }
}
