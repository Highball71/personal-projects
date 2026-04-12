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

            // Temporary debug delay — ensure token is propagated to PostgREST.
            try await Task.sleep(nanoseconds: 500_000_000)

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
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Join Household by Code

    /// Join an existing household using a 6-character code.
    func joinHousehold(code: String, memberDisplayName: String) async -> Bool {
        // ── DEBUG: join code input ──
        print("🟡 [HouseholdService] joinHousehold called")
        print("   • raw code: \"\(code)\"")
        print("   • raw display_name: \"\(memberDisplayName)\"")

        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("   • normalized code: \"\(trimmedCode)\" (length=\(trimmedCode.count))")

        guard trimmedCode.count == 6 else {
            print("🔴 [HouseholdService] joinHousehold: invalid code length \(trimmedCode.count)")
            errorMessage = "Join code must be 6 characters."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // Confirm we have a live authenticated session before any writes.
            let session = try await supabase.auth.session
            let userID = session.user.id
            print("🟢 [HouseholdService] Authenticated Supabase user: \(userID)")
            print("🟢 [HouseholdService] Access token present: \(!session.accessToken.isEmpty)")

            // Temporary debug delay — ensure token is propagated to PostgREST.
            try await Task.sleep(nanoseconds: 500_000_000)

            // ── DEBUG: households SELECT by join_code ──
            print("🟡 [HouseholdService] SELECT households WHERE join_code=\"\(trimmedCode)\"")
            let households: [HouseholdRow] = try await supabase
                .from("households")
                .select()
                .eq("join_code", value: trimmedCode)
                .limit(1)
                .execute()
                .value

            print("🟢 [HouseholdService] SELECT households returned \(households.count) row(s)")

            guard let found = households.first else {
                print("🔴 [HouseholdService] No household found for join_code=\"\(trimmedCode)\"")
                errorMessage = "No household found with that code."
                isLoading = false
                return false
            }

            print("🟢 [HouseholdService] found household id=\(found.id), name=\"\(found.name)\", owner_id=\(found.ownerID)")

            // ── DEBUG: household_members INSERT ──
            let memberPayload = HouseholdMemberInsert(
                householdID: found.id,
                userID: userID,
                displayName: memberDisplayName,
                isHeadCook: false
            )
            print("🟡 [HouseholdService] INSERT household_members payload: household_id=\(memberPayload.householdID), user_id=\(memberPayload.userID), display_name=\"\(memberPayload.displayName)\", is_head_cook=\(memberPayload.isHeadCook)")

            try await supabase
                .from("household_members")
                .insert(memberPayload)
                .execute()

            print("🟢 [HouseholdService] household_members INSERT succeeded")

            household = found
            SupabaseManager.shared.setCurrentHousehold(found.id)
            print("🟢 [HouseholdService] setCurrentHousehold(\(found.id)) — AppRootView should flip into household")

            // Reload members so the UI reflects both users.
            print("🟡 [HouseholdService] reloading members after join…")
            await loadMembers()

            isLoading = false
            return true
        } catch {
            print("🔴 [HouseholdService] joinHousehold ERROR: \(error)")
            errorMessage = error.localizedDescription
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
}
