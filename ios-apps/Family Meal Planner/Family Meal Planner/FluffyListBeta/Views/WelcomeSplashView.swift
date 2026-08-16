//
//  WelcomeSplashView.swift
//  FluffyList
//
//  First-launch welcome. "The Press": masthead with a BETA dateline,
//  the "Dinner, decided." headline, an italic sub-paragraph, three
//  numbered value rows, and a solid ink block CTA.
//  Shown once, then never again; tapping the CTA advances to the
//  household setup step.
//

import SwiftUI

struct WelcomeSplashView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffyMasthead(title: "", dateline: "BETA")
                .padding(.horizontal, 22)

            Text("Dinner,\ndecided.")
                .font(.fluffyDisplayLarge)
                .fluffyTracking(-0.035, at: 52)
                .lineSpacing(-52 * 0.02)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.horizontal, 22)
                .padding(.top, 40)
                .padding(.bottom, 20)

            Text("Plan the week,\nshare the list,\ncook together.")
                .font(.custom(FluffyFace.italic, size: 19))
                .foregroundStyle(Color.fluffySecondary)
                .lineSpacing(4)
                .padding(.horizontal, 22)

            Spacer()

            FluffyValueRows()
                .padding(.horizontal, 22)
                .padding(.bottom, 30)

            FluffyFilledButton(
                title: "Get started",
                fill: .fluffyInkGround,
                textColor: .fluffyBackground
            ) {
                onGetStarted()
            }
            .padding(.horizontal, 22)

            Text("Free while in beta.")
                .font(.custom(FluffyFace.italic, size: 13))
                .foregroundStyle(Color.fluffySecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.fluffyBackground)
    }
}

// MARK: - Numbered Value Rows

/// The three numbered value rows shared by the welcome and sign-in
/// screens: a 13pt SemiBold ink-1 numeral in a 22pt column, 16pt
/// text, hairline rules between and a closing rule.
struct FluffyValueRows: View {
    private let rows: [(String, String)] = [
        ("01", "One shared plan for the whole household."),
        ("02", "The grocery list writes itself."),
        ("03", "Every recipe in one box, scanned or typed.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows, id: \.0) { row in
                VStack(spacing: 0) {
                    FluffyRule()
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(row.0)
                            .font(.custom(FluffyFace.semibold, size: 13))
                            .foregroundStyle(Color.fluffyAccent)
                            .frame(width: 22, alignment: .leading)
                        Text(row.1)
                            .font(.custom(FluffyFace.regular, size: 16))
                            .foregroundStyle(Color.fluffyPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                }
            }
            FluffyRule()
        }
    }
}
