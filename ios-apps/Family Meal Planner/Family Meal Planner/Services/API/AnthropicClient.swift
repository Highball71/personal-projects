//
//  AnthropicClient.swift
//  FluffyList
//
//  HTTP transport to the Anthropic API. Handles request building,
//  authentication, and response decoding. No recipe-specific logic.

import Foundation

enum AnthropicClient {

    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Errors

    enum ClientError: LocalizedError {
        case noAPIKey
        case networkError(Error)
        case httpError(statusCode: Int, message: String)
        case decodingError(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                "No API key found. Please add your Anthropic API key in Settings."
            case .networkError(let error):
                "Network error: \(error.localizedDescription)"
            case .httpError(let code, let message):
                "API error (\(code)): \(message)"
            case .decodingError(let detail):
                "Could not read the response: \(detail)"
            case .emptyResponse:
                "The API returned an empty response."
            }
        }
    }

    // MARK: - Public

    /// Send a messages request with text content.
    static func sendTextMessage(
        systemPrompt: String,
        userPrompt: String,
        model: String = AnthropicModels.defaultModelID,
        maxTokens: Int = AnthropicModels.maxTokens,
        timeout: TimeInterval = 60
    ) async throws -> AnthropicResponse {
        let apiKey = try getAPIKey()

        var request = makeBaseRequest(apiKey: apiKey, timeout: timeout)

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    /// Send a messages request with image content (single image).
    static func sendImageMessage(
        systemPrompt: String,
        userPrompt: String,
        base64Image: String,
        model: String = AnthropicModels.defaultModelID,
        maxTokens: Int = AnthropicModels.maxTokens,
        timeout: TimeInterval = 60
    ) async throws -> AnthropicResponse {
        let apiKey = try getAPIKey()

        var request = makeBaseRequest(apiKey: apiKey, timeout: timeout)

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": userPrompt
                        ]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    /// Send a messages request with multiple images.
    static func sendMultiImageMessage(
        systemPrompt: String,
        userPrompt: String,
        imageContents: [[String: Any]],
        model: String = AnthropicModels.defaultModelID,
        maxTokens: Int = AnthropicModels.maxTokens,
        timeout: TimeInterval = 90
    ) async throws -> AnthropicResponse {
        let apiKey = try getAPIKey()

        var request = makeBaseRequest(apiKey: apiKey, timeout: timeout)

        var messageContent: [[String: Any]] = imageContents
        messageContent.append([
            "type": "text",
            "text": userPrompt
        ])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": messageContent]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    // MARK: - Helpers

    /// Extract the text content from the first text block in a response.
    static func extractText(from response: AnthropicResponse) throws -> String {
        guard let textBlock = response.content.first(where: { $0.type == "text" }),
              let text = textBlock.text else {
            throw ClientError.emptyResponse
        }
        return text
    }

    // MARK: - Private

    private static func getAPIKey() throws -> String {
        if let key = try? KeychainHelper.getAnthropicAPIKey(), !key.isEmpty {
            return key
        }
        if let envKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        throw ClientError.noAPIKey
    }

    private static func makeBaseRequest(apiKey: String, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(AnthropicModels.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeout
        return request
    }

    private static func execute(_ request: URLRequest) async throws -> AnthropicResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw ClientError.httpError(statusCode: httpResponse.statusCode, message: body)
        }

        do {
            return try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            throw ClientError.decodingError(error.localizedDescription)
        }
    }
}
