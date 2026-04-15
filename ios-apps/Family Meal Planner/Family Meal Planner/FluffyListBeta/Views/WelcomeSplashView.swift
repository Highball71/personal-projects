//
//  WelcomeSplashView.swift
//  FluffyList
//
//  First-launch welcome screen. Shown once, then never again.
//  Tapping "Get Started" advances to the household setup step.
//  Heirloom design: Playfair Display title, amber accent, warm bg.
//

import SwiftUI

struct WelcomeSplashView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration area
            ZStack {
                Circle()
                    .fill(Color.fluffyAmberLight)
                    .frame(width: 160, height: 160)
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.fluffyAmber)
            }
            .padding(.bottom, 32)

            // Title
            Text("FluffyList")
                .font(.fluffyDisplayLarge)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 12)

            // Subtitle
            Text("Meal planning for\nyour whole household")
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            // Three section color dots
            HStack(spacing: 8) {
                Circle().fill(Color.fluffyAmber).frame(width: 8, height: 8)
                Circle().fill(Color.fluffyTeal).frame(width: 8, height: 8)
                Circle().fill(Color.fluffySlateBlue).frame(width: 8, height: 8)
            }

            Spacer()

            // CTA
            FluffyPrimaryButton("Get Started", section: .recipes) {
                onGetStarted()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}
