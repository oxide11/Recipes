import Foundation

// MARK: - AI Service Error

enum AIServiceError: LocalizedError {
    case apiKeyMissing(provider: String)
    case emptyResponse
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case onDeviceUnavailable
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

    var preferredProvider: AIProvider = .hybrid

    /// Whether any cloud AI provider has an API key configured.
    var hasCloudProvider: Bool {
        claudeService.isConfigured || openAIService.isConfigured
    }

    /// Route a text generation request to the best available provider.
    /// Pass `preferFast: true` for structured/mechanical tasks where speed matters more than quality.
    func generateText(
        prompt: String,
        taskType: AITaskType,
        provider: AIProvider? = nil,
        preferFast: Bool = false
    ) async throws -> String {
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
                            continuation.yield(result)
                            continuation.finish()
                            return
                        } catch {
                            // On-device failed — fall through to cloud
                        }
                    }
                    // Fall back to cloud streaming or single-chunk
                    if self.claudeService.isConfigured {
                        do {
                            let stream = self.claudeService.sendMessageStreaming(
                                messages: [ClaudeMessage(role: .user, content: prompt)],
                                systemPrompt: """
                                    You are a professional chef and recipe developer with deep knowledge of \
                                    global cuisines, dietary restrictions, and nutritional science. Generate \
                                    detailed, accurate recipes with precise measurements and clear step-by-step \
                                    instructions. Always respond with valid JSON.
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
                    You are a professional chef and recipe developer with deep knowledge of \
                    global cuisines, dietary restrictions, and nutritional science. Generate \
                    detailed, accurate recipes with precise measurements and clear step-by-step \
                    instructions. Always respond with valid JSON.
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

        case .hybrid, .onDevice:
            // Prefer Claude for image analysis, fall back to OpenAI
            if claudeService.isConfigured {
                return try await claudeService.analyzeRecipeImage(imageBase64: imageBase64, prompt: prompt)
            } else if openAIService.isConfigured {
                return try await openAIService.analyzeImage(imageBase64: imageBase64, prompt: prompt)
            }
            throw AIServiceError.apiKeyMissing(provider: "Claude or OpenAI")

        default:
            throw AIServiceError.apiKeyMissing(provider: target.rawValue)
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

    /// Task types where on-device inference is unsuitable due to large context requirements.
    private static let largeContextTasks: Set<AITaskType> = [.imageAnalysis]

    /// Try on-device first, fall back to cloud providers.
    private func hybridGeneration(prompt: String, taskType: AITaskType, preferFast: Bool = false) async throws -> String {
        var errors: [Error] = []
        let claudeModel = preferFast ? "claude-haiku-4-5-20251001" : "claude-sonnet-4-6"

        // Skip on-device for large-context tasks — the prompt is too big for the local model
        let useOnDeviceForTask = !Self.largeContextTasks.contains(taskType)
        if useOnDeviceForTask, await foundationModelService.isAvailable {
            do {
                return try await useOnDevice(prompt: prompt, taskType: taskType)
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

    private static let maxLength = 2_000

    private static let injectionPatterns: [String] = [
        "ignore previous instructions", "ignore all previous",
        "disregard the above", "forget all previous",
        "new instructions:", "system prompt:",
        "you are now", "act as if you are",
        "pretend you are", "from now on you",
        "override instructions",
    ]

    static func sanitize(_ input: String) -> String {
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = result.components(separatedBy: .newlines)
        result = lines
            .filter { line in
                let lower = line.lowercased()
                return !injectionPatterns.contains(where: { lower.contains($0) })
            }
            .joined(separator: "\n")
        if result.count > maxLength {
            let index = result.index(result.startIndex, offsetBy: maxLength)
            result = String(result[..<index]) + "…"
        }
        return result
    }
}

extension String {
    /// Returns this string sanitized for safe embedding in an AI prompt.
    var sanitizedForAI: String { AIInputSanitizer.sanitize(self) }
}
