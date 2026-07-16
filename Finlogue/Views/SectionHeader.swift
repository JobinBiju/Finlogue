//
//  SectionHeader.swift
//  Finlogue
//
//  Design-system section label: small uppercase, wide tracking, warm muted.
//

import SwiftUI

struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .finSectionLabel()
            .padding(.bottom, 4)
            .padding(.leading, 4)
            .finHeaderAligned()
    }
}
