//
//  FluffyFont.swift
//  FluffyList
//
//  Shared typography components that use the Heirloom design tokens.
//  These are reusable building blocks for any screen.
//

import SwiftUI

// MARK: - Section Header

/// Uppercase, tracked section label in the section's accent colour.
/// Example: amber "INGREDIENTS" or teal "THIS WEEK".
struct FluffySectionHeader: View {
    let title: String
    var section: FluffySection = .recipes

    var body: some View {
        Text(title)
            .font(.fluffySubheadline)
            .foregroundStyle(section.accent)
            .textCase(.uppercase)
            .tracking(1.2)
    }
}

// MARK: - Bullet Row

/// A single bullet-point row with a coloured dot.
/// Used in ingredient lists and anywhere a clean bullet is needed.
struct FluffyBulletRow: View {
    let text: String
    var dotColor: Color = .fluffyAmber

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                // Nudge down to sit on the text baseline
                .offset(y: 1)
            Text(text)
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffyPrimary)
        }
    }
}

// MARK: - Primary Button

/// Full-width filled button in the section's accent colour.
/// Used for primary actions like "Add to This Week".
struct FluffyPrimaryButton: View {
    let title: String
    let icon: String?
    var section: FluffySection = .recipes
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: FluffySection = .recipes,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.section = section
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.fluffyButton)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(section.accent, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Metadata Chip

/// Small pill showing an icon + value (e.g. clock icon + "30 min").
/// Used for recipe metadata like servings, cook time, category.
struct FluffyMetadataChip: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.fluffyCaption)
            Text(value)
                .font(.fluffyFootnote)
        }
        .foregroundStyle(Color.fluffySecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.fluffyDivider, in: Capsule())
    }
}
