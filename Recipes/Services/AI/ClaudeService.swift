import Foundation

// MARK: - Claude (Anthropic) Service

/// Integrates with the Anthropic Messages API for cloud-based AI capabilities.
/// Requires user-provided API key stored securely in Keychain.
@Observable
@MainActor
final class ClaudeService {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"

    var apiKey: String? {
        KeychainService.retrieve(key: .claudeAPIKey)
    }

    var isConfigured: Bool {
        apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    // MARK: - Messages API

    func sendMessage(
        messages: [ClaudeMessage],
        model: String = "claude-sonnet-4-20250514",
        systemPrompt: String? = nil,
        maxTokens: Int = 4096,
        temperature: Double? = nil
    ) async throws -> String {
        guard let apiKey else {
            throw AIServiceError.apiKeyMissing(provider: "Claude")
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": messages.map { $0.toDictionary() }
        ]

        if let systemPrompt {
            body["system"] = systemPrompt
        }
        if let temperature {
            body["temperature"] = temperature
        }

        let data = try await performRequest(
            endpoint: "messages",
            method: "POST",
            body: body,
            apiKey: apiKey
        )

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = response.content.first(where: { $0.type == "text" }) else {
            throw AIServiceError.emptyResponse
        }
        return textBlock.text ?? ""
    }

    // MARK: - Recipe-Specific Methods

    func generateRecipe(prompt: String) async throws -> String {
        let messages = [ClaudeMessage(role: .user, content: prompt)]
        return try await sendMessage(
            messages: messages,
            systemPrompt: """
                You are a professional chef and recipe developer with deep knowledge of \
                global cuisines, dietary restrictions, and nutritional science. Generate \
                detailed, accurate recipes with precise measurements, clear step-by-step \
                instructions, and helpful cooking tips. Always consider food safety, \
                seasonal ingredients, and practical home cooking constraints.
                """
        )
    }

    func analyzeRecipeImage(imageBase64: String, prompt: String) async throws -> String {
        guard let apiKey else {
            throw AIServiceError.apiKeyMissing(provider: "Claude")
        }

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": imageBase64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
                ]
            ]
        ]

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "messages": messages
        ]

        let data = try await performRequest(
            endpoint: "messages",
            method: "POST",
            body: body,
            apiKey: apiKey
        )

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = response.content.first(where: { $0.type == "text" }) else {
            throw AIServiceError.emptyResponse
        }
        return textBlock.text ?? ""
    }

    func ingestRecipeFromText(_ text: String) async throws -> String {
        let messages = [ClaudeMessage(role: .user, content: """
            Parse the following recipe text and extract structured data including: \
            title, ingredients with amounts and units, step-by-step directions, \
            prep time, cook time, servings, cuisine type, and dietary information. \
            Format as JSON.

            Recipe text:
            \(text)
            """)]

        return try await sendMessage(
            messages: messages,
            systemPrompt: "You are a recipe parsing assistant. Extract structured recipe data from unstructured text. Always respond with valid JSON."
        )
    }

    // MARK: - Networking

    private func performRequest(
        endpoint: String,
        method: String,
        body: [String: Any],
        apiKey: String
    ) async throws -> Data {
        try await APIClient.request(
            url: baseURL.appendingPathComponent(endpoint),
            method: method,
            body: body,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": apiVersion,
            ]
        )
    }
}

// MARK: - Claude Message

struct ClaudeMessage: Sendable {
    enum Role: String, Sendable {
        case user, assistant
    }

    let role: Role
    let content: String

    func toDictionary() -> [String: Any] {
        ["role": role.rawValue, "content": content]
    }
}

// MARK: - Claude Response Types

struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    let model: String
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content, model
        case stopReason = "stop_reason"
    }

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
}
