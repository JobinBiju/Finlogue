//
//  LiquidSegmentedControl.swift
//  Finlogue
//
//  Segmented control whose selection pill stretches between segments: its
//  two edges ride different springs (see `EdgeSpringAnimation`). Labels are
//  drawn twice — plain underneath, "on pill" styling on top masked by the
//  same pill — so a label changes color exactly where the pill covers it.
//

import SwiftUI

struct LiquidSegmentedControl<Item: Hashable, Segment: View, Pill: View>: View {
    let items: [Item]
    let selection: Item
    var spacing: CGFloat = 0
    let onSelect: (Item) -> Void
    /// Draws a segment. `isSelected` may change layout (both layers get it);
    /// `onPill` must only change styling, or the two layers drift apart.
    @ViewBuilder let segment: (_ item: Item, _ isSelected: Bool, _ onPill: Bool) -> Segment
    /// Fills the pill — receives the pill shape.
    @ViewBuilder let pill: (EdgePill) -> Pill

    @State private var frames: [Item: CGRect] = [:]

    private let space = "LiquidSegmentedControl"

    private var edges: AnimatablePair<CGFloat, CGFloat>? {
        guard let frame = frames[selection] else { return nil }
        return AnimatablePair(frame.minX, frame.maxX)
    }

    var body: some View {
        row(onPill: false)
            .background(alignment: .leading) {
                if let edges {
                    pill(EdgePill(leading: edges.first, trailing: edges.second))
                        .animation(Animation(EdgeSpringAnimation()), value: edges)
                }
            }
            .overlay {
                if let edges {
                    row(onPill: true)
                        .mask {
                            EdgePill(leading: edges.first, trailing: edges.second)
                                .animation(Animation(EdgeSpringAnimation()), value: edges)
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .coordinateSpace(.named(space))
    }

    private func row(onPill: Bool) -> some View {
        HStack(spacing: spacing) {
            ForEach(items, id: \.self) { item in
                let isSelected = item == selection
                if onPill {
                    segment(item, isSelected, true)
                } else {
                    Button {
                        onSelect(item)
                    } label: {
                        segment(item, isSelected, false)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(StillButtonStyle())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(space))
                    } action: { frame in
                        frames[item] = frame
                    }
                }
            }
        }
    }
}

/// No press styling — the masked top layer can't mirror a pressed look.
private struct StillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
