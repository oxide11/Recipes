import Foundation

// MARK: - Recommended Pantry Staples Service

/// Provides recommended pantry staples based on recipe frequency analysis.
/// Tracks which ingredients are used most across recipes and suggests
/// items the user should always keep stocked.
enum RecommendedStaplesService {

    struct Staple: Identifiable, Sendable {
        var id: String { name }
        var name: String
        var category: IngredientCategory
        var reason: String
        var frequency: StapleFrequency
        /// Dietary restrictions for which this staple is inappropriate.
        var excludedFor: Set<DietaryRestriction> = []
    }

    enum StapleFrequency: String, Sendable {
        case essential   // Used in >70% of recipes
        case common      // Used in 40-70% of recipes
        case recommended // Used in 20-40% of recipes
    }

    // MARK: - Universal Staples

    /// Pantry staples that every well-stocked kitchen should have.
    static let universalStaples: [Staple] = [
        // Oils & Fats
        Staple(name: "Olive oil", category: .oil, reason: "The foundation of most cooking", frequency: .essential),
        Staple(name: "Neutral oil", category: .oil, reason: "High smoke point for frying", frequency: .common),
        Staple(name: "Butter", category: .dairy, reason: "Essential for baking and sauces", frequency: .essential, excludedFor: [.vegan, .dairyFree]),

        // Seasonings
        Staple(name: "Salt", category: .spice, reason: "Used in virtually every recipe", frequency: .essential),
        Staple(name: "Black pepper", category: .spice, reason: "Universal seasoning", frequency: .essential),
        Staple(name: "Garlic", category: .vegetable, reason: "Flavour base for most cuisines", frequency: .essential),
        Staple(name: "Onion", category: .vegetable, reason: "Aromatic base ingredient", frequency: .essential),

        // Pantry basics
        Staple(name: "All-purpose flour", category: .grain, reason: "Baking, thickening, breading", frequency: .essential),
        Staple(name: "Sugar", category: .sweetener, reason: "Baking and balancing flavours", frequency: .common),
        Staple(name: "Rice", category: .grain, reason: "Versatile staple grain", frequency: .common),
        Staple(name: "Pasta", category: .grain, reason: "Quick meal base", frequency: .common),

        // Canned goods
        Staple(name: "Canned tomatoes", category: .vegetable, reason: "Base for sauces, soups, stews", frequency: .common),
        Staple(name: "Chicken broth", category: .liquid, reason: "Soups, risottos, deglazing", frequency: .common, excludedFor: [.vegetarian, .vegan]),
        Staple(name: "Vegetable broth", category: .liquid, reason: "Soups, risottos, deglazing — works for everyone", frequency: .common),
        Staple(name: "Canned beans", category: .legume, reason: "Quick protein and fiber", frequency: .recommended),

        // Condiments
        Staple(name: "Soy sauce", category: .condiment, reason: "Umami for Asian and fusion dishes", frequency: .common),
        Staple(name: "Vinegar", category: .condiment, reason: "Dressings, marinades, pickling", frequency: .common),
        Staple(name: "Honey", category: .sweetener, reason: "Natural sweetener and glazes", frequency: .recommended, excludedFor: [.vegan]),

        // Dairy
        Staple(name: "Eggs", category: .dairy, reason: "Binding, leavening, protein", frequency: .essential, excludedFor: [.vegan]),
        Staple(name: "Milk", category: .dairy, reason: "Baking and cooking", frequency: .common, excludedFor: [.vegan, .dairyFree]),
        Staple(name: "Parmesan cheese", category: .dairy, reason: "Flavour finishing for pastas and salads", frequency: .recommended, excludedFor: [.vegan, .dairyFree]),

        // Spices
        Staple(name: "Cumin", category: .spice, reason: "Essential for Mexican, Indian, Middle Eastern", frequency: .common),
        Staple(name: "Paprika", category: .spice, reason: "Colour and mild heat", frequency: .common),
        Staple(name: "Oregano", category: .herb, reason: "Italian and Mediterranean staple", frequency: .common),
        Staple(name: "Cinnamon", category: .spice, reason: "Baking and sweet dishes", frequency: .recommended),
        Staple(name: "Red pepper flakes", category: .spice, reason: "Quick heat for any dish", frequency: .recommended),
        Staple(name: "Bay leaves", category: .herb, reason: "Soups, stews, braises", frequency: .recommended),

        // Fresh
        Staple(name: "Lemon", category: .fruit, reason: "Brightness and acidity", frequency: .common),
        Staple(name: "Ginger", category: .spice, reason: "Asian cooking, marinades, teas", frequency: .recommended),
    ]

