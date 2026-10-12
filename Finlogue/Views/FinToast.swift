//
//  FinToast.swift
//  Finlogue
//
//  Confirmation toast that morphs as one shape: an ink dot drops in under
//  the Dynamic Island, its check pops, it stretches into a pill while the
//  message blurs in, then shrinks back to the dot and away.
//

import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String?
        let symbol: String
    }

    enum Phase {
        case hidden, dot, expanded
    }

    @Published private(set) var toast: Toast?
    @Published private(set) var phase: Phase = .hidden

    private var sequence: Task<Void, Never>?

    /// Shows a confirmation. `delay` lets a dismissing sheet clear the screen
    /// first. A toast arriving mid-display swaps its message in place.
    func show(
        _ title: String, detail: String? = nil, symbol: String = "checkmark",
        after delay: Duration = .zero
    ) {
        sequence?.cancel()
        sequence = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            let wasShowing = phase != .hidden
            toast = Toast(title: title, detail: detail, symbol: symbol)
            AccessibilityNotification.Announcement(
                [title, detail].compactMap { $0 }.joined(separator: ", ")
            ).post()
            if !wasShowing {
                withAnimation(FinMotion.surface) { self.phase = .dot }
                // Let the check land before the pill stretches out of it.
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
            }
            withAnimation(FinMotion.surface) { self.phase = .expanded }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await collapse()
        }
    }

    func dismiss() {
        sequence?.cancel()
        sequence = Task { [weak self] in await self?.collapse() }
    }

    private func collapse() async {
        withAnimation(FinMotion.quick) { self.phase = .dot }
        try? await Task.sleep(for: .milliseconds(240))
        guard !Task.isCancelled else { return }
        withAnimation(FinMotion.quick) { self.phase = .hidden }
    }
}

struct FinToastView: View {
    @ObservedObject var center: ToastCenter

    var body: some View {
        ZStack {
            if center.phase != .hidden, let toast = center.toast {
                pill(toast)
                    .transition(
                        AsymmetricTransition(
                            insertion: DotTransition().animation(FinMotion.surface),
                            removal: DotTransition().animation(FinMotion.quick)
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pill(_ toast: ToastCenter.Toast) -> some View {
        let expanded = center.phase == .expanded
        return HStack(spacing: 10) {
            Image(systemName: toast.symbol)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(FinTheme.coral, in: Circle())
                .popOnAppear(after: 0.1, trigger: toast.id)

            if expanded {
                HStack(spacing: 6) {
                    Text(toast.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FinTheme.cream)
                    if let detail = toast.detail {
                        Text(detail)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FinTheme.cream.opacity(0.7))
                            .monospacedDigit()
                    }
                }
                .lineLimit(1)
                .fixedSize()
                .id(toast.id)
                .blurSwapTransition()
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, expanded ? 16 : 6)
        .frame(height: 36)
        .background(FinTheme.ink, in: Capsule())
        .shadow(color: FinTheme.shadowTint.opacity(0.18), radius: 14, x: 0, y: 8)
        .contentShape(Capsule())
        .onTapGesture { center.dismiss() }
        .gesture(
            DragGesture(minimumDistance: 8).onEnded { value in
                if value.translation.height < -8 { center.dismiss() }
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// The dot drops its own height from under the Dynamic Island and fades in,
/// and leaves back up the same way. Under Reduce Motion it only fades.
private struct DotTransition: Transition {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.95)
            .opacity(phase.isIdentity ? 1 : 0)
            .offset(y: phase.isIdentity || reduceMotion ? 0 : -36)
    }
}
