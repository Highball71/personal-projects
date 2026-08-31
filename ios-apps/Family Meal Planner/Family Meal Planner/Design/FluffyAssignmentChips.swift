//
//  FluffyAssignmentChips.swift
//  FluffyList
//
//  "The Press" assignment chips — the single-select row of
//  underlined small-caps words (EVERYONE · MAYA · SAM) that decides
//  who a meal is for. Sits above the confirm in the recipe picker and
//  the day picker; one tap, no new sheet. Same visual grammar as
//  FluffyDietaryChips: chosen word takes ink 1 and a 2px underline.
//

import SwiftUI

/// Single-select chip row for meal assignment. `selection` nil =
/// EVERYONE — the household meal, the default.
struct FluffyAssignmentChips: View {
    let members: [HouseholdMemberRow]
    @Binding var selection: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                chip(title: "Everyone", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(members) { member in
                    chip(
                        title: member.displayName,
                        isSelected: selection == member.id
                    ) {
                        selection = member.id
                    }
                }
            }
        }
    }

    private func chip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            VStack(spacing: 3) {
                Text(title.uppercased())
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
    }
}
