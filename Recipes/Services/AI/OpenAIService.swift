import Foundation

// MARK: - OpenAI Service

/// Integrates with the OpenAI API for cloud-based AI capabilities.
/// Requires user-provided API key stored securely in Keychain.
@Observable
@MainActor
final class OpenAIService {
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    private let session = URLSession.shared

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
                You are a professional chef and recipe developer. Generate detailed, \
                accurate recipes with precise measurements, clear instructions, and \
                helpful tips. Include nutritional estimates when asked.
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
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        return data
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
