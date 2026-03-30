import Foundation
import FoundationModels

// MARK: - Apple Foundation Model Service

/// Provides on-device AI capabilities using Apple's FoundationModels framework (iOS 26+).
/// Handles recipe generation, nutritional estimation, ingredient substitution,
/// and step inference — all processed locally on the device.
@Observable
@MainActor
final class FoundationModelService {

    /// Reusable session to avoid repeated allocation overhead.
    private var cachedSession: LanguageModelSession?

    private func session() -> LanguageModelSession {
        if let cachedSession { return cachedSession }
        let newSession = LanguageModelSession()
        cachedSession = newSession
        return newSession
    }

    /// Check device eligibility for on-device foundation models.
    var isAvailable: Bool {
        get async {
            let availability = SystemLanguageModel.default.availability
            return availability == .available
        }
    }

    // MARK: - Recipe Generation

    /// Generate a recipe from a list of available ingredients.
    func generateRecipe(
        from ingredients: [String],
        cuisine: Cuisine? = nil,
        maxTimeMinutes: Int? = nil,
        dietaryRestrictions: [DietaryRestriction] = []
    ) async throws -> GeneratedRecipe {
        let session = session()

        var prompt = "Generate a recipe using these ingredients: \(ingredients.joined(separator: ", "))."
        if let cuisine { prompt += " Cuisine style: \(cuisine.rawValue)." }
        if let maxTime = maxTimeMinutes { prompt += " Must be ready in \(maxTime) minutes or less." }
        if !dietaryRestrictions.isEmpty {
            prompt += " Dietary restrictions: \(dietaryRestrictions.map(\.rawValue).joined(separator: ", "))."
        }

        let response = try await session.respond(to: prompt, generating: GeneratedRecipe.self)
        return response.content
    }

    // MARK: - Nutritional Estimation

    /// Estimate nutritional information for a recipe using on-device AI.
    func estimateNutrition(
        ingredients: [String],
        servings: Int
    ) async throws -> NutritionalEstimate {
        let session = session()

        let prompt = """
        Estimate the nutritional information per serving for a recipe with \(servings) servings \
        using these ingredients: \(ingredients.joined(separator: ", ")).
        """

        return try await session.respond(to: prompt, generating: NutritionalEstimate.self).content
    }

    // MARK: - Ingredient Substitution

    /// Suggest substitutions for ingredients based on dietary restrictions or availability.
    func suggestSubstitutions(
        for ingredient: String,
        reason: String,
        context: String
    ) async throws -> SubstitutionSuggestions {
        let session = session()

        let prompt = """
        Suggest substitutions for "\(ingredient)" in the context of: \(context). \
        Reason for substitution: \(reason).
        """

        return try await session.respond(to: prompt, generating: SubstitutionSuggestions.self).content
    }

    // MARK: - Recipe Step Inference (Recipe as Code)

    /// Infer cooking steps from a declarative recipe definition.
    func inferSteps(from definition: RecipeDefinition) async throws -> InferredRecipeSteps {
        let session = session()

        let ingredientList = definition.ingredients
            .map { "\($0.name): \($0.amount)\($0.preparation.map { ", \($0)" } ?? "")" }
            .joined(separator: "\n  - ")

        let outcomeList = definition.outcomes.joined(separator: "\n  - ")

        let prompt = """
        Given this recipe definition, infer the detailed cooking steps:

        Title: \(definition.title)
        Servings: \(definition.servings ?? 4)
        Ingredients:
          - \(ingredientList)
        Desired outcomes:
          - \(outcomeList)
        \(definition.equipment.map { "Equipment: \($0.joined(separator: ", "))" } ?? "")

        Provide step-by-step cooking instructions that achieve all the desired outcomes.
        """

        return try await session.respond(to: prompt, generating: InferredRecipeSteps.self).content
    }

    // MARK: - Recipe Classification & Recommendation

    /// Classify a recipe image or description for recommendation purposes.
    func classifyForRecommendation(
        recipeTitle: String,
        ingredients: [String],
        userHistory: String
    ) async throws -> RecipeClassification {
        let session = session()

        let prompt = """
        Classify this recipe for personalized recommendations.
        Recipe: \(recipeTitle)
        Ingredients: \(ingredients.joined(separator: ", "))
        User cooking history summary: \(userHistory)
        """

        return try await session.respond(to: prompt, generating: RecipeClassification.self).content
    }

    // MARK: - Blind Spot Detection

    /// Suggest recipes the user hasn't tried based on their cooking history.
    func suggestBlindSpots(
        cookedCuisines: [String],
        cookedIngredients: [String],
        preferences: String
    ) async throws -> BlindSpotSuggestions {
        let session = session()

        let prompt = """
        The user frequently cooks: \(cookedCuisines.joined(separator: ", ")).
        Common ingredients: \(cookedIngredients.joined(separator: ", ")).
        Preferences: \(preferences).

        Suggest cuisines, techniques, and recipes they haven't explored yet.
        """

        return try await session.respond(to: prompt, generating: BlindSpotSuggestions.self).content
    }
}

// MARK: - Generable Types for Structured Output

@Generable
struct GeneratedRecipe {
    @Guide(description: "The name of the recipe")
    var title: String

    @Guide(description: "Brief description of the dish")
    var summary: String

    @Guide(description: "Cuisine type")
    var cuisine: String

    @Guide(description: "Estimated prep time in minutes")
    var prepTimeMinutes: Int

    @Guide(description: "Estimated cook time in minutes")
    var cookTimeMinutes: Int

    @Guide(description: "Number of servings")
    var servings: Int

    @Guide(description: "Ordered list of cooking step instructions")
    var steps: [String]
}

@Generable
struct SubstitutionSuggestions {
    @Guide(description: "List of possible ingredient substitutions")
    var substitutions: [SubstitutionOption]
}

@Generable
struct SubstitutionOption {
    @Guide(description: "Name of the substitute ingredient")
    var ingredient: String

    @Guide(description: "Amount to use as a replacement")
    var amount: String

    @Guide(description: "How this substitution affects the dish")
    var impactNote: String

    @Guide(description: "Confidence that this substitution works well, from 1 to 10")
    var confidence: Int
}

@Generable
struct RecipeClassification {
    @Guide(description: "Primary cuisine category")
    var cuisine: String

    @Guide(description: "Cooking techniques used")
    var techniques: [String]

    @Guide(description: "Flavor profile descriptors")
    var flavorProfile: [String]

    @Guide(description: "How likely the user will enjoy this recipe, from 1 to 10")
    var recommendationScore: Int
}

@Generable
struct BlindSpotSuggestions {
    @Guide(description: "Cuisines the user should explore")
    var unexploredCuisines: [String]

    @Guide(description: "Cooking techniques the user hasn't tried")
    var newTechniques: [String]

    @Guide(description: "Specific recipe ideas to broaden their repertoire")
    var recipeIdeas: [String]
}
