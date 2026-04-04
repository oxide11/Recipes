import Foundation

// MARK: - OpenAI Service

/// Integrates with the OpenAI API for cloud-based AI capabilities.
/// Requires user-provided API key stored securely in Keychain.
@Observable
@MainActor
final class OpenAIService {
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    var apiKey: String? {
        KeychainService.retrieve(key: .openAIAPIKey)
    }

    var isConfigured: Bool {
        apiKey != nil && !(apiKey?.isEmpty ?? true)
    }

    // MARK: - Chat Completion

    func chatCompletion(
        messages: [ChatMessage],
        model: String = "gpt-4o",
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) async throws -> String {
        guard let apiKey else {
            throw AIServiceError.apiKeyMissing(provider: "OpenAI")
        }

        var body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "messages": messages.map { $0.toDictionary() }
        ]
        if let maxTokens {
            body["max_tokens"] = maxTokens
        }

        let data = try await performRequest(
            endpoint: "chat/completions",
            method: "POST",
            body: body,
            apiKey: apiKey
        )

        let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }
        return content
    }

    // MARK: - Recipe-Specific Methods

    func generateRecipe(prompt: String) async throws -> String {
        let messages = [
            ChatMessage(role: .system, content: """
                You are a helpful home cooking assistant. Generate practical, approachable \
                recipes that real people actually cook at home — not restaurant food. \
                Use straightforward ingredients and techniques. Recipes should be satisfying \
                and delicious without being overly complex. Include nutritional estimates when asked.
                """),
            ChatMessage(role: .user, content: prompt)
        ]
        return try await chatCompletion(messages: messages)
    }

    func analyzeImage(imageBase64: String, prompt: String) async throws -> String {
        guard let apiKey else {
            throw AIServiceError.apiKeyMissing(provider: "OpenAI")
        }

        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                ]
            ]
        ]

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
            "max_tokens": 2000
        ]

        let data = try await performRequest(
            endpoint: "chat/completions",
            method: "POST",
            body: body,
            apiKey: apiKey
        )

        let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw AIServiceError.emptyResponse
        }
        return content
    }

    // MARK: - Networking

    private func performRequest(
        endpoint: String,
        method: String,
        body: [String: Any],
        apiKey: String
    ) async throws -> Data {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await APIClient.request(
            url: baseURL.appendingPathComponent(endpoint),
            method: method,
            bodyData: bodyData,
            headers: ["Authorization": "Bearer \(apiKey)"]
        )
    }
}

// MARK: - Chat Message

struct ChatMessage: Sendable {
    enum Role: String, Sendable {
        case system, user, assistant
    }

    let role: Role
    let content: String

    func toDictionary() -> [String: String] {
        ["role": role.rawValue, "content": content]
    }
}

// MARK: - OpenAI Response Types

struct OpenAIChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
