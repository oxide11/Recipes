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
        if var jsonLD = extractJSONLDRecipe(from: html) {
            progress = "Found structured recipe data..."
            if jsonLD.imageURL == nil {
                jsonLD.imageURL = extractOGImage(from: html)
            }
            return jsonLD
        }

        // Fall back to AI-powered extraction
        progress = "Importing recipe..."
        let stripped = stripHTML(html)
        let truncated = String(stripped.prefix(6000))

        let prompt = """
        Extract a complete recipe from this webpage text content. \
        Return valid JSON with this exact structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "italian",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "All-purpose flour", "amount": "2 cups", "preparation": "sifted"}],
          "directions": ["Step 1 instruction", "Step 2 instruction"],
          "dietaryInfo": ["vegetarian", "gluten-free"],
          "nutritionPerServing": {"calories": 350, "proteinGrams": 12, "carbsGrams": 45, "fatGrams": 14}
        }

        Important: For canned/packaged goods like "1 (14 ounce) can sweetened condensed milk", \
        use the container count as the quantity — amount should be "1 can" and name "sweetened condensed milk". \
        Never use the ounce count as the ingredient quantity.

        Webpage content:
        \(truncated.sanitizedForAI)
        """

        let response = try await aiRouter.generateText(
            prompt: prompt,
            taskType: .recipeIngestion
        )

        var result = try parseIngestionResponse(response, source: url.absoluteString)
        if result.imageURL == nil {
            result.imageURL = extractOGImage(from: html)
        }
        return result
    }

    // MARK: - Ingest from Text / Markdown

    func ingestFromText(_ text: String) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Parsing recipe text..."
        defer { isProcessing = false; progress = nil }

        let prompt = buildIngestionPrompt(for: text)
        let response = try await aiRouter.generateText(prompt: prompt, taskType: .recipeIngestion)
        return try parseIngestionResponse(response, source: "text")
    }

    /// Prompt for parsing existing recipe text (copy-paste, URL scrape, etc.)
    private func buildIngestionPrompt(for text: String) -> String {
        """
        Parse this recipe and extract structured data. Return valid JSON with this structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "italian",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "All-purpose flour", "amount": "2 cups", "preparation": "sifted"}],
          "directions": ["Step 1", "Step 2"],
          "dietaryInfo": [],
          "nutritionPerServing": {"calories": 350, "proteinGrams": 12, "carbsGrams": 45, "fatGrams": 14}
        }

        Important: For canned/packaged goods like "1 (14 ounce) can sweetened condensed milk", \
        use the container count as the quantity — amount should be "1 can" and name "sweetened condensed milk". \
        Never use the ounce count as the ingredient quantity.

        Recipe text:
        \(text.sanitizedForAI)
        """
    }

    /// Prompt for generating a new recipe from a description or request.
    /// Distinct from `buildIngestionPrompt` — the input here is not existing recipe text;
    /// it is a user request like "chicken salad" or "quick Italian dinner".
    private func buildGenerationPrompt(for description: String) -> String {
        """
        Generate a complete, practical home-cooked recipe based on this request.
        Return valid JSON with this exact structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "italian",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "Chicken breast", "amount": "2", "preparation": "diced"}],
          "directions": ["Step 1", "Step 2"],
          "dietaryInfo": [],
          "nutritionPerServing": {"calories": 350, "proteinGrams": 12, "carbsGrams": 45, "fatGrams": 14}
        }

        The recipe must match the request closely — if the user asked for chicken salad, \
        return a chicken salad recipe. Do not substitute a different dish.
        Keep ingredients to 10 or fewer. Everyday cooking, not restaurant food.

        Request: \(description.sanitizedForAI)
        """
    }

    /// Streaming variant — calls `onChunk` with each text fragment as it arrives,
    /// then returns the fully parsed result. Use this to show live progress in the UI.
    /// - Parameter isGeneration: `true` when the input is a user description/request
    ///   (generates a new recipe); `false` when parsing existing recipe text.
    func ingestFromTextStreaming(_ text: String, isGeneration: Bool = false, onChunk: @escaping (String) -> Void) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = isGeneration ? "Generating recipe…" : "Parsing recipe…"
        defer { isProcessing = false; progress = nil }

        let prompt = isGeneration ? buildGenerationPrompt(for: text) : buildIngestionPrompt(for: text)
        var accumulated = ""
        for try await chunk in aiRouter.generateTextStreaming(prompt: prompt, taskType: .recipeIngestion) {
            accumulated += chunk
            onChunk(chunk)
        }
        return try parseIngestionResponse(accumulated, source: isGeneration ? "ai-generate" : "text")
    }

    // MARK: - Image Compression

    /// Compress image data to fit within the AI API's 5 MB limit.
    /// Tries progressively lower JPEG quality until the encoded size is acceptable.
    static func compressedForAI(_ image: UIImage, maxBytes: Int = 4_800_000) -> Data? {
        let qualities: [CGFloat] = [0.8, 0.6, 0.4, 0.2, 0.1]
        for quality in qualities {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
        }
        return image.jpegData(compressionQuality: 0.1)
    }

    // MARK: - Ingest from Image

    func ingestFromImage(_ imageData: Data) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Importing recipe..."
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

            Important: For canned/packaged goods like "1 (14 ounce) can sweetened condensed milk", \
            use the container count as the quantity — amount should be "1 can" and name "sweetened condensed milk". \
            Never use the ounce count as the ingredient quantity.
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

    // MARK: - AI Recipe Edit

    /// Re-run AI over an existing recipe with a natural-language modification request.
    /// Returns an updated `RecipeIngestionResult` — the caller is responsible for applying
    /// changes to the SwiftData model.
    func editRecipe(_ recipe: Recipe, instruction: String) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Applying changes with AI…"
        defer { isProcessing = false; progress = nil }

        let prompt = buildEditPrompt(recipe: recipe, instruction: instruction)
        let response = try await aiRouter.generateText(prompt: prompt, taskType: .recipeIngestion, preferFast: true)
        return try parseIngestionResponse(response, source: recipe.sourceURL ?? "ai-edit")
    }

    /// Streaming variant of `editRecipe` — calls `onChunk` with each text fragment as it
    /// arrives, then returns the fully parsed result.
    func editRecipeStreaming(_ recipe: Recipe, instruction: String, onChunk: @escaping (String) -> Void) async throws -> RecipeIngestionResult {
        isProcessing = true
        progress = "Applying changes with AI…"
        defer { isProcessing = false; progress = nil }

        let prompt = buildEditPrompt(recipe: recipe, instruction: instruction)
        var accumulated = ""
        for try await chunk in aiRouter.generateTextStreaming(prompt: prompt, taskType: .recipeIngestion) {
            accumulated += chunk
            onChunk(chunk)
        }
        return try parseIngestionResponse(accumulated, source: recipe.sourceURL ?? "ai-edit")
    }

    private func buildEditPrompt(recipe: Recipe, instruction: String) -> String {
        let sortedDirs = recipe.directions.sorted { $0.stepNumber < $1.stepNumber }
        var lines: [String] = [
            "Title: \(recipe.title)",
            "Servings: \(recipe.servings)",
            "Cuisine: \(recipe.cuisine.rawValue)",
            "Prep: \(recipe.prepTimeMinutes) min",
            "Cook: \(recipe.cookTimeMinutes) min",
            "",
            "Ingredients:"
        ]
        for ing in recipe.ingredients {
            let prep = ing.notes.map { ", \($0)" } ?? ""
            lines.append("- \(ing.amount.displayString) \(ing.name)\(prep)")
        }
        lines.append("")
        lines.append("Steps:")
        for dir in sortedDirs {
            lines.append("\(dir.stepNumber). \(dir.instruction)")
        }
        if !recipe.dietaryRestrictions.isEmpty {
            lines.append("")
            lines.append("Current dietary labels: \(recipe.dietaryRestrictions.map(\.displayName).joined(separator: ", "))")
        }
        let recipeText = lines.joined(separator: "\n")

        return """
        Modify the following recipe based on the user's request. \
        Make ONLY the changes needed to fulfil the request; keep everything else identical.

        Recipe:
        \(recipeText)

        User request: \(instruction.sanitizedForAI)

        Return the complete updated recipe as valid JSON with this exact structure:
        {
          "title": "Recipe Name",
          "servings": 4,
          "cuisine": "type",
          "prepTimeMinutes": 15,
          "cookTimeMinutes": 30,
          "ingredients": [{"name": "...", "amount": "...", "preparation": "..."}],
          "directions": ["Step 1", "Step 2"],
          "dietaryInfo": [],
          "nutritionPerServing": null
        }

        For dietaryInfo: re-evaluate based on the updated ingredients. \
        Valid values: vegan, vegetarian, glutenFree, dairyFree, nutFree, lowCarb, keto, paleo, halal, kosher. \
        If the changes add meat or animal products, remove vegetarian/vegan. \
        Return [] if no special dietary labels apply.
        """
    }

    // MARK: - Convert Result to Recipe Model

    /// Convert an ingestion result into a full Recipe model ready for SwiftData insertion.
    func convertToRecipe(_ result: RecipeIngestionResult) async -> Recipe {
        let cuisine = Cuisine.allCases.first {
            $0.rawValue.lowercased() == result.cuisine?.lowercased()
        } ?? .other

        let ingredients = result.ingredients.map { parsed in
            let amount = parseAmount(parsed.amount)
            let name = parsed.name.prefix(1).uppercased() + parsed.name.dropFirst()
            let category = inferIngredientCategory(name)
            return Ingredient(
                name: name,
                category: category,
                amount: amount,
                notes: parsed.preparation
            )
        }

        var seenIngredients = Set<String>()
        let directions = result.directions.enumerated().map { index, instruction -> RecipeDirection in
            let lower = instruction.lowercased()
            var seenInStep = Set<String>()   // per-step dedup
            let refs = ingredients.compactMap { ingredient -> DirectionIngredientRef? in
                let ingredientLower = ingredient.name.lowercased()
                // Find how this ingredient is actually referred to in the step text
                // (handles multi-word names, plurals, abbreviations)
                guard let term = Self.matchedTerm(for: ingredientLower, in: lower) else { return nil }
                guard !seenInStep.contains(ingredientLower) else { return nil }
                guard !Self.isManipulation(instruction: lower, ingredientName: ingredientLower,
                                           matchedTerm: term,
                                           alreadySeen: seenIngredients.contains(ingredientLower)) else { return nil }
                seenInStep.insert(ingredientLower)
                seenIngredients.insert(ingredientLower)
                let amount = Self.extractStepAmount(from: instruction, ingredientName: ingredient.name,
                                                   matchedTerm: term,
                                                   parseAmount: parseAmount, matchUnit: matchUnit,
                                                   parseFraction: parseFraction)
                             ?? ingredient.amount
                return DirectionIngredientRef(ingredientName: ingredient.name, amount: amount)
            }
            let timer = parseTimerFromInstruction(instruction, stepNumber: index + 1)
            return RecipeDirection(stepNumber: index + 1, instruction: instruction, timer: timer, ingredients: refs)
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

        // Derive a human-readable source name
        let sourceName: String?
        let sourceURL: String?
        switch result.source ?? "" {
        case let s where s.hasPrefix("http"):
            sourceURL = s
            sourceName = URL(string: s).flatMap { url in
                url.host.map { host in
                    host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                }
            }
        case "image":
            sourceURL = nil
            sourceName = "Photo Import"
        case "text":
            sourceURL = nil
            sourceName = "Text Import"
        case "recipe-as-code":
            sourceURL = nil
            sourceName = "Recipe Code"
        default:
            sourceURL = nil
            sourceName = nil
        }

        let recipe = Recipe(
            title: result.title,
            cuisine: cuisine,
            servings: result.servings ?? 4,
            prepTimeMinutes: result.prepTimeMinutes ?? 15,
            cookTimeMinutes: result.cookTimeMinutes ?? 30,
            ingredients: ingredients,
            directions: directions,
            nutritionalInfo: nutritionalInfo,
            dietaryRestrictions: dietaryRestrictions,
            sourceURL: sourceURL,
            sourceName: sourceName
        )

        // Add domain as a tag for URL imports
        if let host = sourceURL.flatMap({ URL(string: $0)?.host }) {
            let strippedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            let components = strippedHost.components(separatedBy: ".")
            if components.count >= 2, let domain = components.dropLast().last {
                recipe.tags.append(domain)
            }
        }

        // Fetch and attach the recipe image if one was found
        if let imageURLString = result.imageURL,
           let imageURL = URL(string: imageURLString),
           let (imageData, _) = try? await URLSession.shared.data(from: imageURL),
           !imageData.isEmpty {
            let id = UUID()
            if let filename = try? PhotoStorageService.save(imageData, id: id) {
                let photo = RecipePhoto(id: id, imageFilename: filename)
                recipe.photos.append(photo)
            }
        }

        return recipe
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
            ingredients = list.map { parseFullIngredientString(decodeHTMLEntities($0)) }
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

        // image can be a string, an array of strings, or an ImageObject dict
        let imageURL: String?
        if let str = json["image"] as? String {
            imageURL = str
        } else if let arr = json["image"] as? [String] {
            imageURL = arr.first
        } else if let obj = json["image"] as? [String: Any] {
            imageURL = obj["url"] as? String
        } else if let arr = json["image"] as? [[String: Any]] {
            imageURL = arr.first?["url"] as? String
        } else {
            imageURL = nil
        }

        return RecipeIngestionResult(
            title: title,
            servings: servings,
            cuisine: cuisine,
            ingredients: ingredients,
            directions: directions,
            prepTimeMinutes: prepTime,
            cookTimeMinutes: cookTime,
            source: "json-ld",
            imageURL: imageURL
        )
    }

    /// Extract the og:image URL from HTML meta tags.
    private func extractOGImage(from html: String) -> String? {
        let pattern = #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            // Try reversed attribute order: content first, then property
            let pattern2 = #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#
            guard let regex2 = try? NSRegularExpression(pattern: pattern2, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                  let match2 = regex2.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let range2 = Range(match2.range(at: 1), in: html) else { return nil }
            return String(html[range2])
        }
        return String(html[range])
    }

    /// Extract a timer from a direction instruction, if one is clearly stated.
    /// Handles patterns like "bake for 30 minutes", "simmer for 1 hour 15 minutes",
    /// "cook for 2-3 minutes" (uses the lower bound), "rest for 30 seconds".
    private func parseTimerFromInstruction(_ instruction: String, stepNumber: Int) -> TimerStep? {
        let text = instruction.lowercased()

        // Pattern: optional hours + optional minutes + optional seconds
        // e.g. "1 hour 30 minutes", "45 minutes", "1 hour", "90 seconds"
        let pattern = #"(?:for\s+|about\s+)?(\d+)(?:\s*[-–]\s*\d+)?\s*(?:to\s+\d+\s+)?(hours?|hrs?|minutes?|mins?|seconds?|secs?)(?:\s+(?:and\s+)?(\d+)\s+(minutes?|mins?|seconds?|secs?))?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }

        func intCapture(_ group: Int) -> Int? {
            guard group < match.numberOfRanges,
                  let range = Range(match.range(at: group), in: text),
                  let val = Int(text[range]) else { return nil }
            return val
        }
        func strCapture(_ group: Int) -> String? {
            guard group < match.numberOfRanges,
                  let range = Range(match.range(at: group), in: text) else { return nil }
            return String(text[range])
        }

        guard let value1 = intCapture(1), let unit1 = strCapture(2) else { return nil }

        var totalSeconds = 0
        if unit1.hasPrefix("hour") || unit1.hasPrefix("hr") {
            totalSeconds += value1 * 3600
        } else if unit1.hasPrefix("min") {
            totalSeconds += value1 * 60
        } else if unit1.hasPrefix("sec") {
            totalSeconds += value1
        }

        // Optional second component (e.g. "1 hour 30 minutes")
        if let value2 = intCapture(3), let unit2 = strCapture(4) {
            if unit2.hasPrefix("min") { totalSeconds += value2 * 60 }
            else if unit2.hasPrefix("sec") { totalSeconds += value2 }
        }

        // Ignore implausibly short or long timers (< 10 seconds or > 24 hours)
        guard totalSeconds >= 10, totalSeconds <= 86400 else { return nil }

        return TimerStep(durationSeconds: totalSeconds, label: "Step \(stepNumber)")
    }

    /// Decode common HTML entities including fractions.
    private func decodeHTMLEntities(_ html: String) -> String {
        html
            .replacingOccurrences(of: "&amp;",   with: "&")
            .replacingOccurrences(of: "&lt;",    with: "<")
            .replacingOccurrences(of: "&gt;",    with: ">")
            .replacingOccurrences(of: "&nbsp;",  with: " ")
            .replacingOccurrences(of: "&#39;",   with: "'")
            .replacingOccurrences(of: "&quot;",  with: "\"")
            .replacingOccurrences(of: "&frac12;", with: "½")
            .replacingOccurrences(of: "&frac14;", with: "¼")
            .replacingOccurrences(of: "&frac34;", with: "¾")
            .replacingOccurrences(of: "&frac13;", with: "⅓")
            .replacingOccurrences(of: "&frac23;", with: "⅔")
            .replacingOccurrences(of: "&frac18;", with: "⅛")
            .replacingOccurrences(of: "&frac38;", with: "⅜")
            .replacingOccurrences(of: "&frac58;", with: "⅝")
            .replacingOccurrences(of: "&frac78;", with: "⅞")
    }

    /// Parse a full ingredient string (e.g. from JSON-LD) into name, amount, and preparation.
    /// Handles strings like "4 cloves garlic, pressed or minced" or "½ teaspoon garlic powder".
    /// Also handles "1 (14 ounce) can sweetened condensed milk" → amount="1 can", name="sweetened condensed milk".
    private func parseFullIngredientString(_ str: String) -> RecipeIngestionResult.ParsedIngredient {
        var s = str.trimmingCharacters(in: .whitespaces)

        // Split preparation on first comma: "garlic, minced" → name="garlic", prep="minced"
        var preparation: String? = nil
        if let commaIdx = s.firstIndex(of: ",") {
            let prepStr = String(s[s.index(after: commaIdx)...]).trimmingCharacters(in: .whitespaces)
            if !prepStr.isEmpty { preparation = prepStr }
            s = String(s[..<commaIdx]).trimmingCharacters(in: .whitespaces)
        }

        // Strip parenthetical size descriptors like "(14 ounce)" or "(12 fluid ounce)"
        s = s.replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
             .trimmingCharacters(in: .whitespaces)

        // Try to pull a leading quantity token (number or fraction)
        var tokens = s.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var amountTokens: [String] = []

        if let first = tokens.first, parseFraction(first) != nil {
            amountTokens.append(tokens.removeFirst())
            // Mixed number: "1 1/2" — next token is also a fraction
            if let next = tokens.first, parseFraction(next) != nil, next.contains("/") {
                amountTokens.append(tokens.removeFirst())
            }
            // Optional unit token right after the number (try two-word units first, e.g. "fluid ounce")
            if tokens.count >= 2,
               let _ = matchUnit("\(tokens[0]) \(tokens[1])".lowercased()) {
                amountTokens.append(tokens.removeFirst())
                amountTokens.append(tokens.removeFirst())
            } else if let unit = tokens.first, matchUnit(unit.lowercased()) != nil {
                amountTokens.append(tokens.removeFirst())
            }
        }

        let name = tokens.joined(separator: " ")
        let amount = amountTokens.joined(separator: " ")
        return .init(
            name: name.isEmpty ? s : name,
            amount: amount,
            preparation: preparation
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
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
            }
        }

        // Remove remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }

        // Decode common HTML entities
        text = decodeHTMLEntities(text)

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

    // MARK: - Step Ingredient Helpers

    /// Returns the term by which `ingredientName` is referred to in `instruction`,
    /// or nil if the ingredient doesn't appear.
    /// Handles multi-word names ("black pepper" → "pepper"),
    /// and basic plural/singular variants ("potato" ↔ "potatoes").
    private static func matchedTerm(for ingredientName: String, in instruction: String) -> String? {
        // 1. Exact match
        if wordBoundaryContains(instruction, ingredientName) { return ingredientName }

        let words = ingredientName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        // 2. Single word — try plural/singular
        if words.count == 1 {
            for v in pluralVariants(of: ingredientName) where wordBoundaryContains(instruction, v) { return v }
            return nil
        }

        // 3. Multi-word — try each significant word (and its plural/singular)
        // Descriptor words that are too generic to match on their own
        let descriptors: Set<String> = [
            "fresh", "dried", "large", "small", "medium", "whole", "ground",
            "minced", "sliced", "chopped", "diced", "finely", "coarsely",
            "thinly", "thick", "unsalted", "salted", "extra", "virgin",
            "heavy", "light", "low", "high", "raw", "cooked", "shredded",
            "grated", "peeled", "boneless", "skinless", "lean"
        ]
        // Prefer later words (usually the noun) then earlier words
        for word in words.reversed() where !descriptors.contains(word) && word.count >= 3 {
            if wordBoundaryContains(instruction, word) { return word }
            for v in pluralVariants(of: word) where wordBoundaryContains(instruction, v) { return v }
        }
        return nil
    }

    /// Case-insensitive substring check that requires word boundaries on both sides.
    private static func wordBoundaryContains(_ text: String, _ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: word, options: .caseInsensitive, range: searchRange) {
            let beforeOK = range.lowerBound == text.startIndex
                        || !text[text.index(before: range.lowerBound)].isLetter
            let afterOK  = range.upperBound == text.endIndex
                        || !text[range.upperBound].isLetter
            if beforeOK && afterOK { return true }
            searchRange = range.upperBound..<text.endIndex
        }
        return false
    }

    /// Returns simple plural/singular variants for a word.
    private static func pluralVariants(of word: String) -> [String] {
        if word.hasSuffix("ies") { return [String(word.dropLast(3)) + "y"] }
        if word.hasSuffix("ves") { return [String(word.dropLast(3)) + "f", String(word.dropLast(3)) + "fe"] }
        if word.hasSuffix("es")  { return [String(word.dropLast(2)), String(word.dropLast(1))] }
        if word.hasSuffix("s")   { return [String(word.dropLast())] }
        // Singular — produce plural
        if word.hasSuffix("y")   { return [String(word.dropLast()) + "ies"] }
        if word.hasSuffix("f")   { return [String(word.dropLast()) + "ves"] }
        if ["o","ch","sh","x","z","s"].contains(where: { word.hasSuffix($0) }) { return [word + "es"] }
        return [word + "s"]
    }

    /// Returns true when "remaining" or "reserved" appears within 40 chars before `term`.
    private static func remainingAppearsNear(term: String, in lower: String) -> Bool {
        guard let termRange = lower.range(of: term, options: .caseInsensitive) else { return false }
        let dist = lower.distance(from: lower.startIndex, to: termRange.lowerBound)
        let lookbackStart = lower.index(termRange.lowerBound, offsetBy: -min(40, dist))
        let window = String(lower[lookbackStart..<termRange.lowerBound])
        return window.contains("remaining") || window.contains("reserved")
    }

    /// Returns true when the ingredient mention is manipulation of something already added
    /// rather than a fresh addition, so no chip should be shown.
    private static func isManipulation(
        instruction lower: String,
        ingredientName: String,
        matchedTerm: String,
        alreadySeen: Bool
    ) -> Bool {
        // "remaining/reserved" near the matched term — always a real addition
        if remainingAppearsNear(term: matchedTerm, in: lower) { return false }

        if alreadySeen {
            let addingVerbs = ["add ", "stir in", "mix in", "pour", "place ", "put ",
                               "fold in", "incorporate", "sprinkle", "drizzle", "layer",
                               "toss with", "coat with", "combine with", "whisk in", "blend in",
                               "top with", "season with", "scatter", "dot with", "finish with",
                               "arrange", "distribute", "spread", "nestle"]

            // Prepositional patterns that indicate the ingredient is already in the pan
            let referencePrepositions = ["to the \(matchedTerm)", "over the \(matchedTerm)",
                                         "with the \(matchedTerm)", "on the \(matchedTerm)",
                                         "from the \(matchedTerm)", "into the \(matchedTerm)",
                                         "through the \(matchedTerm)", "of the \(matchedTerm)",
                                         "around the \(matchedTerm)", "among the \(matchedTerm)"]
            if referencePrepositions.contains(where: { lower.contains($0) }) { return true }

            // Check if an adding verb appears within 80 chars before the matched term
            guard let termRange = lower.range(of: matchedTerm, options: .caseInsensitive) else { return true }
            let dist = lower.distance(from: lower.startIndex, to: termRange.lowerBound)
            let lookbackStart = lower.index(termRange.lowerBound, offsetBy: -min(80, dist))
            let window = String(lower[lookbackStart..<termRange.lowerBound])
            return !addingVerbs.contains { window.contains($0) }
        }
        return false
    }

    /// Tries to extract the quantity used in this specific step from the instruction text,
    /// e.g. "2 teaspoons of olive oil" → IngredientAmount(2, .teaspoon).
    /// Returns nil if no explicit amount is found in the text.
    private static func extractStepAmount(
        from instruction: String,
        ingredientName: String,
        matchedTerm: String,
        parseAmount: (String) -> IngredientAmount,
        matchUnit: (String) -> MeasurementUnit?,
        parseFraction: (String) -> Double?
    ) -> IngredientAmount? {
        let lower = instruction.lowercased()

        // "remaining/reserved" near matched term — show a remaining chip
        if remainingAppearsNear(term: matchedTerm, in: lower) { return .remaining }

        let escapedName = NSRegularExpression.escapedPattern(for: matchedTerm)
        // Pattern: (number) (optional unit) (optional "of") matchedTerm
        let pattern = #"([\d½¼¾⅓⅔⅛][0-9 /½¼¾⅓⅔⅛.]*)\s+(teaspoons?|tablespoons?|tsps?|tbsps?|cups?|ounces?|oz|pounds?|lbs?|grams?|g|kilograms?|kg|milliliters?|ml|liters?|l|pinch(?:es)?|cloves?|bunche?s?|slices?|pieces?)\s+(?:of\s+)?"# + escapedName
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
              match.numberOfRanges >= 3 else { return nil }

        let nsLower = lower as NSString
        let quantityStr = nsLower.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        let unitStr     = nsLower.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)

        guard let quantity = parseFraction(quantityStr.components(separatedBy: .whitespaces).last ?? quantityStr),
              let unit = matchUnit(unitStr) else { return nil }

        // Handle mixed numbers like "1 1/2" → last token is fraction, sum with whole
        let tokens = quantityStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var total = quantity
        if tokens.count == 2, let whole = Double(tokens[0]), let frac = parseFraction(tokens[1]) {
            total = whole + frac
        }

        return IngredientAmount(quantity: total, unit: unit)
    }

    private func parseAmount(_ amountString: String) -> IngredientAmount {
        // Strip parenthetical qualifiers like "(14 ounce)" from strings such as "1 (14 ounce) can"
        let cleaned = amountString
            .replacingOccurrences(of: #"\([^)]*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let parts = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        let joined = parts.joined(separator: " ").lowercased()
        guard !parts.isEmpty, parts[0] != "",
              !["as needed", "to taste", "for greasing", "as required", "optional"].contains(joined) else {
            return IngredientAmount(quantity: 1, unit: .asNeeded)
        }

        // Try to extract quantity
        var quantity: Double = 1
        var unitStartIndex = 0

        if let num = parseFraction(parts[0]) {
            quantity = num
            unitStartIndex = 1
            // Mixed number: "1 1/2 cups" — combine whole + fraction parts
            if parts.count > 1, let frac = parseFraction(parts[1]), parts[1].contains("/") {
                quantity += frac
                unitStartIndex = 2
            }
        }

        // Try to match unit — fall back to shorter prefixes so "ounce can" matches "ounce"
        let remainingParts = Array(parts[unitStartIndex...])
        var unit: MeasurementUnit = .piece
        for length in stride(from: remainingParts.count, through: 1, by: -1) {
            let candidate = remainingParts.prefix(length).joined(separator: " ").lowercased()
            if let matched = matchUnit(candidate) {
                unit = matched
                break
            }
        }

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
            "can": .can, "cans": .can,
            "jar": .whole, "jars": .whole,
            "bottle": .whole, "bottles": .whole,
            "package": .whole, "packages": .whole, "pkg": .whole,
            "stick": .whole, "sticks": .whole,
            "fluid ounces": .fluidOunce,
        ]

        return unitMap[str]
    }

    /// Infer ingredient category from name.
    private func inferIngredientCategory(_ name: String) -> IngredientCategory {
        IngredientNormalizer.inferCategory(fromName: name)
    }

    // MARK: - JSON Parsing

    private func parseIngestionResponse(_ json: String, source: String) throws -> RecipeIngestionResult {
        let stripped = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract the JSON object even if the model wraps it in prose or explanation
        guard let start = stripped.firstIndex(of: "{"),
              let end   = stripped.lastIndex(of: "}") else {
            throw IngestionError.parsingFailed
        }
        let jsonString = String(stripped[start...end])

        guard let data = jsonString.data(using: .utf8) else {
            throw IngestionError.parsingFailed
        }

        do {
            var result = try JSONDecoder().decode(RecipeIngestionResult.self, from: data)
            result.source = source
            return result
        } catch {
            throw IngestionError.parsingFailed
        }
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
    var imageURL: String?
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
