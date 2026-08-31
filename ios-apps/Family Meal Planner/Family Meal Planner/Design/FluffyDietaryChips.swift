//
//  FluffyDietaryChips.swift
//  FluffyList
//
//  "The Press" dietary chips — underlined words, not capsules.
//  Extracted from HouseholdSetupView for per-person meals Phase 2 so
//  onboarding and the People screen share one chip row and one flow
//  layout.
//

import SwiftUI

// MARK: - Dietary Chip Row

/// Multi-select underlined-word chips for dietary preferences.
/// Chosen words take ink 1 (persimmon) and a 2px underline. Pass
/// isEnabled: false for a read-only rendering (another account
/// member's preferences — only they can edit their own row).
struct FluffyDietaryChips: View {
    @Binding var selection: Set<DietaryOption>
    var isEnabled: Bool = true

    var body: some View {
        // FluffyFlowLayout lives in SupabaseRecipeListView (the
        // category chips use it too); defaults are hSpacing 18.
        FluffyFlowLayout(vSpacing: 18) {
            ForEach(DietaryOption.allCases) { option in
                chip(option)
            }
        }
    }

    private func chip(_ option: DietaryOption) -> some View {
        let isSelected = selection.contains(option)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selection.remove(option)
                } else {
                    selection.insert(option)
                }
            }
        } label: {
            VStack(spacing: 3) {
                Text(option.rawValue.uppercased())
                    .font(.custom(FluffyFace.regular, size: 14))
                    .fluffyTracking(0.06, at: 14)
                    .foregroundStyle(
                        isSelected ? Color.fluffyAccent : Color.fluffySecondary
                    )
                FluffyRule(
                    weight: 2,
                    color: isSelected ? .fluffyAccent : .clear
                )
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled || isSelected ? 1 : 0.45)
    }
}
