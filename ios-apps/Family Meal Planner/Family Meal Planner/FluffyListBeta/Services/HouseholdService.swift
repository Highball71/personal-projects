//
//  HouseholdService.swift
//  FluffyList
//
//  Create or join a household using a 6-character join code.
//  Replaces CloudKitSharingService for household sharing.
//

import Combine
import Foundation
import Supabase

@MainActor
final class HouseholdService: ObservableObject {
    @Published var household: HouseholdRow?
    @Published var members: [HouseholdMemberRow] = []
    @Published var isLoading = false
    @Published var isLoadingMembers = false
    @Published var membersLoaded = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Create Household

    /// Create a new household. The current user becomes head cook.
    func createHousehold(name: String, memberDisplayName: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            // Confirm we have a live authenticated session before any writes.
            let session = try await supabase.auth.session
            let userID = session.user.id
            print("🟢 [HouseholdService] Authenticated Supabase user: \(userID)")
            print("🟢 [HouseholdService] Access token present: \(!session.accessToken.isEmpty)")

            // Defensive preflight: a returning user may already own/belong to
            // a household even if root routing landed on onboarding.
            if let existingHousehold = try await loadExistingHousehold(for: userID) {
                household = existingHousehold
                SupabaseManager.shared.setCurrentHousehold(existingHousehold.id)
                await loadMembers()
                isLoading = false
                return true
            }

            // ── DEBUG: households INSERT ──
            let householdPayload = HouseholdInsert(name: name, ownerID: userID)
            print("🟡 [HouseholdService] INSERT households payload: name=\(householdPayload.name), owner_id=\(householdPayload.ownerID)")

            let rows: [HouseholdRow] = try await supabase
                .from("households")
                .insert(householdPayload)
                .select()
                .execute()
                .value

            print("🟢 [HouseholdService] households INSERT succeeded, got \(rows.count) row(s)")

            guard let newHousehold = rows.first else {
                errorMessage = "Household was not created."
                isLoading = false
                return false
            }

            print("🟢 [HouseholdService] household id=\(newHousehold.id), join_code=\(newHousehold.joinCode)")

            // ── DEBUG: household_members INSERT ──
            let memberPayload = HouseholdMemberInsert(
                householdID: newHousehold.id,
                userID: userID,
                displayName: memberDisplayName,
                isHeadCook: true
            )
            print("🟡 [HouseholdService] INSERT household_members payload: household_id=\(memberPayload.householdID), user_id=\(memberPayload.userID?.uuidString ?? "NULL"), display_name=\(memberPayload.displayName), is_head_cook=\(memberPayload.isHeadCook)")

            try await supabase
                .from("household_members")
                .insert(memberPayload)
                .execute()

            print("🟢 [HouseholdService] household_members INSERT succeeded")

            household = newHousehold
            SupabaseManager.shared.setCurrentHousehold(newHousehold.id)
            await loadMembers()

            isLoading = false
            return true
        } catch {
            print("🔴 [HouseholdService] ERROR: \(error)")
            if isUniqueViolation(error),
               let session = try? await supabase.auth.session,
               let existingHousehold = try? await loadExistingHousehold(for: session.user.id) {
                household = existingHousehold
                SupabaseManager.shared.setCurrentHousehold(existingHousehold.id)
                await loadMembers()
                isLoading = false
                return true
            }

            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Join Household by Code

    /// Join an existing household using a 6-character code.
    ///
    /// Clients can no longer SELECT `households` by `join_code` (locked down
    /// by RLS), so the code is resolved server-side by the
    /// `join_household_by_code` RPC, which returns the household id or raises
    /// `invalid_join_code`. We then self-insert into `household_members`
    /// (still permitted by RLS) and read the household back as a member.
    func joinHousehold(code: String, memberDisplayName: String) async -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard trimmedCode.count == 6 else {
            errorMessage = "Join code must be 6 characters."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // Confirm we have a live authenticated session before any writes.
            let session = try await supabase.auth.session
            let userID = session.user.id

            // Resolve the join code server-side.
            let householdID: UUID = try await supabase
                .rpc("join_household_by_code", params: ["p_code": trimmedCode])
                .execute()
                .value

            // Add ourselves as a member — membership is what unlocks the
            // rest of this household's data for the user.
            let memberPayload = HouseholdMemberInsert(
                householdID: householdID,
                userID: userID,
                displayName: memberDisplayName,
                isHeadCook: false
            )
            try await supabase
                .from("household_members")
                .insert(memberPayload)
                .execute()

            // Now that we're a member, RLS lets us read the household row.
            household = try await loadHousehold(id: householdID)
            SupabaseManager.shared.setCurrentHousehold(householdID)
            await loadMembers()

            isLoading = false
            return true
        } catch {
            print("🔴 [HouseholdService] joinHousehold ERROR: \(error)")

            if "\(error)".contains("invalid_join_code") {
                errorMessage = "No household found with that code."
            } else if isUniqueViolation(error),
                      let session = try? await supabase.auth.session,
                      let existing = try? await loadExistingHousehold(for: session.user.id) {
                // Already a member of this household — treat as success.
                household = existing
                SupabaseManager.shared.setCurrentHousehold(existing.id)
                await loadMembers()
                isLoading = false
                return true
            } else {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            return false
        }
    }

    // MARK: - Load

    /// Load the current user's household and its members.
    func loadCurrentHousehold() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return }

