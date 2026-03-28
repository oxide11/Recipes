import Foundation

// MARK: - Recipe Ingestion Service

/// Pipeline for importing recipes from various sources:
/// URLs, plain text, markdown, images, and Recipe-as-Code definitions.
@Observable
final class RecipeIngestionService {
    private let aiRouter: AIServiceRouter

    init(aiRouter: AIServiceRouter) {
        self.aiRouter = aiRouter
    }

    // MARK: - Ingest from URL

    func ingestFromURL(_ url: URL) async throws -> RecipeIngestionResult {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw IngestionError.invalidContent
        }

        let prompt = """
        Extract a complete recipe from this webpage content. \
        Parse the title, ingredients with amounts, step-by-step directions, \
        prep time, cook time, servings, and any nutritional information. \
        Respond with structured JSON.

        Content:
        \(html.prefix(8000))
        """

        let response = try await aiRouter.generateText(
            prompt: prompt,
            taskType: .recipeIngestion
        )

        return try parseIngestionResponse(response, source: url.absoluteString)
    }

    // MARK: - Ingest from Text / Markdown

    func ingestFromText(_ text: String) async throws -> RecipeIngestionResult {
        let prompt = """
        Parse this recipe text and extract structured data. Include: \
        title, ingredients with precise amounts and units, step-by-step directions, \
        prep time, cook time, servings, cuisine type, and dietary information. \
        Respond with structured JSON.

        Recipe:
        \(text)
        """

        let response = try await aiRouter.generateText(
            prompt: prompt,
            taskType: .recipeIngestion
        )

        return try parseIngestionResponse(response, source: "text")
    }

    // MARK: - Ingest from Image

    func ingestFromImage(_ imageData: Data) async throws -> RecipeIngestionResult {
        let base64 = imageData.base64EncodedString()

        let response = try await aiRouter.analyzeImage(
            imageBase64: base64,
            prompt: """
            Extract the complete recipe from this image. Include the title, \
            all ingredients with measurements, step-by-step directions, and \
            any other relevant details. Respond with structured JSON.
            """
        )

        return try parseIngestionResponse(response, source: "image")
    }

    // MARK: - Ingest from Recipe-as-Code

    func ingestFromRecipeCode(_ text: String) async throws -> RecipeIngestionResult {
        let definition = try RecipeDefinitionParser.parse(from: text)

        let foundationService = aiRouter.foundationModelService
        let isOnDevice = await foundationService.isAvailable

        var steps: InferredRecipeSteps?
        if isOnDevice {
            steps = try await foundationService.inferSteps(from: definition)
        }

        return RecipeIngestionResult(
            title: definition.title,
            servings: definition.servings ?? 4,
            cuisine: definition.cuisine,
            ingredients: definition.ingredients.map {
                .init(name: $0.name, amount: $0.amount, preparation: $0.preparation)
            },
            directions: steps?.steps.map { $0.instruction } ?? [],
            prepTimeMinutes: steps?.estimatedPrepMinutes,
            cookTimeMinutes: steps?.estimatedCookMinutes,
            source: "recipe-as-code"
        )
    }

    // MARK: - Private

    private func parseIngestionResponse(_ json: String, source: String) throws -> RecipeIngestionResult {
        // Extract JSON from possible markdown code fences
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw IngestionError.parsingFailed
        }

        var result = try JSONDecoder().decode(RecipeIngestionResult.self, from: data)
        result.source = source
        return result
    }
}

// MARK: - Ingestion Result

struct RecipeIngestionResult: Codable {
    var title: String
    var servings: Int?
    var cuisine: String?
    var ingredients: [ParsedIngredient]
    var directions: [String]
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var source: String?

    struct ParsedIngredient: Codable {
        var name: String
        var amount: String
        var preparation: String?
    }
}

// MARK: - Ingestion Error

enum IngestionError: LocalizedError {
    case invalidContent
    case parsingFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidContent:    return "Unable to read the recipe content."
        case .parsingFailed:     return "Failed to parse the recipe data."
        case .unsupportedFormat: return "This recipe format is not supported."
        }
    }
}
