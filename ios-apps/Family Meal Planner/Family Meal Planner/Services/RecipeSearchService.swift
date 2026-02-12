//
//  RecipeSearchService.swift
//  Family Meal Planner
//
//  Searches DuckDuckGo HTML for recipe URLs from popular food blogs,
//  parses the search results HTML, and returns a list of matching recipe pages.

import Foundation

/// A single recipe search result with a page title, URL, and site name.
struct SearchResult: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
    let siteName: String
}

/// Fetches DuckDuckGo HTML search results and extracts recipe page links
/// from a curated list of popular food blogs.
enum RecipeSearchService {

    // MARK: - Configuration

    /// Safari User-Agent (same as ClaudeAPIService uses for URL fetching)
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Recipe domains we trust. Only links to these sites appear in results.
    static let allowedDomains = [
        "allrecipes.com",
        "budgetbytes.com",
        "simplyrecipes.com",
        "foodnetwork.com",
        "seriouseats.com",
        "delish.com",
        "tasty.co",
        "epicurious.com",
        "bonappetit.com",
        "cooking.nytimes.com",
        "thepioneerwoman.com",
        "skinnytaste.com",
        "food.com",
        "tasteofhome.com",
        "damndelicious.net",
    ]

    // MARK: - Errors

    enum SearchError: LocalizedError {
        case invalidQuery
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .invalidQuery:
                "The search query was empty."
            case .networkError(let detail):
                "Search failed: \(detail)"
            }
        }
    }

    // MARK: - Public

    /// Search DuckDuckGo for recipe pages matching the given query.
    /// Returns up to 8 results from known recipe domains.
    static func searchRecipes(query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw SearchError.invalidQuery }

        // Build DuckDuckGo HTML search URL
        guard let encoded = "\(trimmed) recipe"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw SearchError.invalidQuery
        }
        let searchURL = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)")!
        print("[RecipeSearch] Searching: \(searchURL.absoluteString)")

        // Fetch search results HTML
        var request = URLRequest(url: searchURL)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[RecipeSearch] Network error: \(error)")
            throw SearchError.networkError(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("[RecipeSearch] HTTP \(httpResponse.statusCode), \(data.count) bytes")
        }

        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .ascii)
            ?? ""

        let results = parseSearchResults(from: html)
        print("[RecipeSearch] Found \(results.count) recipe result(s)")
        return results
    }

    // MARK: - HTML Parsing

    /// Extract recipe links from DuckDuckGo HTML search results.
    private static func parseSearchResults(from html: String) -> [SearchResult] {
        var results: [SearchResult] = []
        var seenHosts: Set<String> = []

        // DuckDuckGo HTML results use <a ... class="result__a" href="...">Title</a>
        // Other attributes like rel="nofollow" may appear before class, so we
        // allow arbitrary attributes between <a and class="result__a".
        let resultPattern = #"<a\s[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        guard let resultRegex = try? NSRegularExpression(pattern: resultPattern, options: .dotMatchesLineSeparators) else {
            return []
        }

        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = resultRegex.matches(in: html, range: nsRange)

        for match in matches {
            guard results.count < 8 else { break }

            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }

            let rawHref = String(html[hrefRange])
            let rawTitle = String(html[titleRange])

            // Resolve the actual destination URL
            guard let url = resolveURL(from: rawHref) else { continue }

            guard let host = url.host?.lowercased() else { continue }

            // Only keep links to known recipe domains
            guard allowedDomains.contains(where: { host.contains($0) }) else {
                continue
            }

            // Deduplicate by host — one result per site
            let hostKey = host.replacingOccurrences(of: "www.", with: "")
            guard !seenHosts.contains(hostKey) else { continue }
            seenHosts.insert(hostKey)

            // Clean up the title: strip HTML tags and decode entities
            let title = cleanTitle(rawTitle).isEmpty
                ? titleFromURLPath(url)
                : cleanTitle(rawTitle)

            let siteName = friendlySiteName(from: host)
            results.append(SearchResult(title: title, url: url, siteName: siteName))
            print("[RecipeSearch]   \(siteName): \(title)")
        }

        return results
    }

    /// Resolve a DuckDuckGo href to the actual destination URL.
    /// Handles both direct URLs and redirect URLs with a "uddg" query parameter.
    private static func resolveURL(from href: String) -> URL? {
        // DuckDuckGo redirect: "//duckduckgo.com/l/?uddg=https%3A%2F%2F..."
        if href.contains("duckduckgo.com/l/") || href.contains("uddg=") {
            // Parse out the uddg parameter
            let searchable = href.hasPrefix("//") ? "https:\(href)" : href
            guard let components = URLComponents(string: searchable),
                  let uddg = components.queryItems?.first(where: { $0.name == "uddg" })?.value,
                  let url = URL(string: uddg) else {
                return nil
            }
            return url
        }

        // Direct URL (may start with // or http)
        let normalized = href.hasPrefix("//") ? "https:\(href)" : href
        return URL(string: normalized)
    }

    /// Strip HTML tags from a title string and decode entities.
    private static func cleanTitle(_ raw: String) -> String {
        let stripped = raw.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        return decodeHTMLEntities(stripped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Derive a readable title from a URL path as a fallback.
    /// "/recipe/easy-chicken-parmesan/" → "Easy Chicken Parmesan"
    private static func titleFromURLPath(_ url: URL) -> String {
        let lastComponent = url.pathComponents.last(where: { $0 != "/" && !$0.isEmpty })
            ?? url.lastPathComponent
        return lastComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Convert a hostname to a friendly display name.
    /// "www.allrecipes.com" → "AllRecipes"
    /// "cooking.nytimes.com" → "NYT Cooking"
    private static func friendlySiteName(from host: String) -> String {
        let clean = host.replacingOccurrences(of: "www.", with: "")
        let names: [String: String] = [
            "allrecipes.com": "AllRecipes",
            "budgetbytes.com": "Budget Bytes",
            "simplyrecipes.com": "Simply Recipes",
            "foodnetwork.com": "Food Network",
            "seriouseats.com": "Serious Eats",
            "delish.com": "Delish",
            "tasty.co": "Tasty",
            "epicurious.com": "Epicurious",
            "bonappetit.com": "Bon Appetit",
            "cooking.nytimes.com": "NYT Cooking",
            "thepioneerwoman.com": "Pioneer Woman",
            "skinnytaste.com": "Skinnytaste",
            "food.com": "Food.com",
            "tasteofhome.com": "Taste of Home",
            "damndelicious.net": "Damn Delicious",
        ]
        return names[clean] ?? clean
    }

    // MARK: - Text Cleanup

    /// Decode common HTML entities in search result titles.
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&#x27;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}