        do {
            let rows: [HouseholdRow] = try await supabase
                .from("households")
                .select()
                .eq("id", value: householdID.uuidString)
                .limit(1)
                .execute()
                .value

            household = rows.first
            await loadMembers()
            // Phase 2: promote any device-local dietary prefs onto the
            // signed-in user's member row. Runs here because every path
            // into the app (launch, create, join) lands on
            // SupabaseContentView, whose .task calls this method.
            await migrateLocalDietaryPreferencesIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Load all members of the current household.
    func loadMembers() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            print("🟡 [HouseholdService] loadMembers: no currentHouseholdID — skipping")
            membersLoaded = true
            return
        }

        isLoadingMembers = true
        print("🟡 [HouseholdService] loadMembers: querying household_members for household_id=\(householdID.uuidString)")

        do {
            let loaded: [HouseholdMemberRow] = try await supabase
                .from("household_members")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .execute()
                .value

            print("🟢 [HouseholdService] loadMembers: got \(loaded.count) row(s)")
            for m in loaded {
                print("   • member: user_id=\(m.userID?.uuidString ?? "NULL (profile)"), display_name=\(m.displayName), is_head_cook=\(m.isHeadCook)")
            }
            members = loaded
            membersLoaded = true
            isLoadingMembers = false
        } catch {
            print("🔴 [HouseholdService] loadMembers ERROR: \(error)")
            errorMessage = "Failed to load members: \(error.localizedDescription)"
            membersLoaded = true
            isLoadingMembers = false
        }
    }

    // MARK: - Profile Members (per-person meals, Phase 2)

    /// Create a "profile member" — a household member without an
    /// account (user_id NULL, migration 013). Kids, guests: people you
    /// plan meals for who never sign in. Any member can create one.
    func createProfileMember(name: String, dietaryPreferences: [String]) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Give this person a name."
            return false
        }
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            errorMessage = "No household selected."
            return false
        }

        errorMessage = nil
        do {
            let payload = HouseholdMemberInsert(
                householdID: householdID,
                userID: nil,
                displayName: trimmed,
                isHeadCook: false,
                dietaryPreferences: dietaryPreferences
            )
            // .select() so RLS silently inserting nothing can't be
            // mistaken for success.
            let rows: [HouseholdMemberRow] = try await supabase
                .from("household_members")
                .insert(payload)
                .select()
                .execute()
                .value

            guard rows.first != nil else {
                errorMessage = "\(trimmed) couldn't be added."
                return false
            }
            await loadMembers()
            return true
        } catch {
            print("🔴 [HouseholdService] createProfileMember ERROR: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Update a member's name and dietary preferences. RLS permits
    /// this only for the signed-in user's own row and (with the
    /// profile-member policies) for profile members — the UI offers
    /// editing only in those cases.
    func updateMember(
        _ memberID: UUID,
        displayName: String,
        dietaryPreferences: [String]
    ) async -> Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "A person needs a name."
            return false
        }

        errorMessage = nil
        struct MemberUpdate: Encodable {
            let displayName: String
            let dietaryPreferences: [String]

            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case dietaryPreferences = "dietary_preferences"
            }
        }

        do {
            // .select() to verify the row was actually updated — under
            // RLS an unpermitted UPDATE succeeds with zero rows.
            let updated: [HouseholdMemberRow] = try await supabase
                .from("household_members")
                .update(MemberUpdate(displayName: trimmed, dietaryPreferences: dietaryPreferences))
                .eq("id", value: memberID.uuidString)
                .select()
                .execute()
                .value

            guard !updated.isEmpty else {
                errorMessage = "This person couldn't be updated."
                return false
            }
            await loadMembers()
            return true
        } catch {
            print("🔴 [HouseholdService] updateMember ERROR: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Remove a profile member from the household. Account members are
    /// never deletable here — RLS only lets a user delete their own
    /// membership, so they leave from their own device. The DB's
    /// BEFORE DELETE trigger (migration 013) detaches any meals
    /// assigned to the member instead of orphaning them.
    func deleteProfileMember(_ memberID: UUID) async -> Bool {
        guard let member = members.first(where: { $0.id == memberID }) else {
            errorMessage = "This person is no longer in the household."
            return false
        }
        guard member.isProfileMember else {
            errorMessage = "\(member.displayName) has an account and can only leave from their own device."
            return false
        }

        errorMessage = nil
        do {
            // .select() to verify the delete — an RLS-blocked DELETE
            // "succeeds" having removed zero rows.
            let deleted: [HouseholdMemberRow] = try await supabase
                .from("household_members")
                .delete()
                .eq("id", value: memberID.uuidString)
                .select()
                .execute()
                .value

            guard !deleted.isEmpty else {
                errorMessage = "\(member.displayName) couldn't be removed."
                await loadMembers()
                return false
            }
            await loadMembers()
            return true
        } catch {
            print("🔴 [HouseholdService] deleteProfileMember ERROR: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Dietary Prefs Migration (Phase 2)

    /// The pre-Phase-2 device-local dietary preferences key. Onboarding
    /// still writes it (there is no account yet at that step); this
    /// migration promotes it to the member row and clears it.
    static let legacyDietaryPrefsKey = "dietaryPreferences"

    /// One-time promotion of @AppStorage("dietaryPreferences") to the
    /// signed-in user's member row (dietary_preferences, migration 013).
    /// Rules: only when the local key is non-empty; if the member row
    /// already has preferences, the server wins and the local copy is
    /// discarded; on network failure the key is kept so a later launch
    /// retries. Nothing reads the key after Phase 2.
    func migrateLocalDietaryPreferencesIfNeeded() async {
        let defaults = UserDefaults.standard
        let raw = defaults.string(forKey: Self.legacyDietaryPrefsKey) ?? ""
        guard !raw.isEmpty else { return }

        guard let userID = SupabaseManager.shared.currentUserID,
              let mine = members.first(where: { $0.userID == userID }) else {
            // Not signed in or member row not loaded — retry next launch.
            return
        }

        guard mine.dietaryPreferences.isEmpty else {
            // The row was already populated (another device, or an
            // earlier migration) — the server wins.
            defaults.removeObject(forKey: Self.legacyDietaryPrefsKey)
            return
        }

        let prefs = DietaryOption.rawValues(
            from: DietaryOption.set(fromCommaSeparated: raw)
        )
        guard !prefs.isEmpty else {
            // The key held nothing parseable — just clear it.
            defaults.removeObject(forKey: Self.legacyDietaryPrefsKey)
            return
        }

        if await updateMember(mine.id, displayName: mine.displayName, dietaryPreferences: prefs) {
            defaults.removeObject(forKey: Self.legacyDietaryPrefsKey)
            print("🟢 [HouseholdService] migrated device-local dietary prefs to member row: \(prefs)")
        } else {
            // Keep the key; a later launch retries. Don't surface the
            // error — the user didn't ask for this write.
            errorMessage = nil
        }
    }

    private func loadExistingHousehold(for userID: UUID) async throws -> HouseholdRow? {
        let memberships: [HouseholdMemberRow] = try await supabase
            .from("household_members")
            .select()
            .eq("user_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        if let membership = memberships.first {
            return try await loadHousehold(id: membership.householdID)
        }

        let owned: [HouseholdRow] = try await supabase
            .from("households")
            .select()
            .eq("owner_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        return owned.first
    }

    private func loadHousehold(id: UUID) async throws -> HouseholdRow? {
        let rows: [HouseholdRow] = try await supabase
            .from("households")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func isUniqueViolation(_ error: Error) -> Bool {
        if let postgrestError = error as? PostgrestError {
            return postgrestError.code == "23505"
        }

        let description = "\(error) \(error.localizedDescription)"
        return description.contains("23505")
            || description.contains("one_owned_household_per_user")
    }
}
