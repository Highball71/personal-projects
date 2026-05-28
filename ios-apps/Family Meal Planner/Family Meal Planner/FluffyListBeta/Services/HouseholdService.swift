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
            print("🟡 [HouseholdService] INSERT household_members payload: household_id=\(memberPayload.householdID), user_id=\(memberPayload.userID), display_name=\(memberPayload.displayName), is_head_cook=\(memberPayload.isHeadCook)")

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
                print("   • member: user_id=\(m.userID), display_name=\(m.displayName), is_head_cook=\(m.isHeadCook)")
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
