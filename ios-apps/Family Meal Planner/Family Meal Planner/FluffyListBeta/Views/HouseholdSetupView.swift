//
//  HouseholdSetupView.swift
//  FluffyList
//
//  Onboarding — household size and dietary preferences, in "The
//  Press" dress: masthead with a step dateline, underlined-word
//  dietary chips, and a solid ink-1 Continue. Preferences are stored
//  locally in UserDefaults so they survive before a Supabase account
//  exists.
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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FluffyMasthead(title: "", dateline: "STEP 1 OF 2")
                        .padding(.horizontal, 22)

                    Text("Tell us about\nyour household.")
                        .font(.fluffyDisplay)
                        .fluffyTracking(-0.025, at: 38)
                        .foregroundStyle(Color.fluffyPrimary)
                        .padding(.horizontal, 22)
                        .padding(.top, 30)
                        .padding(.bottom, 12)

                    Text("We use this to size recipes and lists. You can change it later.")
                        .font(.custom(FluffyFace.italic, size: 16))
                        .foregroundStyle(Color.fluffySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 30)

                    // Household size
                    householdSizeSection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 30)

                    // Dietary preferences
                    dietarySection
                        .padding(.horizontal, 22)
                        .padding(.bottom, 40)
                }
            }

            // Bottom actions
            VStack(spacing: 12) {
                FluffyFilledButton(title: "Continue") {
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
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
        .onAppear { loadPreferences() }
    }

    // MARK: - Household Size

    private var householdSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FluffySectionHead(title: "How many people?")

            HStack(spacing: 30) {
                Button {
                    if householdSize > 1 { householdSize -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(
                            householdSize > 1 ? Color.fluffyAccent : Color.fluffyBorder
                        )
                        .frame(minWidth: 34, minHeight: 34)
                }
                .disabled(householdSize <= 1)

                Text("\(householdSize)")
                    .font(.custom(FluffyFace.bold, size: 48))
                    .fluffyTracking(-0.03, at: 48)
                    .monospacedDigit()
                    .foregroundStyle(Color.fluffyPrimary)
                    .frame(minWidth: 60)
                    .contentTransition(.numericText())

                Button {
                    if householdSize < 12 { householdSize += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(
                            householdSize < 12 ? Color.fluffyAccent : Color.fluffyBorder
                        )
                        .frame(minWidth: 34, minHeight: 34)
                }
                .disabled(householdSize >= 12)
            }
            .frame(maxWidth: .infinity)

            Text(householdSizeLabel)
                .font(.custom(FluffyFace.italic, size: 14))
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
        VStack(alignment: .leading, spacing: 14) {
            FluffySectionHead(title: "Any dietary preferences?")

            Text("We'll use these to suggest recipes. You can change this later.")
                .font(.custom(FluffyFace.italic, size: 13))
                .foregroundStyle(Color.fluffySecondary)

            // Underlined-word chips — not capsules. Multi-select:
            // chosen words take ink 1 and a 2px underline.
            FlowLayout(spacing: 18) {
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
