//
//  SupabaseSettingsView.swift
//  FluffyList
//
//  Settings tab — Figma design with initials avatar, grouped
//  sections for Household, Recipes, Shopping, and App, with
//  toggle rows and navigation rows. Heirloom design.
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
                VStack(spacing: 24) {
                    profileHeader
                        .padding(.top, 8)

                    settingsGroup("Household") {
                        if let household = householdService.household {
                            navRow(
                                icon: "house",
                                label: household.name,
                                detail: "\(householdService.members.count) member\(householdService.members.count == 1 ? "" : "s")"
                            )
                        }
                        joinCodeRow
                        stepperRow(
                            icon: "person.2",
                            label: "Household Size",
                            value: $householdSize,
                            range: 1...12
                        )
                        pickerRow(
                            icon: "calendar",
                            label: "Week Starts",
                            selection: $startDay,
                            options: ["Sunday", "Monday", "Saturday"]
                        )
                    }

                    settingsGroup("Recipes") {
                        stepperRow(
                            icon: "fork.knife",
                            label: "Default Servings",
                            value: $defaultServings,
                            range: 1...20
                        )
                        toggleRow(
                            icon: "cart.badge.plus",
                            label: "Auto-Add Groceries",
                            detail: "When a recipe is planned",
                            isOn: $autoAddGroceries
                        )
                    }

                    settingsGroup("Shopping") {
                        toggleRow(
                            icon: "list.bullet",
                            label: "Group by Aisle",
                            detail: "Produce, Dairy, Pantry, etc.",
                            isOn: $groupByAisle
                        )
                        toggleRow(
                            icon: "flashlight.on.fill",
                            label: "Store Mode",
                            detail: "Dark, large text for shopping",
                            isOn: $storeMode
                        )
                    }

                    settingsGroup("App") {
                        navRow(
                            icon: "info.circle",
                            label: "Version",
                            detail: appVersion
                        )
                        signOutRow
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.fluffyBackground)
            .navigationTitle("Settings")
            .task {
                await householdService.loadMembers()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Initials avatar
            ZStack {
                Circle()
                    .fill(Color.fluffyAmber)
                    .frame(width: 72, height: 72)
                Text(initials)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Display name
            if let name = currentMemberName {
                Text(name)
                    .font(.fluffyTitle)
                    .foregroundStyle(Color.fluffyPrimary)
            }

            // Household name
            if let household = householdService.household {
                Text(household.name)
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffySecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var currentMemberName: String? {
        // The current user is identified by their Supabase auth ID
        guard let userID = SupabaseManager.shared.currentUserID else { return nil }
        return householdService.members.first { $0.userID == userID }?.displayName
    }

    private var initials: String {
        guard let name = currentMemberName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Settings Group

    private func settingsGroup(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffySecondary)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Row Types

    private func navRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            Text(label)
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffyPrimary)
            Spacer()
            Text(detail)
                .font(.fluffyFootnote)
                .foregroundStyle(Color.fluffyTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func toggleRow(
        icon: String,
        label: String,
        detail: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyPrimary)
                if let detail {
                    Text(detail)
                        .font(.fluffyCaption)
                        .foregroundStyle(Color.fluffyTertiary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.fluffyAmber)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func stepperRow(
        icon: String,
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            Text(label)
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffyPrimary)
            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            value.wrappedValue > range.lowerBound
                                ? Color.fluffyAmber
                                : Color.fluffyDivider
                        )
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
                    .frame(minWidth: 24)
                    .contentTransition(.numericText())

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            value.wrappedValue < range.upperBound
                                ? Color.fluffyAmber
                                : Color.fluffyDivider
                        )
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { rowDivider }
    }

    private func pickerRow(
        icon: String,
        label: String,
        selection: Binding<String>,
        options: [String]
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            Text(label)
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffyPrimary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .tint(Color.fluffyAmber)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { rowDivider }
    }

    // MARK: - Join Code Row

    private var joinCodeRow: some View {
        HStack(spacing: 12) {
            settingsIcon("link")
            VStack(alignment: .leading, spacing: 2) {
                Text("Join Code")
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyPrimary)
                Text((householdService.household?.joinCode ?? "------").uppercased())
                    .font(.system(.callout, design: .monospaced, weight: .bold))
                    .foregroundStyle(Color.fluffyAmber)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = householdService.household?.joinCode ?? ""
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fluffySecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { rowDivider }
    }

    // MARK: - Sign Out Row

    private var signOutRow: some View {
        Button {
            Task { await authService.signOut() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.fluffyError.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: "arrow.right.square")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.fluffyError)
                }
                Text("Sign Out")
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyError)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }

    // MARK: - Shared Helpers

    private func settingsIcon(_ name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.fluffyAmber.opacity(0.12))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .font(.system(size: 14))
                .foregroundStyle(Color.fluffyAmber)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.fluffyDivider)
            .frame(height: 1)
            .padding(.leading, 58)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
