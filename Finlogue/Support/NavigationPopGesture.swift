//
//  NavigationPopGesture.swift
//  Finlogue
//
//  The app hides system navigation bars in favor of custom headers, which
//  normally disables the interactive edge-swipe back gesture. Re-attach the
//  gesture's delegate so swiping back works everywhere, and only when
//  there's actually somewhere to pop back to.
//

import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
