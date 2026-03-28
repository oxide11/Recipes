import Foundation
import FoundationModels

// MARK: - Recipe as Code

/// A declarative, YAML-like recipe definition that the app can parse
/// and from which it can infer cooking steps using AI.
///
/// Example usage in markdown/YAML:
/// ```yaml
/// recipe:
///   title: "Simple Pasta Aglio e Olio"
///   servings: 4
///   cuisine: italian
///   ingredients:
///     - spaghetti: 400g
///     - garlic: 6 cloves, sliced
///     - olive oil: 0.5 cup
///     - red pepper flakes: 1 tsp
///     - parsley: 0.25 cup, chopped
///     - parmesan: to taste
///   outcomes:
///     - pasta is al dente
///     - garlic is golden and fragrant
///     - oil is infused with pepper flakes
///     - parsley is freshly mixed in
/// ```

struct RecipeDefinition: Codable, Hashable, Sendable {
    var title: String
    var servings: Int?
    var cuisine: String?
    var ingredients: [RecipeCodeIngredient]
    var outcomes: [String]
    var constraints: [String]?
    var equipment: [String]?
    var notes: String?
}

struct RecipeCodeIngredient: Codable, Hashable, Sendable {
    var name: String
    var amount: String
    var preparation: String?
}

// MARK: - AI-Generated Steps from Recipe Definition

@Generable
struct InferredRecipeSteps {
    @Guide(description: "Ordered list of cooking steps inferred from ingredients and desired outcomes")
    var steps: [InferredStep]

    @Guide(description: "Estimated total prep time in minutes")
    var estimatedPrepMinutes: Int

    @Guide(description: "Estimated total cook time in minutes")
    var estimatedCookMinutes: Int

    @Guide(description: "Recommended difficulty level: beginner, intermediate, advanced, or expert")
    var difficulty: String
}

@Generable
struct InferredStep {
    @Guide(description: "The step number, starting from 1")
    var stepNumber: Int

    @Guide(description: "Clear cooking instruction for this step")
    var instruction: String

    @Guide(description: "Duration of this step in seconds, if applicable, or 0")
    var durationSeconds: Int

    @Guide(description: "Ingredients used in this step, by name")
    var ingredientsUsed: [String]
}

// MARK: - Recipe Definition Parser

enum RecipeDefinitionParser {

    /// Parse a simple recipe-as-code text block into a RecipeDefinition.
    /// Supports a simplified YAML-like format.
    static func parse(from text: String) throws -> RecipeDefinition {
        var title = "Untitled Recipe"
        var servings: Int?
        var cuisine: String?
        var ingredients: [RecipeCodeIngredient] = []
        var outcomes: [String] = []
        var equipment: [String] = []
        var currentSection: String?

        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("-") {
                let key = trimmed.dropLast().trimmingCharacters(in: .whitespaces).lowercased()
                currentSection = key
                continue
            }

            if let colonIndex = trimmed.firstIndex(of: ":"), !trimmed.hasPrefix("-") {
                let key = trimmed[..<colonIndex].trimmingCharacters(in: .whitespaces).lowercased()
                let value = trimmed[trimmed.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

                switch key {
                case "title":    title = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                case "servings": servings = Int(value)
                case "cuisine":  cuisine = value
                default:         break
                }
                continue
            }

            if trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)

                switch currentSection {
                case "ingredients":
                    let ingredient = parseIngredientLine(content)
                    ingredients.append(ingredient)
                case "outcomes":
                    outcomes.append(content)
                case "equipment":
                    equipment.append(content)
                default:
                    break
                }
            }
        }

        return RecipeDefinition(
            title: title,
            servings: servings,
            cuisine: cuisine,
            ingredients: ingredients,
            outcomes: outcomes,
            equipment: equipment.isEmpty ? nil : equipment
        )
    }

    private static func parseIngredientLine(_ line: String) -> RecipeCodeIngredient {
        // Format: "name: amount[, preparation]"
        if let colonIndex = line.firstIndex(of: ":") {
            let name = line[..<colonIndex].trimmingCharacters(in: .whitespaces)
            let rest = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)

            let parts = rest.components(separatedBy: ",")
            let amount = parts[0].trimmingCharacters(in: .whitespaces)
            let prep = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil

            return RecipeCodeIngredient(name: name, amount: amount, preparation: prep)
        }

        return RecipeCodeIngredient(name: line, amount: "to taste")
    }
}
