//
//  StatusBarBackground.swift
//  FluffyList
//
//  Paints the strip behind the clock and battery. Screens that hide
//  their navigation bar (recipe detail) or whose bar draws no
//  background let content scroll up under the status bar, where the
//  time and battery sat on top of the masthead and week arrows
//  (device pass 2026-10-29).
//

import SwiftUI

extension View {
    /// Fill the top safe area (the status bar strip) with `color`, so
    /// content scrolling up disappears under it instead of colliding
    /// with the clock.
    func statusBarBackground(_ color: Color = .fluffyBackground) -> some View {
        // A zero-height inset at the top of the safe area whose
        // background ignores the top safe area: it paints exactly the
        // status bar strip and takes no layout space. (An overlay with
        // ignoresSafeArea did not reach the strip — checked with
        // simulator screenshots, 2026-10-30.)
        safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .background(color.ignoresSafeArea(edges: .top))
                .accessibilityHidden(true)
        }
    }
}
