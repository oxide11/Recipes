import Foundation

// MARK: - Network Sessions

/// Shared `URLSession`s with real duration caps.
///
/// `URLRequest.timeoutInterval` only bounds *idle* time between bytes; a server
/// that trickles data keeps the request alive forever. `timeoutIntervalForResource`
/// on the session configuration is the only way to bound total wall-clock time.
enum NetworkSession {

    /// For AI providers: generous idle window, but the whole call must finish
    /// within a few minutes so a stalled generation never hangs the UI.
    static let ai: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 240
        return URLSession(configuration: config)
    }()

    /// For ordinary fetches (recipe pages, images, barcode lookups).
    static let standard: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 45
        return URLSession(configuration: config)
    }()
}

// MARK: - API Client

/// Shared HTTP networking layer for AI service providers.
/// Eliminates duplicated request/response handling between ClaudeService and OpenAIService.
enum APIClient {

    /// Perform an authenticated JSON API request.
    /// - Parameters:
    ///   - url: Full endpoint URL.
    ///   - method: HTTP method (e.g. "POST").
    ///   - bodyData: Pre-serialized JSON body data.
    ///   - headers: Additional HTTP headers (e.g. auth, API version).
    /// - Returns: Raw response data on success.
    static func request(
        url: URL,
        method: String = "POST",
        bodyData: Data,
        headers: [String: String]
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = bodyData

        let (data, response) = try await NetworkSession.ai.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
