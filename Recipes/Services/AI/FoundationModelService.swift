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

    // MARK: - General Text Generation

    /// Free-form text prompt using the cached session.
    /// Use this instead of creating a new LanguageModelSession() at the call site —
    /// each new session allocates 10-30 MB and is never freed until the session is deallocated.
    func respond(to prompt: String) async throws -> String {
        let session = session()
        let response = try await session.respond(to: prompt)
        return response.content
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

    // MARK: - OCR Text to Recipe Parsing

    /// Parse OCR-extracted text from a recipe image into structured recipe data.
    func parseRecipeFromOCRText(_ ocrText: String) async throws -> ParsedRecipeFromOCR {
        let session = session()

        let prompt = """
        Parse this text extracted from a recipe image (via OCR) into a structured recipe. \
        The text may contain OCR artifacts, line breaks in odd places, or partial words. \
        Do your best to interpret the recipe accurately.

        For canned/packaged goods like "1 (14 ounce) can sweetened condensed milk", \
        use the container count as the quantity — amount should be "1 can" and \
        name "sweetened condensed milk".

        OCR Text:
        \(ocrText)
        """

        return try await session.respond(to: prompt, generating: ParsedRecipeFromOCR.self).content
    }

    // MARK: - Recipe Generation from Description

    /// Generate a structured recipe from a user's natural-language request.
    func generateRecipeFromDescription(_ request: String) async throws -> ParsedRecipeFromOCR {
        let session = session()

        let prompt = """
        Generate a practical home-cooked recipe based on this request. \
        The recipe must match the request closely — if the user asked for chicken salad, \
        return a chicken salad recipe, not a different dish.

        Rules:
        - Use 10 or fewer everyday ingredients. No exotic or hard-to-find items.
        - Use precise measurements (cups, tablespoons, ounces) — never vague amounts like "some" or "a little".
        - Each ingredient should appear only ONCE in the list with its total amount. \
          If it's used at different stages, mention the split in the directions.
        - Treat these as the same ingredient: olive oil / extra-virgin olive oil; \
          salt / kosher salt / sea salt; butter / unsalted butter; onion / onions; \
          flour / all-purpose flour.
        - Write clear, numbered directions that a home cook can follow.
        - Every ingredient must be used in at least one direction step.
        - Every direction step should only reference ingredients from the list.

        Request: \(request)
        """

        return try await session.respond(to: prompt, generating: ParsedRecipeFromOCR.self).content
    }

    // MARK: - Text Recipe Parsing

    /// Parse user-provided recipe text (pasted, generated, etc.) into structured recipe data.
    func parseRecipeFromText(_ text: String) async throws -> ParsedRecipeFromOCR {
        let session = session()

        let prompt = """
        Parse this recipe text into a structured recipe. Extract the title, servings, \
        cuisine, timing, ingredients, directions, and any dietary labels.

        For canned/packaged goods like "1 (14 ounce) can sweetened condensed milk", \
        use the container count as the quantity — amount should be "1 can" and \
        name "sweetened condensed milk".

        Recipe text:
        \(text)
        """

        return try await session.respond(to: prompt, generating: ParsedRecipeFromOCR.self).content
    }

    // MARK: - Recipe Editing

    /// Apply a natural-language modification to a recipe on-device.
    func editRecipeOnDevice(recipeText: String, instruction: String) async throws -> ParsedRecipeFromOCR {
        let session = session()

        let prompt = """
        Modify the following recipe based on the user's request. \
        Make ONLY the changes needed to fulfil the request; keep everything else identical.

        Recipe:
        \(recipeText)

        User request: \(instruction)

        Return the complete updated recipe with all fields.
        """

        return try await session.respond(to: prompt, generating: ParsedRecipeFromOCR.self).content
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

// MARK: - Structured Recipe Types

@Generable
struct ParsedRecipeFromOCR {
    @Guide(description: "The name or title of the recipe")
    var title: String

    @Guide(description: "Number of servings the recipe makes, or 0 if not specified")
    var servings: Int

    @Guide(description: "The cuisine type such as italian, mexican, indian, american, etc.")
    var cuisine: String

    @Guide(description: "Estimated prep time in minutes, or 0 if not specified")
    var prepTimeMinutes: Int

    @Guide(description: "Estimated cook time in minutes, or 0 if not specified")
    var cookTimeMinutes: Int

    @Guide(description: "List of ingredients. Each ingredient appears only once with its total amount needed. Maximum 10 ingredients.")
    var ingredients: [ParsedOCRIngredient]

    @Guide(description: "Ordered list of clear, actionable cooking step instructions. Each step should reference specific ingredients and include times or temperatures where relevant.")
    var directions: [String]

    @Guide(description: "Dietary labels that apply such as vegetarian, vegan, glutenFree, dairyFree. Empty if none apply.")
    var dietaryInfo: [String]
}

@Generable
struct ParsedOCRIngredient {
    @Guide(description: "Name of the ingredient, e.g. 'chicken breast' or 'olive oil'")
    var name: String

    @Guide(description: "Precise amount with unit, e.g. '2 cups', '1 tablespoon', '1 lb'. Never use vague amounts like 'some' or 'to taste'.")
    var amount: String

    @Guide(description: "Preparation instructions such as 'diced' or 'melted', or empty string if none")
    var preparation: String
}
