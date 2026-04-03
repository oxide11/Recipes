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

    /// Streaming variant — yields text chunks as Claude generates them.
    /// Falls back to a single-chunk stream for other providers.
    func generateTextStreaming(
        prompt: String,
        taskType: AITaskType
    ) -> AsyncThrowingStream<String, Error> {
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
        // Store the Task so it's cancelled if the stream consumer disposes early.
        return AsyncThrowingStream { continuation in
            let task = Task { @MainActor in
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

        // For on-device, use the FoundationModels session directly for text
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }

    /// Task types where on-device inference is unsuitable due to large context requirements.
    private static let largeContextTasks: Set<AITaskType> = [.recipeIngestion, .imageAnalysis]

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
