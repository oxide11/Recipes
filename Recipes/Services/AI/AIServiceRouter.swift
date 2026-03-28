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
        case .httpError(let code, _):
            return "AI service request failed with status code \(code)."
        case .onDeviceUnavailable:
            return "On-device AI is not available on this device."
        case .allProvidersFailed:
            return "All AI providers failed to process the request."
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
    func generateText(
        prompt: String,
        taskType: AITaskType,
        provider: AIProvider? = nil
    ) async throws -> String {
        let target = provider ?? preferredProvider

        switch target {
        case .onDevice:
            return try await useOnDevice(prompt: prompt, taskType: taskType)

        case .claude:
            return try await claudeService.generateRecipe(prompt: prompt)

        case .openAI:
            return try await openAIService.generateRecipe(prompt: prompt)

        case .hybrid:
            return try await hybridGeneration(prompt: prompt, taskType: taskType)
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

    /// Try on-device first, fall back to cloud providers.
    private func hybridGeneration(prompt: String, taskType: AITaskType) async throws -> String {
        // Try on-device first
        if await foundationModelService.isAvailable {
            do {
                return try await useOnDevice(prompt: prompt, taskType: taskType)
            } catch {
                // Fall through to cloud
            }
        }

        // Try Claude
        if claudeService.isConfigured {
            do {
                return try await claudeService.generateRecipe(prompt: prompt)
            } catch {
                // Fall through
            }
        }

        // Try OpenAI
        if openAIService.isConfigured {
            return try await openAIService.generateRecipe(prompt: prompt)
        }

        throw AIServiceError.allProvidersFailed([])
    }
}

// Need this import for LanguageModelSession in the router
import FoundationModels
