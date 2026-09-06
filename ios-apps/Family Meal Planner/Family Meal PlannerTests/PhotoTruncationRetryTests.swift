//
//  PhotoTruncationRetryTests.swift
//  Family Meal PlannerTests
//
//  Fix 1 from the 2026-09-06 photo-import test report: a response that
//  hits the output-token limit (stop_reason == "max_tokens") is cut off
//  mid-JSON. The extractor must retry once with a doubled limit, and if
//  that is also cut off, throw responseTruncated — never hand truncated
//  text to the JSON parser.
//
//  All requests go through a fake AnthropicClient.transport: no network
//  call is ever made.

import XCTest
import UIKit
@testable import Family_Meal_Planner

final class PhotoTruncationRetryTests: XCTestCase {

    // MARK: - Helpers

    /// Records what the extractor asked the (fake) API for.
    private final class RequestLog {
        var maxTokensPerRequest: [Int] = []
    }

    /// A tiny in-memory image — the extractor needs one to build the
    /// request; the fake transport ignores it.
    private static let testImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }()

    /// Wrap recipe-JSON text in the Anthropic Messages API response envelope.
    private func envelope(text: String, stopReason: String) throws -> Data {
        let object: [String: Any] = [
            "id": "msg_test",
            "content": [["type": "text", "text": text]],
            "stop_reason": stopReason,
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// Install a fake transport that serves `bodies` in order and logs
    /// the max_tokens of each request. Restored on teardown.
    private func installFakeTransport(bodies: [Data]) -> RequestLog {
        let log = RequestLog()
        var remaining = bodies
        AnthropicClient.transport = { request in
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            log.maxTokensPerRequest.append(try XCTUnwrap(json["max_tokens"] as? Int))
            guard !remaining.isEmpty else {
                XCTFail("Extractor sent more requests than expected (\(bodies.count))")
                throw AnthropicClient.ClientError.emptyResponse
            }
            let data = remaining.removeFirst()
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }
        addTeardownBlock { @MainActor in
            AnthropicClient.transport = AnthropicClient.liveTransport
        }
        return log
    }

    /// The P05 recipe text cut at the byte length the real truncated
    /// response had: the limit was 2,048 tokens of the 2,403 the full
    /// recipe needed, so cut at that fraction of the full text.
    private func truncatedP05(from full: String) -> String {
        let cutBytes = full.utf8.count * 2048 / 2403
        return String(decoding: Data(full.utf8).prefix(cutBytes), as: UTF8.self)
    }

    // MARK: - Tests

    func testMaxTokensResponseRetriesWithDoubledLimitAndParses() async throws {
        let full = try PhotoImportFixtures.text("P05-4096-diagnostic")
        let truncated = truncatedP05(from: full)
        // Sanity: the cut really is mid-JSON.
        XCTAssertNil(try? JSONSerialization.jsonObject(with: Data(truncated.utf8)))

        let log = installFakeTransport(bodies: [
            try envelope(text: truncated, stopReason: "max_tokens"),
            try envelope(text: full, stopReason: "end_turn"),
        ])

        let recipe = try await RecipeImageExtractor.extract(from: [Self.testImage])

        XCTAssertEqual(log.maxTokensPerRequest, [8192, 16384],
                       "First try uses the extraction limit; the retry doubles it")
        XCTAssertEqual(recipe.name, "Mexican Twice Baked Potatoes")
        XCTAssertEqual(recipe.ingredients.count, 27)
        XCTAssertFalse(recipe.instructions.isEmpty)
    }

    func testDoubleTruncationThrowsResponseTruncatedNotParseError() async throws {
        let full = try PhotoImportFixtures.text("P05-4096-diagnostic")
        let truncated = truncatedP05(from: full)

        let log = installFakeTransport(bodies: [
            try envelope(text: truncated, stopReason: "max_tokens"),
            try envelope(text: truncated, stopReason: "max_tokens"),
        ])

        do {
            _ = try await RecipeImageExtractor.extract(from: [Self.testImage])
            XCTFail("Extraction should have thrown")
        } catch let error as RecipeImageExtractor.ExtractionError {
            guard case .responseTruncated = error else {
                return XCTFail("Expected .responseTruncated, got \(error)")
            }
            // The user-facing message is advice, not "incorrect format".
            XCTAssertEqual(
                error.localizedDescription,
                "The recipe was too long to read in one pass — try fewer pages or a closer photo"
            )
        } catch {
            XCTFail("Truncation must not surface as a parse/decoding error, got \(error)")
        }
        XCTAssertEqual(log.maxTokensPerRequest, [8192, 16384],
                       "Exactly one retry — no loop")
    }
}
