import Foundation

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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
    }
}
