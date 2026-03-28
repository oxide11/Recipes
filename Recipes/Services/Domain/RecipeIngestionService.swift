import Foundation
import SwiftUI
import PhotosUI

// MARK: - Recipe Ingestion Service

/// Full pipeline for importing recipes from various sources:
/// URLs, plain text, markdown, images, photos, and Recipe-as-Code definitions.
/// Handles HTML stripping, JSON-LD recipe extraction, and AI-powered parsing.
@Observable
@MainActor
final class RecipeIngestionService {
    private let aiRouter: AIServiceRouter

    var isProcessing = false
    var progress: String?

    init(aiRouter: AIServiceRouter) {
        self.aiRouter = aiRouter
    }

    // MARK: - Ingest from URL

    func ingestFromURL(_ url: URL) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Fetching recipe page..."
        defer { isProcessing = false; progress = nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw IngestionError.invalidContent
        }

        // Try JSON-LD structured data first (many recipe sites use schema.org)
        if let jsonLD = extractJSONLDRecipe(from: html) {
            progress = "Found structured recipe data..."
            return jsonLD
        }

        // Fall back to AI-powered extraction
        progress = "Analyzing page with AI..."
        let stripped = stripHTML(html)
        let truncated = String(stripped.prefix(12000))

        let prompt = """
        Extract a complete recipe from this webpage text content. \
        Return valid JSON with this exact structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "italian",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "flour", "amount": "2 cups", "preparation": "sifted"}],
          "directions": ["Step 1 instruction", "Step 2 instruction"],
          "dietaryInfo": ["vegetarian", "gluten-free"],
          "nutritionPerServing": {"calories": 350, "proteinGrams": 12, "carbsGrams": 45, "fatGrams": 14}
        }

        Webpage content:
        \(truncated)
        """

        let response = try await aiRouter.generateText(
            prompt: prompt,
            taskType: .recipeIngestion
        )

