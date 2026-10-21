import Foundation
import SwiftUI

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case apiKeyMissing(provider: String)
    case emptyResponse
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case onDeviceUnavailable
    case cloudRequiredForImages
    case allProvidersFailed([Error])

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing(let provider):
            return "\(provider) API key is not configured. Add it in Settings."
        case .emptyResponse:
            return "The AI service returned an empty response."
        case .invalidResponse:
            return "Received an invalid response from the AI service."
        case .httpError(let code, let data):
            let body = String(data: data, encoding: .utf8) ?? ""
            return "AI service HTTP \(code): \(body)"
        case .onDeviceUnavailable:
            return "On-device AI is not available on this device."
        case .cloudRequiredForImages:
            return "Photo analysis needs a cloud provider. Your AI setting is On-Device Only; switch to Hybrid, Claude, or OpenAI in Settings to analyze photos."
        case .allProvidersFailed(let errors):
            let detail = errors.map { $0.localizedDescription }.joined(separator: "; ")
            return "All AI providers failed. \(detail)"
        }
    }
}

// MARK: - AI Task Type

enum AITaskType {
    case recipeGeneration
    case nutritionalEstimation
    case ingredientSubstitution
    case recipeIngestion
    case imageAnalysis
    case stepInference
    case classification
    case blindSpotDetection
    case mealPlanGeneration
    case cookingOptimization
    case ingredientLookup
}

// MARK: - AI Service Router

/// Routes AI requests to the appropriate provider based on user preferences,
/// task type, and availability. Supports hybrid mode with on-device first,
/// cloud fallback.
@Observable
@MainActor
final class AIServiceRouter {
    let foundationModelService = FoundationModelService()
    let openAIService = OpenAIService()
    let claudeService = ClaudeService()

