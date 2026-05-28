//
//  SupabaseManager.swift
//  FluffyList
//
//  Singleton that owns the Supabase client.
//  URL and anon key are read from Secrets.xcconfig via Info.plist.
//

import Combine
import Foundation
import Supabase

enum HouseholdMembershipState: Equatable {
    case loading
    case noHousehold
    case hasHousehold(UUID)
    case failed(String)
}

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    /// The currently signed-in user's profile ID, if any.
    @Published private(set) var currentUserID: UUID?

    /// The household the current user belongs to, if any.
    @Published private(set) var currentHouseholdID: UUID?

    /// Explicit lookup state so a failed/in-flight membership lookup is
    /// never mistaken for "the user genuinely has no household."
    @Published private(set) var householdMembershipState: HouseholdMembershipState = .loading

    /// Non-nil when Supabase configuration is missing or invalid. When set,
    /// the app shows a recoverable config-error screen instead of crashing
    /// at launch. The `client`/`projectURL` are placeholders in this state
    /// and must not be used — routing gates on `configError` first.
    @Published private(set) var configError: String?

    private init() {
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL")
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY")

        // Safe stand-ins so the singleton can finish init without a session
        // when config is bad. Never used for real requests — the config-error
        // screen intercepts routing before any service touches the client.
        let placeholderURL = URL(string: "https://placeholder.supabase.co")!

        guard let urlString = rawURL as? String, !urlString.isEmpty else {
            configError = "Supabase URL is missing. Add SUPABASE_URL to Secrets.xcconfig and rebuild."
            projectURL = placeholderURL
            client = SupabaseClient(supabaseURL: placeholderURL, supabaseKey: "placeholder")
            return
        }

        guard let url = URL(string: urlString), url.host != nil else {
            // A nil host usually means the '//' was eaten by xcconfig's
            // comment parser — fix with SUPABASE_URL=https:/$()/host in Secrets.
            configError = "Supabase URL is invalid (\"\(urlString)\"). Check SUPABASE_URL in Secrets.xcconfig."
            projectURL = placeholderURL
            client = SupabaseClient(supabaseURL: placeholderURL, supabaseKey: "placeholder")
            return
        }

        guard let anonKey = rawKey as? String, !anonKey.isEmpty else {
            configError = "Supabase anon key is missing. Add SUPABASE_ANON_KEY to Secrets.xcconfig and rebuild."
            projectURL = url
            client = SupabaseClient(supabaseURL: url, supabaseKey: "placeholder")
            return
        }

        projectURL = url
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    // MARK: - Session State

    /// Update the cached user ID after sign-in/sign-out.
    func setCurrentUser(_ id: UUID?) {
        currentUserID = id
    }

    /// Update the cached household ID after create/join.
    func setCurrentHousehold(_ id: UUID?) {
        currentHouseholdID = id
        householdMembershipState = id.map { .hasHousehold($0) } ?? .noHousehold
    }

    func setHouseholdMembershipLoading() {
        householdMembershipState = .loading
    }

    func setHouseholdMembershipFailed(_ message: String) {
        householdMembershipState = .failed(message)
    }

    // MARK: - Storage

    /// The project's base URL, read from Info.plist at init.
    let projectURL: URL

    /// Build a public URL for a file in Supabase Storage.
    /// Returns nil if the path is nil or empty.
    func publicStorageURL(path: String?, bucket: String = "recipe-images") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return projectURL
            .appendingPathComponent("storage/v1/object/public")
            .appendingPathComponent(bucket)
            .appendingPathComponent(path)
    }
}
