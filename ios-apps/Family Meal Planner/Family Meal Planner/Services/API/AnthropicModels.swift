//
//  AnthropicModels.swift
//  Family Meal Planner
//
//  Request and response Codable types for the Anthropic Messages API.

import Foundation

nonisolated enum AnthropicModels {
    static let defaultModelID = "claude-sonnet-4-20250514"
    static let apiVersion = "2023-06-01"
    static let maxTokens = 2048
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
