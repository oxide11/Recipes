import Foundation
import SwiftData

// MARK: - No Waste Recipe Matching Engine

/// Matches available pantry items against recipe ingredients to surface
/// recipes the user can make right now. Prioritizes recipes that:
/// 1. Use expiring-soon ingredients
/// 2. Maximize pantry utilization (minimize waste)
/// 3. Require fewest additional purchases
@Observable
final class NoWasteMatchingEngine {

    struct MatchResult: Identifiable {
        var id: UUID { recipe.id }
        var recipe: Recipe
        var score: Double
        var matchedIngredients: [MatchedIngredient]
        var substitutableIngredients: [SubstitutableIngredient]
        var missingIngredients: [String]
        var expiringIngredientsUsed: [String]
        var pantryUtilizationPercent: Double

        /// Percentage of recipe ingredients covered by pantry (substitutes count as covered).
        var coveragePercent: Double {
            let total = matchedIngredients.count + substitutableIngredients.count + missingIngredients.count
            guard total > 0 else { return 0 }
            return Double(matchedIngredients.count + substitutableIngredients.count) / Double(total) * 100
        }

        var isFullyCoverable: Bool { missingIngredients.isEmpty }
    }

    struct MatchedIngredient: Sendable {
        var recipeName: String
        var pantryName: String
        var isExpiringSoon: Bool
        var isExpired: Bool
    }

    struct SubstitutableIngredient: Sendable {
        /// What the recipe calls for.
        var recipeName: String
        /// What you have that can substitute.
        var substituteName: String
    }

    // MARK: - Match Recipes Against Pantry

    /// Find recipes that can be made with current pantry items.
    /// Returns results sorted by match score (best matches first).
    static func matchRecipes(
        recipes: [Recipe],
        pantryItems: [PantryItem],
        maxMissing: Int = 3,
        prioritizeExpiring: Bool = true
    ) -> [MatchResult] {
        let pantryIndex = buildPantryIndex(from: pantryItems)

        return recipes.compactMap { recipe in
            score(recipe: recipe, pantryIndex: pantryIndex, pantryItems: pantryItems, maxMissing: maxMissing, prioritizeExpiring: prioritizeExpiring)
        }
        .sorted { $0.score > $1.score }
    }

    /// Find recipes that specifically use expiring-soon ingredients.
    static func recipesForExpiringItems(
        recipes: [Recipe],
        pantryItems: [PantryItem]
    ) -> [MatchResult] {
        let expiring = pantryItems.filter { $0.isExpiringSoon || $0.isExpired }
        guard !expiring.isEmpty else { return [] }

        let pantryIndex = buildPantryIndex(from: pantryItems)

        return recipes.compactMap { recipe in
            let result = score(recipe: recipe, pantryIndex: pantryIndex, pantryItems: pantryItems, maxMissing: 5, prioritizeExpiring: true)
            guard let result, !result.expiringIngredientsUsed.isEmpty else { return nil }
            return result
        }
        .sorted { $0.score > $1.score }
    }

    /// Suggest what to cook given a time constraint.
    static func lastMinuteRecipes(
        recipes: [Recipe],
        pantryItems: [PantryItem],
        maxMinutes: Int
    ) -> [MatchResult] {
        let quickRecipes = recipes.filter { $0.estimatedTotalMinutes <= maxMinutes }
        return matchRecipes(recipes: quickRecipes, pantryItems: pantryItems, maxMissing: 2)
    }

    // MARK: - Scoring

    private static func score(
        recipe: Recipe,
        pantryIndex: [String: [PantryItem]],
        pantryItems: [PantryItem],
        maxMissing: Int,
        prioritizeExpiring: Bool
    ) -> MatchResult? {
        var matched: [MatchedIngredient] = []
        var substitutable: [SubstitutableIngredient] = []
        var missing: [String] = []
        var expiringUsed: [String] = []

        for ingredient in recipe.ingredients {
            if ingredient.isOptional { continue }

            let name = IngredientNormalizer.canonicalize(ingredient.name)

            if let pantryMatches = findPantryMatch(for: name, in: pantryIndex) {
                let isExpiring = pantryMatches.contains { $0.isExpiringSoon }
                let isExpired = pantryMatches.contains { $0.isExpired }

                matched.append(MatchedIngredient(
                    recipeName: ingredient.name,
                    pantryName: pantryMatches.first?.name ?? ingredient.name,
                    isExpiringSoon: isExpiring,
                    isExpired: isExpired
                ))

                if isExpiring || isExpired {
                    expiringUsed.append(ingredient.name)
                }
            } else if let sub = findSubstitution(for: name, in: pantryIndex) {
                substitutable.append(SubstitutableIngredient(
                    recipeName: ingredient.name,
                    substituteName: sub
                ))
            } else {
                missing.append(ingredient.name)
            }
        }

        // Skip recipes with too many truly missing ingredients (substitutes don't count)
        guard missing.count <= maxMissing else { return nil }

        // Calculate score
        let requiredIngredients = recipe.ingredients.filter { !$0.isOptional }
        let totalRequired = max(requiredIngredients.count, 1)

        // Base score: matched + substitutable at 70% value (0–50 points)
        var score = (Double(matched.count) + Double(substitutable.count) * 0.7) / Double(totalRequired) * 50.0

        // Expiring bonus: recipes using expiring items get a big boost (0–30 points)
        if prioritizeExpiring && !expiringUsed.isEmpty {
            score += Double(expiringUsed.count) * 10.0
            score = min(score, 80.0)
        }

        // Freshness penalty: recipes requiring expired ingredients score slightly lower
        let expiredCount = matched.filter(\.isExpired).count
        score -= Double(expiredCount) * 5.0

        // Missing penalty: each missing ingredient reduces score (0–20 points)
        score -= Double(missing.count) * 5.0

        // Time bonus: quicker recipes get a small boost
        if recipe.estimatedTotalMinutes <= 30 {
            score += 5.0
        }

        // Seasonal bonus
        let ingredientNames = recipe.ingredients.map(\.name)
        let seasonality = SeasonalAwarenessService.seasonalityScore(ingredientNames: ingredientNames)
        score += seasonality * 5.0

        // Pantry utilization: what % of pantry items does this recipe use
        let usedPantryNames = Set(matched.map { $0.pantryName.lowercased() })
        let totalPantry = max(pantryItems.count, 1)
        let utilization = Double(usedPantryNames.count) / Double(totalPantry) * 100

        return MatchResult(
            recipe: recipe,
            score: max(score, 0),
            matchedIngredients: matched,
            substitutableIngredients: substitutable,
            missingIngredients: missing,
            expiringIngredientsUsed: expiringUsed,
            pantryUtilizationPercent: utilization
        )
    }

