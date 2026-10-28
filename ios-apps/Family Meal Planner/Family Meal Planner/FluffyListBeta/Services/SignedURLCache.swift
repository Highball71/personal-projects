//
//  SignedURLCache.swift
//  FluffyList
//
//  Private photos (family history, cookbook illustrations) display
//  through short-lived signed URLs. Every RecipeCardImage and
//  FamilyPhotoTile used to sign a fresh one-hour URL in its .task, so
//  scrolling a list re-signed the same photo over and over — one
//  network round trip per row appearance, and a different URL each
//  time, which also defeats AsyncImage/URLCache reuse.
//
//  This in-memory cache keeps one signed URL per (bucket, path) and
//  hands it back until it is within `refreshMargin` of expiring, then
//  signs a new one. Memory only: nothing is persisted, and a relaunch
//  starts empty.
//

import Foundation

@MainActor
final class SignedURLCache {
    static let shared = SignedURLCache()

    /// How long each signed URL is valid, in seconds (what we ask
    /// Supabase for).
    static let lifetime: TimeInterval = 3600
    /// Stop reusing a URL this long before it expires, so a photo that
    /// starts loading near the end of the hour never gets a URL that
    /// dies mid-download.
    static let refreshMargin: TimeInterval = 600

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    /// Injected so tests can move time forward without waiting an hour.
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// The cached URL for (bucket, path) if it still has more than
    /// refreshMargin left; otherwise calls `sign` (which should ask
    /// for a URL valid for `lifetime` seconds), caches, and returns it.
    /// A failed `sign` caches nothing, so the next view retries.
    func url(
        bucket: String,
        path: String,
        sign: (_ expiresIn: Int) async throws -> URL
    ) async throws -> URL {
        let key = "\(bucket)/\(path)"
        if let entry = entries[key], now() < entry.expiresAt.addingTimeInterval(-Self.refreshMargin) {
            return entry.url
        }
        // Stamp the expiry from BEFORE the request, so network time is
        // counted against the URL's life rather than added to it.
        let requestedAt = now()
        let url = try await sign(Int(Self.lifetime))
        entries[key] = Entry(url: url, expiresAt: requestedAt.addingTimeInterval(Self.lifetime))
        return url
    }

    /// Forget everything — e.g. on sign-out.
    func removeAll() {
        entries.removeAll()
    }
}
