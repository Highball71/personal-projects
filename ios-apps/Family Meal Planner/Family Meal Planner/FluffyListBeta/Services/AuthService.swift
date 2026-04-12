//
//  AuthService.swift
//  FluffyList
//
//  Sign in with Apple via Supabase Auth.
//  Handles the full Apple credential -> Supabase session flow.
//

import AuthenticationServices
import Combine
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Session Check

    /// Check for an existing session on app launch.
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            isSignedIn = true
            SupabaseManager.shared.setCurrentUser(session.user.id)

            // Load the user's household membership.
            await loadHouseholdMembership(for: session.user.id)
        } catch {
            isSignedIn = false
        }
    }

    // MARK: - Sign in with Apple

    /// Called from the ASAuthorizationController delegate with the Apple credential.
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8)
        else {
            errorMessage = "Missing identity token from Apple."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: tokenString
                )
            )

            isSignedIn = true
            SupabaseManager.shared.setCurrentUser(session.user.id)
            await loadHouseholdMembership(for: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            isSignedIn = false
            SupabaseManager.shared.setCurrentUser(nil)
            SupabaseManager.shared.setCurrentHousehold(nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Household Lookup

    /// Find the first household this user belongs to.
    private func loadHouseholdMembership(for userID: UUID) async {
        do {
            let memberships: [HouseholdMemberRow] = try await supabase
                .from("household_members")
                .select()
                .eq("user_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value

            if let first = memberships.first {
                SupabaseManager.shared.setCurrentHousehold(first.householdID)
            }
        } catch {
            // No membership yet — that's fine, user will create/join.
        }
    }
}
