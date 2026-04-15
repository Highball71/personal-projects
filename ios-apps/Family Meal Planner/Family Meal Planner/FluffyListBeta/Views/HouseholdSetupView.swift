//
//  HouseholdSetupView.swift
//  FluffyList
//
//  Onboarding Step 1 of 3 — household size and dietary preferences.
//  Preferences are stored locally in UserDefaults so they survive
//  before a Supabase account exists. Heirloom design.
//

import SwiftUI

struct HouseholdSetupView: View {
    let onContinue: () -> Void

    @AppStorage("householdSize") private var householdSize: Int = 2
    @AppStorage("dietaryPreferences") private var dietaryPrefsRaw: String = ""

    /// The toggle state for each dietary option, derived from the
    /// persisted comma-separated string.
    @State private var selectedPrefs: Set<DietaryOption> = []
    @State private var didLoadPrefs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Step indicator
            stepIndicator
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text("Tell us about\nyour household")
                        .font(.fluffyDisplay)
                        .foregroundStyle(Color.fluffyPrimary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    // Household size
                    householdSizeSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)

                    // Dietary preferences
                    dietarySection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }

            // Bottom actions
            VStack(spacing: 12) {
                FluffyPrimaryButton("Continue", section: .recipes) {
                    savePreferences()
                    onContinue()
                }

                Button {
                    onContinue()
                } label: {
                    Text("Skip for now")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
        .onAppear { loadPreferences() }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            Text("Step 1")
                .font(.fluffySubheadline)
                .foregroundStyle(Color.fluffyAmber)
            Text("of 3")
                .font(.fluffySubheadline)
                .foregroundStyle(Color.fluffyTertiary)

            Spacer()

            // Progress dots
            HStack(spacing: 6) {
                Circle().fill(Color.fluffyAmber).frame(width: 8, height: 8)
                Circle().fill(Color.fluffyDivider).frame(width: 8, height: 8)
                Circle().fill(Color.fluffyDivider).frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Household Size

    private var householdSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FluffySectionHeader(title: "How many people?", section: .recipes)

            HStack(spacing: 24) {
                Button {
                    if householdSize > 1 { householdSize -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            householdSize > 1 ? Color.fluffyAmber : Color.fluffyDivider
                        )
                }
                .disabled(householdSize <= 1)

                Text("\(householdSize)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fluffyPrimary)
                    .frame(minWidth: 60)
                    .contentTransition(.numericText())

                Button {
                    if householdSize < 12 { householdSize += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            householdSize < 12 ? Color.fluffyAmber : Color.fluffyDivider
                        )
                }
                .disabled(householdSize >= 12)
            }
            .frame(maxWidth: .infinity)

            Text(householdSizeLabel)
                .font(.fluffyFootnote)
                .foregroundStyle(Color.fluffySecondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var householdSizeLabel: String {
        switch householdSize {
        case 1: return "Just me"
        case 2: return "A couple"
        case 3...4: return "Small family"
        case 5...6: return "Family"
        default: return "Big family!"
        }
    }

    // MARK: - Dietary Preferences

    private var dietarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FluffySectionHeader(title: "Any dietary preferences?", section: .recipes)

            Text("We'll use these to suggest recipes. You can change this later.")
                .font(.fluffyFootnote)
                .foregroundStyle(Color.fluffySecondary)

            // Chip grid — wrapping flow layout
            FlowLayout(spacing: 10) {
                ForEach(DietaryOption.allCases) { option in
                    dietaryChip(option)
                }
            }
        }
    }

    private func dietaryChip(_ option: DietaryOption) -> some View {
        let isSelected = selectedPrefs.contains(option)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selectedPrefs.remove(option)
                } else {
                    selectedPrefs.insert(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.fluffyCaption)
                Text(option.rawValue)
                    .font(.fluffySubheadline)
            }
            .foregroundStyle(isSelected ? .white : Color.fluffyPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.fluffyAmber : Color.fluffyCard,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : Color.fluffyBorder,
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Persistence

    private func loadPreferences() {
        guard !didLoadPrefs else { return }
        didLoadPrefs = true
        let saved = dietaryPrefsRaw
            .split(separator: ",")
            .compactMap { DietaryOption(rawValue: String($0)) }
        selectedPrefs = Set(saved)
    }

    private func savePreferences() {
        dietaryPrefsRaw = selectedPrefs
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}

// MARK: - Dietary Options

private enum DietaryOption: String, CaseIterable, Identifiable, Hashable {
    case vegetarian  = "Vegetarian"
    case vegan       = "Vegan"
    case glutenFree  = "Gluten-Free"
    case dairyFree   = "Dairy-Free"
    case nutFree     = "Nut-Free"
    case lowCarb     = "Low-Carb"
    case pescatarian = "Pescatarian"
    case halal       = "Halal"
    case kosher      = "Kosher"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .vegetarian:  "leaf"
        case .vegan:       "leaf.fill"
        case .glutenFree:  "slash.circle"
        case .dairyFree:   "drop.triangle"
        case .nutFree:     "exclamationmark.triangle"
        case .lowCarb:     "scalemass"
        case .pescatarian: "fish"
        case .halal:       "checkmark.seal"
        case .kosher:      "star.circle"
        }
    }
}

// MARK: - Flow Layout

/// A wrapping horizontal layout — chips flow to the next line
/// when the row fills up. Lightweight replacement for iOS 16 Layout.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i < rows.count - 1 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
