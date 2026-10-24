//
//  ContentFilterRetryTests.swift
//  Family Meal PlannerTests
//
//  Some cookbook pages come back from Anthropic as 400
//  invalid_request_error "Output blocked by content filtering policy".
//  The extractor must spot that specific error, retry once with the same
//  image(s) plus an instruction to paraphrase the steps, and if that is
//  also blocked, throw contentFiltered with a clear message — never
//  "Server error (400)". Other errors must not trigger the retry.
//
//  All requests go through a fake AnthropicClient.transport: no network
//  call is ever made.

import XCTest
import UIKit
@testable import Family_Meal_Planner

final class ContentFilterRetryTests: XCTestCase {

    // MARK: - Helpers

    /// What the extractor sent on each (fake) request.
    private final class RequestLog {
        var userPrompts: [String] = []
        var imagePayloads: [[String]] = []
    }

    /// One canned reply from the fake API.
    private struct FakeReply {
        let statusCode: Int
        let body: Data
    }

    /// The error body the proxy logged for the blocked pages.
    private static let contentFilterBody = """
        {"type":"error","error":{"type":"invalid_request_error",\
        "message":"Output blocked by content filtering policy"}}
        """

    private static let otherBadRequestBody = """
        {"type":"error","error":{"type":"invalid_request_error",\
        "message":"messages.0.content.0.image.source.base64: image exceeds 5 MB maximum"}}
        """

    /// Tiny in-memory images — the extractor needs them to build the
    /// request; the fake transport only records their base64 payloads.
    private static func testImage(_ color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func blocked() -> FakeReply {
        FakeReply(statusCode: 400, body: Data(Self.contentFilterBody.utf8))
    }

    private func success() throws -> FakeReply {
        let text = try PhotoImportFixtures.text("P05-4096-diagnostic")
        let object: [String: Any] = [
            "id": "msg_test",
            "content": [["type": "text", "text": text]],
            "stop_reason": "end_turn",
        ]
        return FakeReply(statusCode: 200, body: try JSONSerialization.data(withJSONObject: object))
    }

    /// Install a fake transport that serves `replies` in order and logs
    /// each request's text prompt and image data. Restored on teardown.
    private func installFakeTransport(replies: [FakeReply]) -> RequestLog {
        let log = RequestLog()
        var remaining = replies
        AnthropicClient.transport = { request in
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
            let content = try XCTUnwrap(messages.first?["content"] as? [[String: Any]])
            log.userPrompts.append(content.compactMap { $0["text"] as? String }.joined())
            log.imagePayloads.append(content.compactMap {
                ($0["source"] as? [String: Any])?["data"] as? String
            })

            guard !remaining.isEmpty else {
                XCTFail("Extractor sent more requests than expected (\(replies.count))")
                throw AnthropicClient.ClientError.emptyResponse
            }
            let reply = remaining.removeFirst()
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: reply.statusCode,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"]
            )!
            return (reply.body, response)
        }
        addTeardownBlock { @MainActor in
            AnthropicClient.transport = AnthropicClient.liveTransport
        }
        return log
    }

    // MARK: - Detection

    func testDetectsContentFilter400() {
        let error = AnthropicClient.ClientError.httpError(statusCode: 400, message: Self.contentFilterBody)
        XCTAssertTrue(error.isContentFilterBlock)
    }

    func testDetectionIsCaseInsensitive() {
        let error = AnthropicClient.ClientError.httpError(statusCode: 400, message: "OUTPUT BLOCKED BY CONTENT FILTERING POLICY")
        XCTAssertTrue(error.isContentFilterBlock)
    }

    func testOther400IsNotContentFilter() {
        let error = AnthropicClient.ClientError.httpError(statusCode: 400, message: Self.otherBadRequestBody)
        XCTAssertFalse(error.isContentFilterBlock)
    }

