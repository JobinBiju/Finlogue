//
//  SectionHeader.swift
//  Finlogue
//
//  Consistent section title style: 16pt semibold, leading-aligned with the
//  card edge, no automatic uppercasing.
//

import SwiftUI

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.leading, 0)
            .padding(.bottom, 4)
    }
}
