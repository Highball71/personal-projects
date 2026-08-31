//
//  HouseholdSetupView.swift
//  FluffyList
//
//  Onboarding — household size and dietary preferences, in "The
//  Press" dress: masthead with a step dateline, underlined-word
//  dietary chips, and a solid ink-1 Continue. Preferences are stored
//  locally in UserDefaults so they survive before a Supabase account
//  exists; once the user has a member row, HouseholdService's
//  dietary-prefs migration promotes them to that row's
//  dietary_preferences column and clears the local key (Phase 2).
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
            FluffyDietaryChips(selection: $selectedPrefs)
        }
    }

    // MARK: - Persistence

    private func loadPreferences() {
        guard !didLoadPrefs else { return }
        didLoadPrefs = true
        selectedPrefs = DietaryOption.set(fromCommaSeparated: dietaryPrefsRaw)
    }

    private func savePreferences() {
        dietaryPrefsRaw = selectedPrefs
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}

// DietaryOption moved to Models/DietaryOption.swift and the chip row
// to Design/FluffyDietaryChips.swift (shared with the People screen
// since per-person meals Phase 2); the flow layout was replaced by the
// shared FluffyFlowLayout in SupabaseRecipeListView.