    func testContentFilterTextOnNon400IsNotContentFilter() {
        let error = AnthropicClient.ClientError.httpError(statusCode: 500, message: Self.contentFilterBody)
        XCTAssertFalse(error.isContentFilterBlock)
    }

    func testNonHTTPErrorsAreNotContentFilter() {
        XCTAssertFalse(AnthropicClient.ClientError.emptyResponse.isContentFilterBlock)
        XCTAssertFalse(AnthropicClient.ClientError.decodingError("content filtering").isContentFilterBlock)
        XCTAssertFalse(AnthropicClient.ClientError.networkError(URLError(.timedOut)).isContentFilterBlock)
    }

    // MARK: - Retry path

    func testBlockedPageRetriesOnceWithSameImageAndParaphraseInstruction() async throws {
        let log = installFakeTransport(replies: [blocked(), try success()])

        let recipe = try await RecipeImageExtractor.extract(from: [Self.testImage(.white)])

        XCTAssertEqual(log.userPrompts.count, 2, "Exactly one retry")
        XCTAssertFalse(log.userPrompts[0].contains(RecipeImageExtractor.contentFilterRetryInstruction),
                       "First try uses the normal prompt")
        XCTAssertTrue(log.userPrompts[1].contains(RecipeImageExtractor.contentFilterRetryInstruction),
                      "Retry adds the paraphrase-steps instruction")
        XCTAssertTrue(log.userPrompts[1].hasPrefix(log.userPrompts[0]),
                      "Retry keeps the original prompt and only appends to it")
        XCTAssertEqual(log.imagePayloads[0], log.imagePayloads[1], "Retry sends the same image")
        XCTAssertEqual(log.imagePayloads[0].count, 1)

        XCTAssertEqual(recipe.name, "Mexican Twice Baked Potatoes")
        XCTAssertEqual(recipe.ingredients.count, 27)
    }

    func testBlockedMultiPageRetriesWithSameImages() async throws {
        let log = installFakeTransport(replies: [blocked(), try success()])

        _ = try await RecipeImageExtractor.extract(from: [Self.testImage(.white), Self.testImage(.black)])

        XCTAssertEqual(log.userPrompts.count, 2)
        XCTAssertTrue(log.userPrompts[1].contains(RecipeImageExtractor.contentFilterRetryInstruction))
        XCTAssertEqual(log.imagePayloads[0].count, 2)
        XCTAssertEqual(log.imagePayloads[0], log.imagePayloads[1], "Retry sends the same pages in the same order")
    }

    func testDoubleBlockThrowsContentFilteredWithClearMessage() async throws {
        let log = installFakeTransport(replies: [blocked(), blocked()])

        do {
            _ = try await RecipeImageExtractor.extract(from: [Self.testImage(.white)])
            XCTFail("Extraction should have thrown")
        } catch let error as RecipeImageExtractor.ExtractionError {
            guard case .contentFiltered = error else {
                return XCTFail("Expected .contentFiltered, got \(error)")
            }
            XCTAssertEqual(
                error.localizedDescription,
                "This page couldn't be read automatically. Add it by hand — the photo is saved with the recipe."
            )
        } catch {
            XCTFail("A double content-filter block must not surface as a raw HTTP error, got \(error)")
        }
        XCTAssertEqual(log.userPrompts.count, 2, "Exactly one retry — no loop")
    }

    func testOther400DoesNotRetry() async throws {
        let log = installFakeTransport(replies: [
            FakeReply(statusCode: 400, body: Data(Self.otherBadRequestBody.utf8)),
        ])

        do {
            _ = try await RecipeImageExtractor.extract(from: [Self.testImage(.white)])
            XCTFail("Extraction should have thrown")
        } catch let AnthropicClient.ClientError.httpError(statusCode, _) {
            XCTAssertEqual(statusCode, 400, "Unrelated 400s pass through unchanged")
        } catch {
            XCTFail("Expected the original httpError, got \(error)")
        }
        XCTAssertEqual(log.userPrompts.count, 1, "No retry for an unrelated 400")
    }
}
