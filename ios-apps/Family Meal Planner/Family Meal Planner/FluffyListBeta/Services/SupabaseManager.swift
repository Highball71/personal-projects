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

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    /// The currently signed-in user's profile ID, if any.
    @Published private(set) var currentUserID: UUID?

    /// The household the current user belongs to, if any.
    @Published private(set) var currentHouseholdID: UUID?

    private init() {
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL")
        let rawKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY")

        // ── Diagnostics ──
        print("[SupabaseManager] SUPABASE_URL raw: \(String(describing: rawURL))")
        print("[SupabaseManager] SUPABASE_ANON_KEY present: \(rawKey != nil)")

        guard let urlString = rawURL as? String, !urlString.isEmpty else {
            fatalError("Missing SUPABASE_URL at runtime. Raw value: \(String(describing: rawURL))")
        }

        let parsed = URL(string: urlString)
        print("[SupabaseManager] urlString: \"\(urlString)\"")
        print("[SupabaseManager] URL absoluteString: \(parsed?.absoluteString ?? "nil")")
        print("[SupabaseManager] URL scheme: \(parsed?.scheme ?? "nil")")
        print("[SupabaseManager] URL host: \(parsed?.host ?? "nil")")

        guard let url = parsed, url.host != nil else {
            fatalError(
                "Invalid SUPABASE_URL at runtime: \"\(urlString)\". "
                + "host is nil — the '//' was likely eaten by xcconfig's comment parser. "
                + "Fix in Secrets.xcconfig: SUPABASE_URL=https:/$()/yourproject.supabase.co"
            )
        }

        guard let anonKey = rawKey as? String, !anonKey.isEmpty else {
            fatalError("Missing SUPABASE_ANON_KEY at runtime. Raw value: \(String(describing: rawKey))")
        }

        print("[SupabaseManager] Creating SupabaseClient with host: \(url.host!)")
        projectURL = url
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        print("[SupabaseManager] SupabaseClient created successfully")
    }

    // MARK: - Session State

    /// Check if we have a valid session and update currentUserID.
    func refreshSession() async {
        do {
            let session = try await client.auth.session
            setCurrentUser(session.user.id)
        } catch {
            setCurrentUser(nil)
        }
    }

    /// Update the cached user ID after sign-in/sign-out.
    func setCurrentUser(_ id: UUID?) {
        currentUserID = id
    }

    /// Update the cached household ID after create/join.
    func setCurrentHousehold(_ id: UUID?) {
        currentHouseholdID = id
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