    // MARK: - Pantry Index

    /// Build a lookup index from pantry items for fast ingredient matching.
    /// Maps normalized ingredient names and common aliases to pantry items.
    private static func buildPantryIndex(from items: [PantryItem]) -> [String: [PantryItem]] {
        var index: [String: [PantryItem]] = [:]

        for item in items {
            // Index by canonical name so "extra-virgin olive oil" in a recipe
            // matches "olive oil" in the pantry and vice versa.
            let canonical = IngredientNormalizer.canonicalize(item.name)
            index[canonical, default: []].append(item)

            // Also index the raw normalized name in case it differs from canonical
            let name = IngredientNormalizer.normalize(item.name)
            if name != canonical {
                index[name, default: []].append(item)
            }

            // Add singular/plural variants
            for variant in IngredientNormalizer.variants(of: canonical) where variant != canonical {
                index[variant, default: []].append(item)
            }

            // Common aliases
            for alias in ingredientAliases(for: canonical) {
                index[alias, default: []].append(item)
            }
        }

        return index
    }

    /// Find a pantry match for a recipe ingredient name using fuzzy matching.
    private static func findPantryMatch(
        for ingredientName: String,
        in index: [String: [PantryItem]]
    ) -> [PantryItem]? {
        // ingredientName is already canonicalized by callers
        let name = ingredientName

        // O(1) exact/canonical match
        if let items = index[name], !items.isEmpty {
            return items
        }

        // Word-level matching (O(words)): "chicken breast" matches "chicken"
        let words = name.components(separatedBy: CharacterSet.whitespaces)
        for word in words where word.count > 3 {
            if let items = index[word], !items.isEmpty {
                return items
            }
        }

        // Substring fallback only for short pantries (capped to avoid O(n²))
        if index.count <= 200 {
            for (key, items) in index {
                if key.contains(name) || name.contains(key) {
                    return items
                }
            }
        }

        return nil
    }

    /// Look for a substitutable pantry item when no direct match exists.
    /// Returns the pantry item name that can stand in, or nil.
    private static func findSubstitution(
        for canonicalName: String,
        in index: [String: [PantryItem]]
    ) -> String? {
        guard let group = IngredientNormalizer.substitutionGroups.first(where: { $0.contains(canonicalName) }) else { return nil }

        for substitute in group where substitute != canonicalName {
            if let items = findPantryMatch(for: substitute, in: index), let item = items.first {
                return item.name
            }
        }
        return nil
    }

    /// Common ingredient aliases for fuzzy matching.
    private static func ingredientAliases(for name: String) -> [String] {
        let aliasMap: [String: [String]] = [
            "chicken breast": ["chicken", "poultry"],
            "chicken thigh": ["chicken", "poultry"],
            "ground beef": ["beef", "mince", "ground meat"],
            "ground turkey": ["turkey", "ground poultry"],
            "bell pepper": ["pepper", "capsicum"],
            "green onion": ["scallion", "spring onion"],
            "heavy cream": ["cream", "whipping cream"],
            "sour cream": ["cream"],
            "olive oil": ["oil"],
            "vegetable oil": ["oil"],
            "coconut oil": ["oil"],
            "all-purpose flour": ["flour", "plain flour", "ap flour"],
            "kosher salt": ["salt"],
            "sea salt": ["salt"],
            "black pepper": ["pepper"],
            "garlic clove": ["garlic"],
            "fresh basil": ["basil"],
            "fresh parsley": ["parsley"],
            "fresh cilantro": ["cilantro", "coriander"],
            "parmesan cheese": ["parmesan", "parmigiano"],
            "mozzarella cheese": ["mozzarella"],
            "cheddar cheese": ["cheddar"],
            "soy sauce": ["soya sauce"],
            "brown sugar": ["sugar"],
            "powdered sugar": ["icing sugar", "confectioners sugar"],
        ]

        return aliasMap[name] ?? []
    }
}
