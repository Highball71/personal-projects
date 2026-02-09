//
//  ClaudeMessagesResponse.swift
//  Family Meal Planner
//

import Foundation

/// Top-level response from the Anthropic Messages API (POST /v1/messages).
/// Only decodes the fields we actually need.
struct ClaudeMessagesResponse: Codable {
    let id: String
    let content: [ContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case stopReason = "stop_reason"
    }
}

/// A single content block in the API response.
struct ContentBlock: Codable {
    let type: String
    let text: String?
}