    /// Persisted across launches. Stored in UserDefaults rather than on UserProfile
    /// because the profile field pre-dates the picker and defaults to `.onDevice`,
    /// which would silently downgrade existing users.
    var preferredProvider: AIProvider {
        get { storedProvider }
        set {
            storedProvider = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.providerKey)
        }
    }
    private var storedProvider: AIProvider
    private static let providerKey = "ai_preferredProvider"

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.providerKey)
        storedProvider = stored.flatMap(AIProvider.init(rawValue:)) ?? .hybrid
    }

    /// Whether any cloud AI provider has an API key configured.
    var hasCloudProvider: Bool {
        claudeService.isConfigured || openAIService.isConfigured
    }

    /// The most recent prompt sent to any AI provider. Useful for debugging.
    var lastPrompt: String? = nil

    /// Route a text generation request to the best available provider.
    /// Pass `preferFast: true` for structured/mechanical tasks where speed matters more than quality.
    func generateText(
        prompt: String,
        taskType: AITaskType,
        provider: AIProvider? = nil,
        preferFast: Bool = false
    ) async throws -> String {
        lastPrompt = prompt
        let target = provider ?? preferredProvider
        let claudeModel = preferFast ? "claude-haiku-4-5-20251001" : "claude-sonnet-4-6"

        switch target {
        case .onDevice:
            return try await useOnDevice(prompt: prompt, taskType: taskType)

        case .claude:
            return try await claudeService.sendMessage(
                messages: [ClaudeMessage(role: .user, content: prompt)],
                model: claudeModel
            )

        case .openAI:
            return try await openAIService.generateRecipe(prompt: prompt)

        case .hybrid:
            return try await hybridGeneration(prompt: prompt, taskType: taskType, preferFast: preferFast)
        }
    }

    /// Streaming variant — tries on-device first (as a single chunk), then Claude streaming,
    /// then wraps other providers in a single-chunk stream.
    func generateTextStreaming(
        prompt: String,
        taskType: AITaskType
    ) -> AsyncThrowingStream<String, Error> {
        lastPrompt = prompt
        // Try on-device first for suitable tasks when in hybrid or onDevice mode
        let useOnDeviceForTask = !Self.largeContextTasks.contains(taskType)
        if useOnDeviceForTask && (preferredProvider == .hybrid || preferredProvider == .onDevice) {
            return AsyncThrowingStream { continuation in
                let task = Task { @MainActor [weak self] in
                    guard let self else { continuation.finish(); return }
                    // Attempt on-device generation
                    if await self.foundationModelService.isAvailable {
                        do {
                            let result = try await self.foundationModelService.respond(to: prompt)
                            if Self.jsonTasks.contains(taskType), !Self.looksLikeJSON(result) {
                                throw AIServiceError.invalidResponse
                            }
                            continuation.yield(result)
                            continuation.finish()
                            return
                        } catch {
                            // On-Device Only: surface the failure instead of quietly
                            // sending the prompt to a cloud provider.
                            if self.preferredProvider == .onDevice {
                                continuation.finish(throwing: error)
                                return
                            }
                            // Hybrid: fall through to cloud
                        }
                    } else if self.preferredProvider == .onDevice {
                        continuation.finish(throwing: AIServiceError.onDeviceUnavailable)
                        return
                    }
                    // Fall back to cloud streaming or single-chunk
                    if self.claudeService.isConfigured {
                        do {
                            let stream = self.claudeService.sendMessageStreaming(
                                messages: [ClaudeMessage(role: .user, content: prompt)],
                                systemPrompt: """
                                    You are a helpful home cooking assistant. Generate practical, approachable \
                                    recipes that real people actually cook at home — not restaurant food. \
                                    Use straightforward ingredients and techniques. Recipes should be satisfying \
                                    and delicious without being overly complex. Always respond with valid JSON.
                                    """
                            )
                            for try await chunk in stream {
                                continuation.yield(chunk)
                            }
                            continuation.finish()
                            return
                        } catch {
                            // Claude failed — try other providers
                        }
                    }
                    do {
                        let result = try await self.generateText(prompt: prompt, taskType: taskType)
                        continuation.yield(result)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        // Direct cloud streaming when cloud provider is explicitly selected
        if claudeService.isConfigured {
            return claudeService.sendMessageStreaming(
                messages: [ClaudeMessage(role: .user, content: prompt)],
                systemPrompt: """
                    You are a helpful home cooking assistant. Generate practical, approachable \
                    recipes that real people actually cook at home — not restaurant food. \
                    Use straightforward ingredients and techniques. Recipes should be satisfying \
                    and delicious without being overly complex. Always respond with valid JSON.
                    """
            )
        }
        // Wrap non-streaming providers in a single-chunk stream.
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else { continuation.finish(); return }
                do {
                    let result = try await self.generateText(prompt: prompt, taskType: taskType)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Analyze an image using a cloud provider (vision not available on-device).
    func analyzeImage(
        imageBase64: String,
        prompt: String,
        provider: AIProvider? = nil
    ) async throws -> String {
        let target = provider ?? preferredProvider

        switch target {
        case .claude where claudeService.isConfigured:
            return try await claudeService.analyzeRecipeImage(imageBase64: imageBase64, prompt: prompt)

        case .openAI where openAIService.isConfigured:
            return try await openAIService.analyzeImage(imageBase64: imageBase64, prompt: prompt)

        case .onDevice:
            // Apple's on-device model has no vision path. Honour the user's choice
            // rather than silently uploading the photo.
            throw AIServiceError.cloudRequiredForImages

        case .hybrid:
            // Prefer Claude for image analysis, fall back to OpenAI
            if claudeService.isConfigured {
                return try await claudeService.analyzeRecipeImage(imageBase64: imageBase64, prompt: prompt)
            } else if openAIService.isConfigured {
                return try await openAIService.analyzeImage(imageBase64: imageBase64, prompt: prompt)
            }
            throw AIServiceError.apiKeyMissing(provider: "Claude or OpenAI")

        case .claude:
            throw AIServiceError.apiKeyMissing(provider: "Claude")

        case .openAI:
            throw AIServiceError.apiKeyMissing(provider: "OpenAI")
        }
    }

    // MARK: - Private

    private func useOnDevice(prompt: String, taskType: AITaskType) async throws -> String {
        guard await foundationModelService.isAvailable else {
            throw AIServiceError.onDeviceUnavailable
        }
        // Use the service's cached session — never create LanguageModelSession() directly
        // here, as each fresh allocation costs 10-30 MB that isn't freed until the session
        // is released. The service keeps one session alive for the app's lifetime.
        return try await foundationModelService.respond(to: prompt)
    }

    /// Task types where on-device inference is unsuitable due to large context or strict JSON schema requirements.
    /// These always go to a cloud provider — on-device models ignore complex prompts and return prose instead of JSON.
    private static let largeContextTasks: Set<AITaskType> = [
        .imageAnalysis,     // vision not available on-device
        .mealPlanGeneration // complex JSON schema; on-device returns prose
    ]

    /// Tasks whose callers parse the reply as JSON. An on-device answer that isn't
    /// JSON is treated as a failure so Hybrid mode can fall through to the cloud
    /// instead of handing prose to a JSON decoder.
    private static let jsonTasks: Set<AITaskType> = [
        .recipeIngestion, .classification, .nutritionalEstimation,
        .ingredientLookup, .mealPlanGeneration, .cookingOptimization,
    ]

    /// True when `text` contains a JSON object or array that actually parses.
    static func looksLikeJSON(_ text: String) -> Bool {
        let stripped = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        guard let start = stripped.firstIndex(where: { $0 == "{" || $0 == "[" }) else { return false }
        let closer: Character = stripped[start] == "{" ? "}" : "]"
        guard let end = stripped.lastIndex(of: closer), end > start,
              let data = String(stripped[start...end]).data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// On-device call that fails when a JSON task gets a non-JSON answer.
    private func useOnDeviceValidated(prompt: String, taskType: AITaskType) async throws -> String {
        let result = try await useOnDevice(prompt: prompt, taskType: taskType)
        if Self.jsonTasks.contains(taskType), !Self.looksLikeJSON(result) {
            throw AIServiceError.invalidResponse
        }
        return result
    }

    /// Try on-device first, fall back to cloud providers.
    private func hybridGeneration(prompt: String, taskType: AITaskType, preferFast: Bool = false) async throws -> String {
        var errors: [Error] = []
        let claudeModel = preferFast ? "claude-haiku-4-5-20251001" : "claude-sonnet-4-6"

        // Skip on-device for large-context tasks — the prompt is too big for the local model
        let useOnDeviceForTask = !Self.largeContextTasks.contains(taskType)
        if useOnDeviceForTask, await foundationModelService.isAvailable {
            do {
                return try await useOnDeviceValidated(prompt: prompt, taskType: taskType)
            } catch {
                errors.append(error)
            }
        }

        // Try Claude
        if claudeService.isConfigured {
            do {
                return try await claudeService.sendMessage(
                    messages: [ClaudeMessage(role: .user, content: prompt)],
                    model: claudeModel
                )
            } catch {
                errors.append(error)
            }
        }

        // Try OpenAI
        if openAIService.isConfigured {
            do {
                return try await openAIService.generateRecipe(prompt: prompt)
            } catch {
                errors.append(error)
            }
        }

        throw AIServiceError.allProvidersFailed(errors)
    }
}

// Need this import for LanguageModelSession in the router
import FoundationModels

// MARK: - AI Input Sanitizer

/// Sanitizes user-controlled text before embedding it in AI prompts,
/// preventing prompt-injection attacks where user input overrides system instructions.
enum AIInputSanitizer {

    /// Default cap for user-typed text. Callers embedding scraped pages pass a larger limit.
    static let defaultMaxLength = 2_000

    private static let injectionPatterns: [String] = [
        "ignore previous instructions", "ignore all previous",
        "disregard the above", "forget all previous",
        "new instructions:", "system prompt:",
        "you are now", "act as if you are",
        "pretend you are", "from now on you",
        "override instructions",
    ]

    static func sanitize(_ input: String, maxLength: Int = defaultMaxLength) -> String {
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Neutralise the phrase, not the whole line: a recipe step like
        // "once you are now ready, drain the pasta" must survive.
        for pattern in injectionPatterns {
            result = result.replacingOccurrences(of: pattern, with: "[…]", options: [.caseInsensitive])
        }
        if result.count > maxLength {
            let index = result.index(result.startIndex, offsetBy: maxLength)
            result = String(result[..<index]) + "…"
        }
        return result
    }
}

private struct AIRouterKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = AIServiceRouter()
}

extension EnvironmentValues {
    var aiRouter: AIServiceRouter {
        get { self[AIRouterKey.self] }
        set { self[AIRouterKey.self] = newValue }
    }
}

extension String {
    /// Returns this string sanitized for safe embedding in an AI prompt.
    var sanitizedForAI: String { AIInputSanitizer.sanitize(self) }

    /// Sanitized with an explicit length cap, for long scraped content.
    func sanitizedForAI(maxLength: Int) -> String { AIInputSanitizer.sanitize(self, maxLength: maxLength) }
}
