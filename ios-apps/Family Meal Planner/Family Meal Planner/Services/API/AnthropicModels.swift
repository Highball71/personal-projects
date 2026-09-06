//
//  AnthropicModels.swift
//  FluffyList
//
//  Request and response Codable types for the Anthropic Messages API.

import Foundation

nonisolated enum AnthropicModels {
    static let defaultModelID = "claude-sonnet-5"
    static let apiVersion = "2023-06-01"
    // Output-token limit for extraction requests. 2048 truncated real
    // cookbook pages (the 2026-09-06 photo test's P05 needed 2,403
    // output tokens); 8192 leaves generous headroom, and the extractor
    // retries once at double this if a response still gets cut off.
    static let maxTokens = 8192
}

/// Top-level response from the Anthropic Messages API (POST /v1/messages).
/// Only decodes the fields we actually need.
struct AnthropicResponse: Codable {
    let id: String
    let content: [AnthropicContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case stopReason = "stop_reason"
    }
}

/// A single content block in the API response.
struct AnthropicContentBlock: Codable {
    let type: String
    let text: String?
}
