import Foundation
import CryptoKit

/// The audio asset library: a directory of generated .m4a files plus a
/// manifest recording what each file was rendered from. Assets are generated
/// lazily (a lesson's three words, a review session's scenes) rather than the
/// whole catalog up front, so storage and CPU stay proportional to use.
///
/// Staleness is fingerprint-driven: an asset is valid only if the manifest
/// entry's fingerprint (text + voice profile + provider) matches what we'd
/// generate today. Change the voice, the rate, the provider, or the scene
/// text, and the old file stops being served and gets regenerated.
actor AudioStore {
    static let shared = AudioStore()

    /// One generated audio file's provenance.
    struct ManifestEntry: Codable {
        let filename: String
        let fingerprint: String
        let generatedAt: Date
    }

    private struct Manifest: Codable {
        var entries: [String: ManifestEntry] = [:]  // assetID → entry
    }

    /// A request to have audio available for one piece of text.
    struct AssetRequest {
        let id: String              // e.g. "petrichor.scene", "petrichor.word"
        let text: String
        let style: VoiceProfile.Style
    }

    private let generator = SpeechAudioGeneratorFactory.make()
    private var manifest: Manifest
    private let directory: URL
    private let manifestURL: URL
    private var inFlight: Set<String> = []

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("WordSceneAudio", isDirectory: true)
        manifestURL = directory.appendingPathComponent("manifest.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: manifestURL),
           let loaded = try? JSONDecoder().decode(Manifest.self, from: data) {
            manifest = loaded
        } else {
            manifest = Manifest()
        }
    }

    /// The playable file for an asset, or nil if it hasn't been generated
    /// (or is stale). Callers fall back to live speech on nil — audio is an
    /// upgrade, never a requirement.
    func url(for request: AssetRequest) -> URL? {
        guard let entry = manifest.entries[request.id],
              entry.fingerprint == fingerprint(for: request) else {
            return nil
        }
        let url = directory.appendingPathComponent(entry.filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Generates any missing or stale assets in the batch. Safe to call
    /// repeatedly; work already done (or in flight) is skipped.
    func ensureGenerated(_ requests: [AssetRequest]) async {
        for request in requests {
            guard url(for: request) == nil, !inFlight.contains(request.id) else { continue }
            inFlight.insert(request.id)
            defer { inFlight.remove(request.id) }

            let fp = fingerprint(for: request)
            let filename = "\(request.id)-\(String(fp.prefix(8))).m4a"
            let fileURL = directory.appendingPathComponent(filename)
            do {
                try? FileManager.default.removeItem(at: fileURL)
                try await generator.writeAudio(for: request.text, style: request.style, to: fileURL)
                // Drop the old file for this asset before recording the new one
                if let old = manifest.entries[request.id], old.filename != filename {
                    try? FileManager.default.removeItem(at: directory.appendingPathComponent(old.filename))
                }
                manifest.entries[request.id] = ManifestEntry(
                    filename: filename, fingerprint: fp, generatedAt: Date()
                )
                saveManifest()
            } catch {
                // Generation is best-effort: live speech covers the gap.
                // Leave no manifest entry so the next call retries.
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func fingerprint(for request: AssetRequest) -> String {
        let input = "\(generator.providerID)|\(VoiceProfile.current.fingerprint)|\(styleTag(request.style))|\(request.text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func styleTag(_ style: VoiceProfile.Style) -> String {
        switch style {
        case .scene: return "scene"
        case .word: return "word"
        }
    }

    private func saveManifest() {
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }
}

// MARK: - Standard asset requests for seed words

extension AudioStore.AssetRequest {
    static func scene(for word: SeedWord) -> Self {
        .init(id: "\(word.id).scene", text: word.systemScene, style: .scene)
    }
    static func word(for word: SeedWord) -> Self {
        .init(id: "\(word.id).word", text: word.word, style: .word)
    }
    static func definition(for word: SeedWord) -> Self {
        .init(id: "\(word.id).definition", text: word.definition, style: .scene)
    }
    static func neighborLine(for word: SeedWord) -> Self? {
        guard let line = word.spokenNeighborLine else { return nil }
        return .init(id: "\(word.id).neighbor", text: line, style: .scene)
    }
    static func reviewScene(for word: SeedWord) -> Self? {
        guard let text = word.reviewScene else { return nil }
        return .init(id: "\(word.id).review", text: text, style: .scene)
    }

    /// Everything the full lesson beat needs for one word:
    /// scene → word → definition → neighbour line.
    static func lessonAssets(for word: SeedWord) -> [Self] {
        var assets: [Self] = [.scene(for: word), .word(for: word), .definition(for: word)]
        if let neighbor = neighborLine(for: word) { assets.append(neighbor) }
        return assets
    }
}
