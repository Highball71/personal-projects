//
//  PeopleView.swift
//  FluffyList
//
//  Per-person meals Phase 2 — the People screen (Settings → People).
//  Everyone you plan meals for, whether or not they have an account:
//  account members joined via Apple ID, "profile members" (user_id
//  NULL) added right here for kids and guests. Ruled rows, names in
//  Source Serif, dietary preferences as the underlined-word chips —
//  no join-code machinery for profile members.
//
//  Editing follows RLS reality: you can edit yourself and profile
//  members; other account members' rows belong to them.
//

import SwiftUI

struct PeopleView: View {
    @EnvironmentObject private var householdService: HouseholdService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FluffyMasthead(
                    title: "People",
                    dateline: householdService.household?.name ?? "THE HOUSEHOLD"
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

                Text("Everyone you cook for. Dietary preferences live with the person, and nobody needs their own account.")
                    .font(.custom(FluffyFace.italic, size: 15))
                    .foregroundStyle(Color.fluffySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 25)

                if householdService.isLoadingMembers && householdService.members.isEmpty {
                    Text("Loading\u{2026}")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                        .padding(.horizontal, 22)
                } else {
                    memberRows
                }

                NavigationLink {
                    AddPersonView()
                } label: {
                    // Same dress as FluffyTextLink, but as a link label.
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add a person \u{2192}")
                            .font(.fluffyButton)
                            .foregroundStyle(Color.fluffyAccent)
                        FluffyRule(weight: 2, color: .fluffyAccent)
                    }
                    .fixedSize()
                }
                .buttonStyle(FluffyPressDarkenStyle())
                .padding(.horizontal, 22)
                .padding(.top, 30)

