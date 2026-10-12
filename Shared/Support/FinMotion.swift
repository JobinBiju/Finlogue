//
//  FinMotion.swift
//  Finlogue
//
//  The house motion tokens (Emil Kowalski's craft rules + the Scoop motion
//  values). Every duration, curve and spring in the app comes from here;
//  nothing is written inline. Motion confirms and orders content — it never
//  decorates. Under Reduce Motion, movement drops to a short fade.
//

import SwiftUI
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

enum FinMotion {
    // MARK: Curves

    /// The house ease-out, for anything entering, exiting or responding.
    static let easeOutCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.22, y: 1), endControlPoint: UnitPoint(x: 0.36, y: 1)
    )
    /// For something already on screen moving somewhere without a spring.
    static let easeInOutCurve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.77, y: 0), endControlPoint: UnitPoint(x: 0.175, y: 1)
    )

    // MARK: Springs (mass 1)

    /// Settles ≈0.41s with a 3% overshoot.
    static let pressSpring = Spring(mass: 1, stiffness: 420, damping: 30)
    /// Settles ≈0.39s with no visible overshoot.
    static let surfaceSpring = Spring(mass: 1, stiffness: 340, damping: 32)
    /// Settles ≈0.69s with a 19% overshoot — celebrations only.
    static let popSpring = Spring(mass: 1, stiffness: 380, damping: 18)

    // MARK: Transitions

    /// Release after a press: buttons, toggles, chevrons.
    static var press: Animation { resolved(.spring(pressSpring)) }
    /// Sheets, toasts, layout changes, selections that swap content in place.
    static var surface: Animation { resolved(.spring(surfaceSpring)) }
    /// Count-ups, growing bars, rings and donuts filling.
    static var settle: Animation { resolved(.timingCurve(easeOutCurve, duration: 0.9)) }
    /// A success mark landing. Rare: confirmations only.
    static var pop: Animation { resolved(.spring(popSpring)) }
    /// Opacity only: scrims, exits, label swaps, the Reduce Motion stand-in.
    static let fade = Animation.linear(duration: 0.2)
    /// A line chart drawing its stroke.
    static var draw: Animation { resolved(.timingCurve(easeOutCurve, duration: 1.4)) }
    /// Already on screen and moving: the tab pill, period switches that reload.
    static var move: Animation { resolved(.timingCurve(easeInOutCurve, duration: 0.26)) }

    // MARK: Durations

    /// Press-down, colour, frequent tiny changes.
    static var fast: Animation { resolved(.timingCurve(easeOutCurve, duration: 0.15)) }
    /// Menus, accordions, form rows showing or hiding, quick exits.
    static var quick: Animation { resolved(.timingCurve(easeOutCurve, duration: 0.2)) }
    /// In-app entrances.
    static var base: Animation { resolved(.timingCurve(easeOutCurve, duration: 0.26)) }

    // MARK: Choreography

    /// Delay between choreographed siblings.
    static let stagger: Double = 0.06
    /// Siblings past this many arrive with the last one.
    static let maxStagger = 6

    /// The delay for the `index`th sibling, capped so long groups don't trail.
    static func staggered(_ index: Int) -> Double {
        Double(min(index, maxStagger - 1)) * stagger
    }

    // MARK: Reduce Motion

    static var reduceMotion: Bool {
        #if os(watchOS)
        WKAccessibilityIsReduceMotionEnabled()
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    private static func resolved(_ animation: Animation) -> Animation {
        reduceMotion ? fade : animation
    }
}

// MARK: - Blur swap

/// Content crossfades through a light blur with a hint of scale — used when
/// text or content swaps inside a container that stays put.
struct BlurSwap: Transition {
    var radius: CGFloat = 2
    var scale: CGFloat = 0.97

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : scale)
    }
}

extension View {
    /// Blur swap: arrives on the house ease-out, leaves on a quicker fade.
    func blurSwapTransition(radius: CGFloat = 2, scale: CGFloat = 0.97) -> some View {
        transition(
            AsymmetricTransition(
                insertion: BlurSwap(radius: radius, scale: scale).animation(FinMotion.quick),
                removal: BlurSwap(radius: radius, scale: scale).animation(FinMotion.fade)
            )
        )
    }

    /// One-time entrance: rises 12pt and fades in, `index` steps after its
    /// choreographed siblings (capped at six). Under Reduce Motion it only fades.
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
            .offset(y: isVisible || reduceMotion ? 0 : 12)
            .animation(FinMotion.base.delay(FinMotion.staggered(index)), value: isVisible)
    }
}

// MARK: - Pop

extension View {
    /// Pops the view from 0.6 on the `pop` spring when it appears and whenever
    /// `trigger` changes — the "landed" beat on success checks only.
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
                    SpringKeyframe(1.0, duration: 0.7, spring: FinMotion.popSpring)
                }
            }
            .onAppear { if !reduceMotion { pops += 1 } }
            .onChange(of: trigger) { if !reduceMotion { pops += 1 } }
    }
}

// MARK: - Pressable buttons

/// Scales the label down while pressed: quickly on touch-down, back up on the
/// `press` spring. The action's own haptic stays at the call site, so this
/// never double-fires feedback.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(configuration.isPressed ? FinMotion.fast : FinMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    /// Buttons and chips.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    /// Small icon buttons, which need a deeper press to read.
    static var pressableIcon: PressableButtonStyle { PressableButtonStyle(scale: 0.9) }
}

// MARK: - Liquid indicator

/// Springs the two edges of a sliding indicator separately: the edge in the
/// direction of travel leads on a quick spring and the trailing edge follows
/// on a slower one, so the indicator stretches toward its target and settles.
/// Unmerged, so rapid retargets add up rather than restart.
struct EdgeSpringAnimation: CustomAnimation {
    var lead = FinMotion.pressSpring
    var follow = FinMotion.surfaceSpring

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
