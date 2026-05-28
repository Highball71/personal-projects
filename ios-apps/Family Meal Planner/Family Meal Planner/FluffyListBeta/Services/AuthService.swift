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
    /// Where the app is in restoring / confirming the auth session.
    /// Mirrors the membership-state pattern so routing never has to guess
    /// "signed out" while a session check is still in flight, and so a
    /// transient network failure isn't mistaken for an invalid session.
    enum SessionState: Equatable {
        case restoring              // checking for an existing session
        case signedIn               // confirmed valid session
        case signedOut              // confirmed no valid session
        case restoreFailed(String)  // transient/network failure — keep the user, offer retry
    }

    @Published private(set) var sessionState: SessionState = .restoring
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    /// How long to wait for the household-membership lookup before giving up
    /// and surfacing a retry instead of spinning forever.
    private let membershipLookupTimeout: TimeInterval = 12

    // MARK: - Session Check

    /// Check for an existing session on app launch.
    func checkSession() async {
        sessionState = .restoring
        do {
            let session = try await supabase.auth.session
            SupabaseManager.shared.setHouseholdMembershipLoading()
            sessionState = .signedIn
            isSignedIn = true
            SupabaseManager.shared.setCurrentUser(session.user.id)

            // Load the user's household membership.
            await loadHouseholdMembership(for: session.user.id)
        } catch {
            isSignedIn = false
            if isTransientError(error) {
                // Network blip while restoring — DON'T sign a valid user out
                // into a sign-in wall they can't get past while offline.
                sessionState = .restoreFailed(
                    "We couldn't reach the server. Check your connection and try again."
                )
            } else {
                // No session, or a genuinely invalid/expired one.
                sessionState = .signedOut
            }
        }
    }

    /// Re-validate the session when the app returns to the foreground.
    /// Unlike `checkSession`, this never flips the UI back to `.restoring` —
    /// it silently confirms the session and only routes to sign-in if the
    /// session is genuinely gone (e.g. the token expired while backgrounded).
    func revalidateOnForeground() async {
        guard sessionState == .signedIn else { return }
        do {
            _ = try await supabase.auth.session
            // Still valid (or transparently refreshed) — nothing to do.
        } catch {
            if isTransientError(error) {
                // Offline/transient — leave the user where they are.
                return
            }
            // Token genuinely dead — route to sign-in rather than render a
            // logged-in-but-broken app.
            isSignedIn = false
            sessionState = .signedOut
            SupabaseManager.shared.setCurrentUser(nil)
            SupabaseManager.shared.setCurrentHousehold(nil)
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

            SupabaseManager.shared.setHouseholdMembershipLoading()
            sessionState = .signedIn
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
            sessionState = .signedOut
            SupabaseManager.shared.setCurrentUser(nil)
            SupabaseManager.shared.setCurrentHousehold(nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Household Lookup

    /// Find the first household this user belongs to.
    private func loadHouseholdMembership(for userID: UUID) async {
        SupabaseManager.shared.setHouseholdMembershipLoading()

        let client = supabase
        do {
            // Bounded so a stalled request surfaces a retry instead of an
            // infinite "Loading your household…" spinner.
            let memberships: [HouseholdMemberRow] = try await withTimeout(seconds: membershipLookupTimeout) {
                try await client
                    .from("household_members")
                    .select()
                    .eq("user_id", value: userID.uuidString)
                    .limit(1)
                    .execute()
                    .value
            }

            if let first = memberships.first {
                SupabaseManager.shared.setCurrentHousehold(first.householdID)
            } else {
                SupabaseManager.shared.setCurrentHousehold(nil)
            }
        } catch is TimeoutError {
            SupabaseManager.shared.setHouseholdMembershipFailed(
                "This is taking longer than expected. Check your connection and try again."
            )
        } catch {
            // Failed lookup is distinct from a successful zero-row lookup.
            // Keep the user out of create/join until they retry successfully.
            SupabaseManager.shared.setHouseholdMembershipFailed(error.localizedDescription)
        }
    }

    // MARK: - Error Classification

    /// True for transient/connectivity errors that should NOT be treated as
    /// "the session is invalid." A network blip must not log a valid user out
    /// into a sign-in wall they can't get past while offline.
    private func isTransientError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .timedOut, .networkConnectionLost,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        // Some SDK errors wrap the underlying URL error.
        return (error as NSError).domain == NSURLErrorDomain
    }
}

// MARK: - Timeout Helper

struct TimeoutError: Error {}

/// Run `operation`, throwing `TimeoutError` if it doesn't finish within
/// `seconds`. Used to bound network calls that would otherwise hang the UI.
func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        return result
    }
}
