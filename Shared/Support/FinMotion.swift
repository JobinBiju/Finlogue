//
//  FinMotion.swift
//  Finlogue
//
//  Motion vocabulary, tuned against a reference morphing-shape motion study:
//  springs everywhere with a tiny overshoot at most, content that swaps with
//  a short blur, and outgoing content that leaves before incoming arrives.
//  Every token falls back to a short crossfade under Reduce Motion.
//

import SwiftUI
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

enum FinMotion {
    // MARK: Tokens

    /// Press-down feedback on buttons and chips.
    static var press: Animation { resolved(.snappy(duration: 0.18)) }
    /// Selection changes: tabs, segments, chips.
    static var select: Animation { resolved(.snappy(duration: 0.3)) }
    /// Content swaps and small layout changes.
    static var swap: Animation { resolved(.smooth(duration: 0.3)) }
    /// Something growing into place — settles with a ~5% overshoot.
    static var grow: Animation { resolved(.spring(duration: 0.45, bounce: 0.15)) }
    /// Something shrinking away — no overshoot.
    static var shrink: Animation { resolved(.smooth(duration: 0.3)) }
    /// Shapes filling or drawing in: bars, rings, chart lines.
    static var reveal: Animation { resolved(.smooth(duration: 0.8)) }
    /// Counting numbers. A strong ease-out that lands on time — a spring's
    /// long tail would leave the last digits ticking for half a second.
    static var count: Animation { resolved(.timingCurve(0.16, 0.84, 0.3, 1, duration: 0.9)) }

    /// Delay between choreographed siblings.
    static let stagger: Double = 0.045

    /// Outgoing half of a blur swap — quick, so it clears before the new content lands.
    static var swapOut: Animation { resolved(.smooth(duration: 0.12)) }
    /// Incoming half of a blur swap — waits for the outgoing half.
    static var swapIn: Animation { resolved(.smooth(duration: 0.28)).delay(reduceMotion ? 0 : 0.08) }

    // MARK: Reduce Motion

    static var reduceMotion: Bool {
        #if os(watchOS)
        WKAccessibilityIsReduceMotionEnabled()
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    private static func resolved(_ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : animation
    }
}

// MARK: - Blur swap

/// Content fades through a short blur with a hint of scale — the "swap"
/// used whenever text or content changes inside a container that stays put.
struct BlurSwap: Transition {
    var radius: CGFloat = 6
    var scale: CGFloat = 0.96

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : scale)
    }
}

extension View {
    /// Blur swap with exit-before-enter timing, so swapped text never overlaps.
    func blurSwapTransition(radius: CGFloat = 6, scale: CGFloat = 0.96) -> some View {
        transition(
            AsymmetricTransition(
                insertion: BlurSwap(radius: radius, scale: scale).animation(FinMotion.swapIn),
                removal: BlurSwap(radius: radius, scale: scale).animation(FinMotion.swapOut)
            )
        )
    }

    /// One-time entrance: rises and un-blurs into place, `index` steps after
    /// its choreographed siblings. Under Reduce Motion it only fades.
    func finEntrance(_ isVisible: Bool, index: Int = 0) -> some View {
        modifier(EntranceModifier(isVisible: isVisible, index: index))
    }
}

private struct EntranceModifier: ViewModifier {
    let isVisible: Bool
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible || reduceMotion ? 0 : 4)
            .offset(y: isVisible || reduceMotion ? 0 : 14)
            .animation(
                FinMotion.grow.delay(Double(index) * FinMotion.stagger),
                value: isVisible
            )
    }
}

// MARK: - Pop

extension View {
    /// Pops the view (small → 1.18 → 1) when it appears and whenever
    /// `trigger` changes — the "landed" beat on checks and badges.
    func popOnAppear(after delay: Double = 0, trigger: some Equatable = 0) -> some View {
        modifier(PopModifier(delay: delay, trigger: trigger))
    }
}

private struct PopModifier<Trigger: Equatable>: ViewModifier {
    let delay: Double
    let trigger: Trigger

    @State private var pops = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: 1.0, trigger: pops) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0.6)
                    LinearKeyframe(0.6, duration: delay)
                    SpringKeyframe(1.18, duration: 0.2, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.26, spring: .smooth)
                }
            }
            .onAppear { if !reduceMotion { pops += 1 } }
            .onChange(of: trigger) { if !reduceMotion { pops += 1 } }
    }
}

// MARK: - Pressable buttons

/// Scales the label down while pressed. The action's own haptic stays at the
/// call site, so this never double-fires feedback.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(FinMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

// MARK: - Liquid indicator

/// Springs the two edges of a sliding indicator separately: the edge in the
/// direction of travel leads on a quick spring and the trailing edge follows
/// on a slower one, so the indicator stretches toward its target and settles.
/// Unmerged, so rapid retargets add up rather than restart.
struct EdgeSpringAnimation: CustomAnimation {
    var lead = Spring(duration: 0.26, bounce: 0.1)
    var follow = Spring(duration: 0.44, bounce: 0.06)

    func animate<V: VectorArithmetic>(
        value: V, time: TimeInterval, context: inout AnimationContext<V>
    ) -> V? {
        let settle = max(lead.settlingDuration, follow.settlingDuration)
        guard time < settle else { return nil }
        guard let edges = value as? AnimatablePair<CGFloat, CGFloat> else {
            return follow.value(target: value, time: time)
        }
        let movingRight = edges.first + edges.second > 0
        let leading = (movingRight ? follow : lead).value(target: edges.first, time: time)
        let trailing = (movingRight ? lead : follow).value(target: edges.second, time: time)
        return AnimatablePair(leading, trailing) as? V
    }
}

/// A capsule spanning `leading...trailing` horizontally, full height.
struct EdgePill: Shape {
    var leading: CGFloat
    var trailing: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(leading, trailing) }
        set {
            leading = newValue.first
            trailing = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let span = CGRect(
            x: leading, y: rect.minY,
            width: max(trailing - leading, 0), height: rect.height
        )
        return Capsule(style: .continuous).path(in: span)
    }
}

// MARK: - Counting numbers

/// Currency that counts through intermediate values while animating (rather
/// than rolling glyphs), for headline totals. Whole units mid-flight, the
/// exact figure once it lands.
struct CountingCurrencyText: View, Animatable {
    var value: Double
    /// Where `value` is heading; lets the label show exact cents on arrival.
    var target: Double

    init(_ value: Double) {
        self.value = value
        self.target = value
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        let landed = abs(value - target) < 0.005
        Text(CurrencyFormatter.string(landed ? target : value.rounded()))
    }
}

// MARK: - Tab activity

extension View {
    /// Runs `action` once, a beat after this view's tab first comes on
    /// screen. The environment is read inside the modifier, so a tab switch
    /// re-evaluates only the modifier — not the (heavy) screen around it.
    func onFirstTabActivation(
        after delay: Duration = .milliseconds(120), perform action: @escaping () -> Void
    ) -> some View {
        modifier(FirstTabActivationModifier(delay: delay, action: action))
    }
}

private struct FirstTabActivationModifier: ViewModifier {
    let delay: Duration
    let action: () -> Void

    @Environment(\.isTabActive) private var isTabActive
    @State private var fired = false

    func body(content: Content) -> some View {
        content.task(id: isTabActive) {
            guard isTabActive, !fired else { return }
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            fired = true
            action()
        }
    }
}

private struct TabActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while a tab is kept alive but hidden, so first-appearance motion
    /// can wait until the tab is actually on screen.
    var isTabActive: Bool {
        get { self[TabActiveKey.self] }
        set { self[TabActiveKey.self] = newValue }
    }
}
