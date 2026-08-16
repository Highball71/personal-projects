//
//  SupabaseSettingsView.swift
//  FluffyList
//
//  "The Press" settings. Masthead with the household name as the
//  dateline, then plain label/value ruled rows — no grouped-inset
//  list, no chevrons, no icons. All controls and persistence are
//  unchanged from the shipped app.
//

import SwiftUI

struct SupabaseSettingsView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService

    // Persisted preferences
    @AppStorage("householdSize") private var householdSize: Int = 2
    @AppStorage("dietaryPreferences") private var dietaryPrefsRaw: String = ""
    @AppStorage("groceryStoreMode") private var storeMode = false
    @AppStorage("defaultServings") private var defaultServings: Int = 4
    @AppStorage("autoAddGroceries") private var autoAddGroceries = true
    @AppStorage("groupGroceriesByAisle") private var groupByAisle = true
    @AppStorage("mealPlanStartDay") private var startDay: String = "Sunday"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FluffyMasthead(
                        title: "Settings",
                        dateline: householdService.household?.name ?? "FLUFFYLIST BETA"
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)

                    if let name = currentMemberName {
                        Text("Signed in as \(name).")
                            .font(.custom(FluffyFace.italic, size: 15))
                            .foregroundStyle(Color.fluffySecondary)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 15)
                    }

                    settingsGroup("Household") {
                        if let household = householdService.household {
                            labelValueRow(
                                label: household.name,
                                value: "\(householdService.members.count) member\(householdService.members.count == 1 ? "" : "s")"
                            )
                        }
                        joinCodeRow
                        stepperRow(
                            label: "Household size",
                            value: $householdSize,
                            range: 1...12
                        )
                        pickerRow(
                            label: "Week starts",
                            selection: $startDay,
                            options: ["Sunday", "Monday", "Saturday"]
                        )
                    }

                    settingsGroup("Recipes") {
                        stepperRow(
                            label: "Default servings",
                            value: $defaultServings,
                            range: 1...20
                        )
                        toggleRow(
                            label: "Auto-add groceries",
                            detail: "When a recipe is planned",
                            isOn: $autoAddGroceries
                        )
                    }

                    settingsGroup("Shopping") {
                        toggleRow(
                            label: "Group by aisle",
                            detail: "Produce, Dairy, Pantry, etc.",
                            isOn: $groupByAisle
                        )
                        toggleRow(
                            label: "Store Mode",
                            detail: "Dark, large text for shopping",
                            isOn: $storeMode
                        )
                    }

                    settingsGroup("App") {
                        labelValueRow(label: "Version", value: appVersion)
                        signOutRow
                    }

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.fluffyBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
            .task {
                await householdService.loadMembers()
            }
        }
    }

    private var currentMemberName: String? {
        // The current user is identified by their Supabase auth ID
        guard let userID = SupabaseManager.shared.currentUserID else { return nil }
        return householdService.members.first { $0.userID == userID }?.displayName
    }

    // MARK: - Settings Group

    private func settingsGroup(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHead(title: title)
                .padding(.horizontal, 22)
                .padding(.top, 30)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            rule
        }
    }

    // MARK: - Row Types

    /// Plain label/value row: 17pt label left, 14pt secondary value
    /// right, 15pt vertical padding, hairline rule above.
    private func labelValueRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            rule
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.custom(FluffyFace.regular, size: 17))
                    .foregroundStyle(Color.fluffyPrimary)
                Spacer()
                Text(value)
                    .font(.custom(FluffyFace.regular, size: 14))
                    .foregroundStyle(Color.fluffySecondary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
        }
    }

    private func toggleRow(
        label: String,
        detail: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(spacing: 0) {
            rule
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.custom(FluffyFace.regular, size: 17))
                        .foregroundStyle(Color.fluffyPrimary)
                    if let detail {
                        Text(detail)
                            .font(.custom(FluffyFace.italic, size: 13))
                            .foregroundStyle(Color.fluffySecondary)
                    }
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color.fluffyAccent)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    private func stepperRow(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(spacing: 0) {
            rule
            HStack(spacing: 12) {
                Text(label)
                    .font(.custom(FluffyFace.regular, size: 17))
                    .foregroundStyle(Color.fluffyPrimary)
                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if value.wrappedValue > range.lowerBound {
                            value.wrappedValue -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(
                                value.wrappedValue > range.lowerBound
                                    ? Color.fluffyAccent
                                    : Color.fluffyBorder
                            )
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .disabled(value.wrappedValue <= range.lowerBound)

                    Text("\(value.wrappedValue)")
                        .font(.custom(FluffyFace.bold, size: 19))
                        .monospacedDigit()
                        .foregroundStyle(Color.fluffyPrimary)
                        .frame(minWidth: 24)
                        .contentTransition(.numericText())

                    Button {
                        if value.wrappedValue < range.upperBound {
                            value.wrappedValue += 1
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(
                                value.wrappedValue < range.upperBound
                                    ? Color.fluffyAccent
                                    : Color.fluffyBorder
                            )
                            .frame(minWidth: 28, minHeight: 28)
                    }
                    .disabled(value.wrappedValue >= range.upperBound)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
    }

    private func pickerRow(
        label: String,
        selection: Binding<String>,
        options: [String]
    ) -> some View {
        VStack(spacing: 0) {
            rule
            HStack(spacing: 12) {
                Text(label)
                    .font(.custom(FluffyFace.regular, size: 17))
                    .foregroundStyle(Color.fluffyPrimary)
                Spacer()
                Picker("", selection: selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .tint(Color.fluffyAccent)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Join Code Row

    private var joinCodeRow: some View {
        VStack(spacing: 0) {
            rule
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Join code")
                        .font(.custom(FluffyFace.regular, size: 17))
                        .foregroundStyle(Color.fluffyPrimary)
                    Text((householdService.household?.joinCode ?? "------").uppercased())
                        .font(.custom(FluffyFace.semibold, size: 15))
                        .fluffyTracking(0.10, at: 15)
                        .monospacedDigit()
                        .foregroundStyle(Color.fluffyAccent)
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = householdService.household?.joinCode ?? ""
                } label: {
                    Text("Copy")
                        .font(.fluffyButton)
                        .foregroundStyle(Color.fluffyAccent)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sign Out Row

    private var signOutRow: some View {
        VStack(spacing: 0) {
            rule
            Button {
                Task { await authService.signOut() }
            } label: {
                HStack {
                    Text("Sign out")
                        .font(.custom(FluffyFace.semibold, size: 17))
                        .foregroundStyle(Color.fluffyError)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Shared Helpers

    private var rule: some View {
        FluffyRule().padding(.horizontal, 22)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