                if let error = householdService.errorMessage {
                    Text(error)
                        .font(.custom(FluffyFace.regular, size: 13))
                        .foregroundStyle(Color.fluffyError)
                        .padding(.horizontal, 22)
                        .padding(.top, 15)
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

    // MARK: - Member Rows

    /// Head cook first, then the other account members, then profile
    /// members — alphabetical within each group.
    private var sortedMembers: [HouseholdMemberRow] {
        householdService.members.sorted { a, b in
            if a.isHeadCook != b.isHeadCook { return a.isHeadCook }
            if a.isProfileMember != b.isProfileMember { return b.isProfileMember }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private var memberRows: some View {
        VStack(spacing: 0) {
            ForEach(sortedMembers) { member in
                NavigationLink {
                    PersonDetailView(member: member)
                } label: {
                    memberRow(member)
                }
                .buttonStyle(.plain)
            }
            FluffyRule().padding(.horizontal, 22)
        }
    }

    private func memberRow(_ member: HouseholdMemberRow) -> some View {
        VStack(spacing: 0) {
            FluffyRule().padding(.horizontal, 22)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName.isEmpty ? "Unnamed" : member.displayName)
                        .font(.custom(FluffyFace.regular, size: 17))
                        .foregroundStyle(Color.fluffyPrimary)
                    if member.dietaryPreferences.isEmpty {
                        Text("No dietary preferences")
                            .font(.custom(FluffyFace.italic, size: 13))
                            .foregroundStyle(Color.fluffyTertiary)
                    } else {
                        FluffyMetadataLine(
                            text: member.dietaryPreferences.joined(separator: " \u{00B7} ")
                        )
                    }
                }
                Spacer()
                if member.isHeadCook {
                    FluffyMetadataLine(text: "HEAD COOK", color: .fluffyAccent)
                } else if member.isProfileMember {
                    FluffyMetadataLine(text: "PROFILE")
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Person Detail (edit)

struct PersonDetailView: View {
    let member: HouseholdMemberRow

    @EnvironmentObject private var householdService: HouseholdService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedPrefs: Set<DietaryOption>
    @State private var isSaving = false
    @State private var confirmingRemoval = false

    init(member: HouseholdMemberRow) {
        self.member = member
        _name = State(initialValue: member.displayName)
        _selectedPrefs = State(initialValue: DietaryOption.set(fromRawValues: member.dietaryPreferences))
    }

    /// You can edit yourself and profile members. Another account
    /// member's row belongs to them (and RLS enforces it).
    private var canEdit: Bool {
        member.isProfileMember
            || member.userID == SupabaseManager.shared.currentUserID
    }

    private var hasChanges: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines) != member.displayName
            || selectedPrefs != DietaryOption.set(fromRawValues: member.dietaryPreferences)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FluffyMasthead(
                    title: member.displayName.isEmpty ? "Person" : member.displayName,
                    dateline: member.isProfileMember ? "PROFILE" : (member.isHeadCook ? "HEAD COOK" : "MEMBER")
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 25)

                if canEdit {
                    inkRuleField(
                        label: "Name",
                        placeholder: "e.g. Maya",
                        text: $name
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                } else {
                    Text("Only \(member.displayName.isEmpty ? "they" : member.displayName) can edit their own name and preferences, from their own device.")
                        .font(.custom(FluffyFace.italic, size: 15))
                        .foregroundStyle(Color.fluffySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 30)
                }

                VStack(alignment: .leading, spacing: 14) {
                    FluffySectionHead(title: "Dietary preferences")
                    FluffyDietaryChips(selection: $selectedPrefs, isEnabled: canEdit)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)

                if canEdit {
                    FluffyFilledButton(title: isSaving ? "Saving\u{2026}" : "Save changes") {
                        save()
                    }
                    .disabled(!hasChanges || isSaving)
                    .opacity(hasChanges && !isSaving ? 1 : 0.5)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                }

                if member.isProfileMember {
                    removeSection
                        .padding(.horizontal, 22)
                }

                if let error = householdService.errorMessage {
                    Text(error)
                        .font(.custom(FluffyFace.regular, size: 13))
                        .foregroundStyle(Color.fluffyError)
                        .padding(.horizontal, 22)
                        .padding(.top, 15)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.fluffyBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
        .confirmationDialog(
            "Remove \(member.displayName) from the household?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove \(member.displayName)", role: .destructive) {
                remove()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Meals assigned to \(member.displayName) go back to the whole household. This can't be undone.")
        }
    }

    private var removeSection: some View {
        Button {
            confirmingRemoval = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Remove from household")
                    .font(.fluffyButton)
                    .foregroundStyle(Color.fluffyError)
                FluffyRule(weight: 2, color: .fluffyError)
            }
            .fixedSize()
        }
        .buttonStyle(FluffyPressDarkenStyle())
    }

    private func save() {
        isSaving = true
        Task {
            let saved = await householdService.updateMember(
                member.id,
                displayName: name,
                dietaryPreferences: DietaryOption.rawValues(from: selectedPrefs)
            )
            isSaving = false
            if saved { dismiss() }
        }
    }

    private func remove() {
        isSaving = true
        Task {
            let removed = await householdService.deleteProfileMember(member.id)
            isSaving = false
            if removed { dismiss() }
        }
    }

    /// Same ink-rule field as HouseholdOnboardingView: uppercase label
    /// over a value on a 2px solid ink rule.
    private func inkRuleField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FluffySectionHead(title: label)
            VStack(spacing: 7) {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.custom(FluffyFace.regular, size: 22))
                            .foregroundStyle(Color.fluffyTertiary)
                    }
                    TextField("", text: text)
                        .font(.custom(FluffyFace.semibold, size: 22))
                        .foregroundStyle(Color.fluffyPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                FluffyRule(weight: 2, color: .fluffyPrimary)
            }
        }
    }
}

// MARK: - Add Person

struct AddPersonView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedPrefs: Set<DietaryOption> = []
    @State private var isAdding = false

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAdding
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FluffyMasthead(title: "Add a person", dateline: "PROFILE")
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)

                Text("For kids and guests — anyone you cook for who doesn't need their own account. They can get one later by joining with the household code.")
                    .font(.custom(FluffyFace.italic, size: 15))
                    .foregroundStyle(Color.fluffySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 10) {
                    FluffySectionHead(title: "Name")
                    VStack(spacing: 7) {
                        ZStack(alignment: .leading) {
                            if name.isEmpty {
                                Text("e.g. Maya")
                                    .font(.custom(FluffyFace.regular, size: 22))
                                    .foregroundStyle(Color.fluffyTertiary)
                            }
                            TextField("", text: $name)
                                .font(.custom(FluffyFace.semibold, size: 22))
                                .foregroundStyle(Color.fluffyPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        FluffyRule(weight: 2, color: .fluffyPrimary)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)

                VStack(alignment: .leading, spacing: 14) {
                    FluffySectionHead(title: "Dietary preferences")
                    FluffyDietaryChips(selection: $selectedPrefs)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 40)

                FluffyFilledButton(title: isAdding ? "Adding\u{2026}" : "Add to the household") {
                    add()
                }
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.5)
                .padding(.horizontal, 22)

                if let error = householdService.errorMessage {
                    Text(error)
                        .font(.custom(FluffyFace.regular, size: 13))
                        .foregroundStyle(Color.fluffyError)
                        .padding(.horizontal, 22)
                        .padding(.top, 15)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.fluffyBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
    }

    private func add() {
        isAdding = true
        Task {
            let added = await householdService.createProfileMember(
                name: name,
                dietaryPreferences: DietaryOption.rawValues(from: selectedPrefs)
            )
            isAdding = false
            if added { dismiss() }
        }
    }
}