    // MARK: - Personalized Recommendations

    /// Analyze the user's recipes to find ingredients they use frequently
    /// but may not have stocked.
    static func personalizedStaples(
        recipes: [Recipe],
        pantryItems: [PantryItem],
        limit: Int = 10
    ) -> [Staple] {
        // Count ingredient frequency across all recipes
        var ingredientCounts: [String: Int] = [:]
        let totalRecipes = max(recipes.count, 1)

        for recipe in recipes {
            for ingredient in recipe.ingredients {
                let name = ingredient.name.lowercased()
                ingredientCounts[name, default: 0] += 1
            }
        }

        let pantryNames = pantryItems.map { $0.name.lowercased() }

        // Find frequently used ingredients NOT already covered in pantry.
        // Uses the same bidirectional substring match as missingStaples() so
        // "flour" in recipes is satisfied by "all-purpose flour" in the pantry, etc.
        return ingredientCounts
            .filter { !isCovered($0.key, by: pantryNames) }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { name, count in
                let percent = Double(count) / Double(totalRecipes) * 100
                let frequency: StapleFrequency
                if percent > 70 { frequency = .essential }
                else if percent > 40 { frequency = .common }
                else { frequency = .recommended }

                return Staple(
                    name: name.capitalized,
                    category: .other,
                    reason: "Used in \(count) of your recipes (\(Int(percent))%)",
                    frequency: frequency
                )
            }
    }

    /// Get universal staples that are missing from the user's pantry.
    ///
    /// - Parameters:
    ///   - pantryItems: The user's current pantry.
    ///   - dietaryRestrictions: Active dietary restrictions — staples tagged as
    ///     `excludedFor` any of these are silently omitted.
    static func missingStaples(
        pantryItems: [PantryItem],
        dietaryRestrictions: Set<DietaryRestriction> = []
    ) -> [Staple] {
        let pantryNames = pantryItems.map { $0.name.lowercased() }

        return universalStaples.filter { staple in
            // Skip staples that conflict with the user's dietary restrictions.
            guard staple.excludedFor.isDisjoint(with: dietaryRestrictions) else { return false }

            let staleName = staple.name.lowercased()

            // Check direct / substring match in pantry.
            if isCovered(staleName, by: pantryNames) { return false }

            // Check whether any pantry item belongs to the same substitution
            // group as this staple — e.g., "vegetable bouillon" covers "chicken broth".
            let group = IngredientNormalizer.substitutionGroups.first { group in
                group.contains(where: { staleName == $0 || staleName.contains($0) || $0.contains(staleName) })
            }
            if let group {
                let groupCoversStaple = pantryNames.contains { pantry in
                    group.contains(where: { pantry == $0 || pantry.contains($0) || $0.contains(pantry) })
                }
                if groupCoversStaple { return false }
            }

            return true
        }
    }

    // MARK: - Matching

    /// Bidirectional substring match: considers a staple covered if any pantry
    /// item name contains it OR it contains a pantry item name.
    ///
    /// Examples:
    ///   "flour"       covered by "all-purpose flour"  (pantry contains staple)
    ///   "onion"       covered by "yellow onion"        (pantry contains staple)
    ///   "pasta"       covered by "dried pasta"         (pantry contains staple)
    ///   "neutral oil" covered by "vegetable oil"       (staple contains pantry)
    ///   "vinegar"     covered by "white vinegar"       (pantry contains staple)
    ///   "parmesan"    covered by "parmesan cheese"     (pantry contains staple)
    private static func isCovered(_ staple: String, by pantryNames: [String]) -> Bool {
        pantryNames.contains { pantry in
            pantry == staple || pantry.contains(staple) || staple.contains(pantry)
        }
    }
}
