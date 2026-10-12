//
//  ProgressFill.swift
//  Finlogue
//
//  A capsule bar's fill that moves on an offset instead of animating its
//  width: a full-width capsule slides in from the leading edge and the track
//  clips it, so growing the bar never re-runs layout and the leading end
//  stays round.
//

import SwiftUI

struct ProgressFill: View {
    /// 0...1; values past 1 show a full bar.
    var fraction: Double
    var color: Color
    /// The shortest visible fill, so a small non-zero value still shows.
    var minimumWidth: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = min(max(fraction, 0), 1)
            let shown = clamped > 0 ? max(width * clamped, minimumWidth) : 0
            Capsule()
                .fill(color)
                .frame(width: width)
                .offset(x: shown - width)
        }
        .clipShape(Capsule())
    }
}