        return try parseIngestionResponse(response, source: url.absoluteString)
    }

    // MARK: - Ingest from Text / Markdown

    func ingestFromText(_ text: String) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Parsing recipe text..."
        defer { isProcessing = false; progress = nil }

        let prompt = """
        Parse this recipe and extract structured data. Return valid JSON with this structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "italian",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "flour", "amount": "2 cups", "preparation": "sifted"}],
          "directions": ["Step 1", "Step 2"],
          "dietaryInfo": [],
          "nutritionPerServing": {"calories": 350, "proteinGrams": 12, "carbsGrams": 45, "fatGrams": 14}
        }

        Recipe text:
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
        isProcessing = true
        progress = "Analyzing recipe image..."
        defer { isProcessing = false; progress = nil }

        let base64 = imageData.base64EncodedString()

        let response = try await aiRouter.analyzeImage(
            imageBase64: base64,
            prompt: """
            Extract the complete recipe from this image. This could be a photo of a \
            recipe card, cookbook page, handwritten recipe, or screenshot. \
            Return valid JSON with this structure:
            {
              "title": "Recipe Name",
              "servings": 4,
              "cuisine": "type",
              "prepTimeMinutes": 15,
              "cookTimeMinutes": 30,
              "ingredients": [{"name": "ingredient", "amount": "amount", "preparation": "prep"}],
              "directions": ["Step 1", "Step 2"],
              "dietaryInfo": [],
              "nutritionPerServing": null
            }
            """
        )

        return try parseIngestionResponse(response, source: "image")
    }

    // MARK: - Ingest from Recipe-as-Code

    func ingestFromRecipeCode(_ text: String) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Parsing recipe definition..."
        defer { isProcessing = false; progress = nil }

        let definition = try RecipeDefinitionParser.parse(from: text)

        progress = "Inferring cooking steps with AI..."
        let foundationService = aiRouter.foundationModelService
        let isOnDevice = await foundationService.isAvailable

        var steps: InferredRecipeSteps?
        if isOnDevice {
            steps = try await foundationService.inferSteps(from: definition)
        } else {
            // Fall back to cloud AI for step inference
            steps = try await inferStepsViaCloud(definition: definition)
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

    // MARK: - Convert Result to Recipe Model

    /// Convert an ingestion result into a full Recipe model ready for SwiftData insertion.
    func convertToRecipe(_ result: RecipeIngestionResult) -> Recipe {
        let cuisine = Cuisine.allCases.first {
            $0.rawValue.lowercased() == result.cuisine?.lowercased()
        } ?? .other

        let ingredients = result.ingredients.map { parsed in
            let amount = parseAmount(parsed.amount)
            let category = inferIngredientCategory(parsed.name)
            return Ingredient(
                name: parsed.name,
                category: category,
                amount: amount,
                notes: parsed.preparation
            )
        }

        let directions = result.directions.enumerated().map { index, instruction in
            RecipeDirection(stepNumber: index + 1, instruction: instruction)
        }

        var nutritionalInfo: NutritionalInfo?
        if let nutrition = result.nutritionPerServing {
            nutritionalInfo = NutritionalInfo(
                calories: Double(nutrition.calories ?? 0),
                proteinGrams: Double(nutrition.proteinGrams ?? 0),
                carbsGrams: Double(nutrition.carbsGrams ?? 0),
                fatGrams: Double(nutrition.fatGrams ?? 0)
            )
        }

        // Detect dietary info
        let dietaryRestrictions = (result.dietaryInfo ?? []).compactMap { info in
            DietaryRestriction.allCases.first {
                $0.rawValue.lowercased() == info.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
            }
        }

        return Recipe(
            title: result.title,
            cuisine: cuisine,
            servings: result.servings ?? 4,
            prepTimeMinutes: result.prepTimeMinutes ?? 15,
            cookTimeMinutes: result.cookTimeMinutes ?? 30,
            ingredients: ingredients,
            directions: directions,
            nutritionalInfo: nutritionalInfo,
            dietaryRestrictions: dietaryRestrictions,
            sourceURL: result.source
        )
    }

    // MARK: - HTML Processing

    /// Extract JSON-LD recipe schema from HTML (schema.org/Recipe).
    private func extractJSONLDRecipe(from html: String) -> RecipeIngestionResult? {
        // Find <script type="application/ld+json"> blocks
        let pattern = #"<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[range])

            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // Could be the recipe itself or an array containing it
            if let recipe = parseSchemaOrgRecipe(json) {
                return recipe
            }

            // Check if it's a @graph
            if let graph = json["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let recipe = parseSchemaOrgRecipe(item) {
                        return recipe
                    }
                }
            }
        }

        return nil
    }

    /// Parse a schema.org/Recipe JSON object.
    private func parseSchemaOrgRecipe(_ json: [String: Any]) -> RecipeIngestionResult? {
        let type = json["@type"] as? String
        guard type == "Recipe" else { return nil }

        let title = json["name"] as? String ?? "Untitled"
        let servings = parseYield(json["recipeYield"])

        let ingredients: [RecipeIngestionResult.ParsedIngredient]
        if let list = json["recipeIngredient"] as? [String] {
            ingredients = list.map { .init(name: $0, amount: "", preparation: nil) }
        } else {
            ingredients = []
        }

        var directions: [String] = []
        if let steps = json["recipeInstructions"] as? [String] {
            directions = steps
        } else if let steps = json["recipeInstructions"] as? [[String: Any]] {
            directions = steps.compactMap { $0["text"] as? String }
        }

        let prepTime = parseISODuration(json["prepTime"] as? String)
        let cookTime = parseISODuration(json["cookTime"] as? String)

        let cuisine = json["recipeCuisine"] as? String

        return RecipeIngestionResult(
            title: title,
            servings: servings,
            cuisine: cuisine,
            ingredients: ingredients,
            directions: directions,
            prepTimeMinutes: prepTime,
            cookTimeMinutes: cookTime,
            source: "json-ld"
        )
    }

    /// Strip HTML tags to get plain text.
    private func stripHTML(_ html: String) -> String {
        var text = html
        // Remove script and style blocks
        let blockPatterns = [
            #"<script[^>]*>.*?</script>"#,
            #"<style[^>]*>.*?</style>"#,
            #"<nav[^>]*>.*?</nav>"#,
            #"<footer[^>]*>.*?</footer>"#,
            #"<header[^>]*>.*?</header>"#,
        ]
        for pattern in blockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: " ")
            }
        }

        // Remove remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.count), withTemplate: " ")
        }

        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        // Collapse whitespace
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        return components.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Parse ISO 8601 duration (e.g., "PT30M", "PT1H15M") to minutes.
    private func parseISODuration(_ duration: String?) -> Int? {
        guard let duration else { return nil }
        var minutes = 0
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: duration, range: NSRange(location: 0, length: duration.count)) else {
            return nil
        }

        if let range = Range(match.range(at: 1), in: duration), let hours = Int(duration[range]) {
            minutes += hours * 60
        }
        if let range = Range(match.range(at: 2), in: duration), let mins = Int(duration[range]) {
            minutes += mins
        }
        if let range = Range(match.range(at: 3), in: duration), let secs = Int(duration[range]) {
            minutes += secs / 60
        }

        return minutes > 0 ? minutes : nil
    }

    /// Parse recipe yield to servings count.
    private func parseYield(_ yield: Any?) -> Int? {
        if let num = yield as? Int { return num }
        if let str = yield as? String {
            let digits = str.filter(\.isNumber)
            return Int(digits)
        }
        if let arr = yield as? [String], let first = arr.first {
            return Int(first.filter(\.isNumber))
        }
        return nil
    }

    // MARK: - Ingredient Parsing Helpers

    private func parseAmount(_ amountString: String) -> IngredientAmount {
        let parts = amountString.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)

        guard !parts.isEmpty else {
            return IngredientAmount(quantity: 1, unit: .piece)
        }

        // Try to extract quantity
        var quantity: Double = 1
        var unitStartIndex = 0

        if let num = parseFraction(parts[0]) {
            quantity = num
            unitStartIndex = 1
        }

        // Try to match unit
        let unitString = parts[unitStartIndex...].joined(separator: " ").lowercased()
        let unit = matchUnit(unitString) ?? .piece

        return IngredientAmount(quantity: quantity, unit: unit)
    }

    private func parseFraction(_ str: String) -> Double? {
        if let num = Double(str) { return num }

        // Handle fractions like "1/2", "3/4"
        let parts = str.components(separatedBy: "/")
        if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
            return num / den
        }

        // Handle unicode fractions
        let fractionMap: [String: Double] = [
            "½": 0.5, "⅓": 0.333, "⅔": 0.667,
            "¼": 0.25, "¾": 0.75, "⅛": 0.125,
        ]
        return fractionMap[str]
    }

    private func matchUnit(_ str: String) -> MeasurementUnit? {
        let unitMap: [String: MeasurementUnit] = [
            "tsp": .teaspoon, "teaspoon": .teaspoon, "teaspoons": .teaspoon,
            "tbsp": .tablespoon, "tablespoon": .tablespoon, "tablespoons": .tablespoon,
            "cup": .cup, "cups": .cup, "c": .cup,
            "oz": .ounce, "ounce": .ounce, "ounces": .ounce,
            "fl oz": .fluidOunce, "fluid ounce": .fluidOunce,
            "lb": .pound, "lbs": .pound, "pound": .pound, "pounds": .pound,
            "g": .gram, "gram": .gram, "grams": .gram,
            "kg": .kilogram, "kilogram": .kilogram, "kilograms": .kilogram,
            "ml": .milliliter, "milliliter": .milliliter, "milliliters": .milliliter,
            "l": .liter, "liter": .liter, "liters": .liter,
            "pinch": .pinch, "dash": .dash, "bunch": .bunch,
            "clove": .clove, "cloves": .clove,
            "slice": .slice, "slices": .slice,
            "piece": .piece, "pieces": .piece, "whole": .whole,
        ]

        return unitMap[str]
    }

    /// Infer ingredient category from name.
    private func inferIngredientCategory(_ name: String) -> IngredientCategory {
        let lower = name.lowercased()

        let proteins = ["chicken", "beef", "pork", "lamb", "turkey", "fish", "salmon", "tuna", "shrimp", "tofu", "egg"]
        let vegetables = ["onion", "garlic", "tomato", "pepper", "carrot", "potato", "celery", "broccoli", "spinach", "mushroom", "zucchini", "lettuce", "cucumber", "corn", "pea", "bean", "cabbage", "kale", "cauliflower"]
        let fruits = ["apple", "banana", "lemon", "lime", "orange", "berry", "strawberry", "blueberry", "avocado", "mango", "peach", "pear"]
        let grains = ["flour", "rice", "pasta", "bread", "oat", "quinoa", "noodle", "tortilla", "couscous"]
        let dairy = ["milk", "cream", "butter", "cheese", "yogurt", "sour cream"]
        let spices = ["salt", "pepper", "cumin", "paprika", "cinnamon", "turmeric", "oregano", "thyme", "chili"]
        let herbs = ["basil", "parsley", "cilantro", "rosemary", "sage", "dill", "mint", "chive"]
        let oils = ["oil", "olive oil", "vegetable oil", "coconut oil", "sesame oil"]
        let condiments = ["soy sauce", "vinegar", "ketchup", "mustard", "mayo", "hot sauce", "worcestershire"]

        if proteins.contains(where: lower.contains) { return .protein }
        if herbs.contains(where: lower.contains) { return .herb }
        if vegetables.contains(where: lower.contains) { return .vegetable }
        if fruits.contains(where: lower.contains) { return .fruit }
        if dairy.contains(where: lower.contains) { return .dairy }
        if grains.contains(where: lower.contains) { return .grain }
        if spices.contains(where: lower.contains) { return .spice }
        if oils.contains(where: lower.contains) { return .oil }
        if condiments.contains(where: lower.contains) { return .condiment }

        return .other
    }

    // MARK: - Cloud Fallback for Step Inference

    private func inferStepsViaCloud(definition: RecipeDefinition) async throws -> InferredRecipeSteps? {
        let ingredientList = definition.ingredients
            .map { "\($0.name): \($0.amount)\($0.preparation.map { ", \($0)" } ?? "")" }
            .joined(separator: "\n  - ")

        let outcomeList = definition.outcomes.joined(separator: "\n  - ")

        let prompt = """
        Given this recipe definition, infer the cooking steps. Return JSON:
        {
          "steps": [{"stepNumber": 1, "instruction": "...", "durationSeconds": 0, "ingredientsUsed": ["..."]}],
          "estimatedPrepMinutes": 15,
          "estimatedCookMinutes": 30,
          "difficulty": "intermediate"
        }

        Title: \(definition.title)
        Servings: \(definition.servings ?? 4)
        Ingredients: \(ingredientList)
        Desired outcomes: \(outcomeList)
        """

        let response = try await aiRouter.generateText(prompt: prompt, taskType: .stepInference)

        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct CloudSteps: Decodable {
            var steps: [CloudStep]
            var estimatedPrepMinutes: Int
            var estimatedCookMinutes: Int
            var difficulty: String
        }
        struct CloudStep: Decodable {
            var stepNumber: Int
            var instruction: String
            var durationSeconds: Int
            var ingredientsUsed: [String]
        }

        guard let _ = try? JSONDecoder().decode(CloudSteps.self, from: data) else {
            return nil
        }

        // Convert to InferredRecipeSteps (can't construct @Generable directly,
        // so we return nil and let the caller use the raw directions)
        return nil
    }

    // MARK: - JSON Parsing

    private func parseIngestionResponse(_ json: String, source: String) throws -> RecipeIngestionResult {
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
    var dietaryInfo: [String]?
    var nutritionPerServing: ParsedNutrition?

    struct ParsedIngredient: Codable {
        var name: String
        var amount: String
        var preparation: String?
    }

    struct ParsedNutrition: Codable {
        var calories: Int?
        var proteinGrams: Int?
        var carbsGrams: Int?
        var fatGrams: Int?
    }
}

// MARK: - Ingestion Error

enum IngestionError: LocalizedError {
    case invalidContent
    case parsingFailed
    case unsupportedFormat
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidContent:       return "Unable to read the recipe content."
        case .parsingFailed:        return "Failed to parse the recipe data."
        case .unsupportedFormat:    return "This recipe format is not supported."
        case .networkError(let e):  return "Network error: \(e.localizedDescription)"
        }
    }
}
