//
//  AnthropicClient.swift
//  FluffyList
//
//  HTTP transport to the Anthropic API. Handles request building,
//  authentication, and response decoding. No recipe-specific logic.

import Foundation

enum AnthropicClient {

    static let endpoint = URL(string: "https://fluffylist-proxy.onrender.com/v1/messages")!

    // Proxy key — authenticates this app to the fluffylist-proxy server.
    // The actual Anthropic API key is stored server-side and never sent to the app.
    private static let proxyKey = "fluffylist-proxy-2026-xk9mq"

    // MARK: - Errors

    enum ClientError: LocalizedError {
        case networkError(Error)
        case httpError(statusCode: Int, message: String)
        case decodingError(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
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
        var request = makeBaseRequest(timeout: timeout)

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
        var request = makeBaseRequest(timeout: timeout)

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
        var request = makeBaseRequest(timeout: timeout)

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

    private static func makeBaseRequest(timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(proxyKey, forHTTPHeaderField: "X-Proxy-Key")
        request.setValue(AnthropicModels.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeout
        return request
    }

    private static func execute(_ request: URLRequest) async throws -> AnthropicResponse {
        // Log the outbound request so we can confirm the proxy URL and key.
        let keyHint = request.value(forHTTPHeaderField: "X-Proxy-Key").map { "\($0.prefix(8))..." } ?? "MISSING"
        let version = request.value(forHTTPHeaderField: "anthropic-version") ?? "?"
        print("[DEBUG AnthropicClient] → POST \(request.url?.absoluteString ?? "?")")
        print("[DEBUG AnthropicClient]   X-Proxy-Key: \(keyHint)  anthropic-version: \(version)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[DEBUG AnthropicClient] Network request FAILED: \(error)")
            throw ClientError.networkError(error)
        }

        let httpResponse = response as? HTTPURLResponse
        let statusCode = httpResponse?.statusCode ?? -1
        let contentType = httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "?"
        print("[DEBUG AnthropicClient] ← \(statusCode)  Content-Type: \(contentType)  (\(data.count) bytes)")

        let rawBody = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"

        if !(200...299).contains(statusCode) {
            // Print the full error body — reveals whether it's a proxy error
            // (HTML cold-start page, auth rejection) or an Anthropic API error.
            print("[DEBUG AnthropicClient] Error body:\n\(rawBody)")
            throw ClientError.httpError(statusCode: statusCode, message: rawBody)
        }

        do {
            let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            print("[DEBUG AnthropicClient] Decoded OK — id: \(decoded.id), blocks: \(decoded.content.count)")
            return decoded
        } catch {
            // Print the full body on decode failure — helps diagnose format
            // mismatches between what the proxy returns and AnthropicResponse.
            print("[DEBUG AnthropicClient] DECODING FAILED: \(error)")
            print("[DEBUG AnthropicClient] Full response body:\n\(rawBody)")
            throw ClientError.decodingError(error.localizedDescription)
        }
    }
}
