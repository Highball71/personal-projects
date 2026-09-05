import Foundation
import CryptoKit

/// The audio asset library, consulted in two layers:
///
/// 1. **Bundled audio** (Resources/audio/ + audio-manifest.json): the fixed
///    main-track content, generated once by scripts/generate_bundled_audio.py
///    with OpenAI TTS and shipped in the app. Served whenever the manifest's
///    text hash matches the request — so editing a scene in words.json
///    automatically stops serving its stale recording.
/// 2. **On-device generated files** (Application Support, AVSpeech): the
///    fallback layer for anything the bundle can't know about — user-authored
///    scenes, or seed content while the bundle hasn't been generated yet.
///
/// The on-device layer is fingerprint-driven: an asset is valid only if the
/// manifest entry's fingerprint (text + voice profile + provider) matches
/// what we'd generate today.
actor AudioStore {
    static let shared = AudioStore()

    /// Shape of Resources/audio/audio-manifest.json.
    private struct BundledManifest: Codable {
        struct Entry: Codable {
            let filename: String
            let textHash: String
        }
        let provider: String
        let voice: String
        let entries: [String: Entry]
    }

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

    /// Loaded once from the app bundle; nil until the generation script has
    /// been run and its output committed.
    private let bundled: BundledManifest? = {
        guard let url = Bundle.main.url(forResource: "audio-manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(BundledManifest.self, from: data)
    }()

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

    /// The playable file for an asset: bundled audio first, then on-device
    /// generated audio; nil if neither exists (or both are stale). Callers
    /// fall back to live speech on nil — audio is an upgrade, never a
    /// requirement.
    func url(for request: AssetRequest) -> URL? {
        if let url = bundledURL(for: request) {
            return url
        }
        guard let entry = manifest.entries[request.id],
              entry.fingerprint == fingerprint(for: request) else {
            return nil
        }
        let url = directory.appendingPathComponent(entry.filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Bundled asset lookup, guarded by text hash: a scene edited in
    /// words.json after generation stops matching and falls through.
    private func bundledURL(for request: AssetRequest) -> URL? {
        guard let bundled, let entry = bundled.entries[request.id],
              entry.textHash == Self.sha256Hex(request.text) else {
            return nil
        }
        // The Resources synced group flattens into the bundle root; the
        // resource name keeps its internal dots ("petrichor.scene")
        let name = (entry.filename as NSString).deletingPathExtension
        let ext = (entry.filename as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
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
        Self.sha256Hex("\(generator.providerID)|\(VoiceProfile.current.fingerprint)|\(styleTag(request.style))|\(request.text)")
    }

    private static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
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
