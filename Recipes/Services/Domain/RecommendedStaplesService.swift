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
        Staple(name: "Vegetable oil", category: .oil, reason: "High smoke point for frying", frequency: .common),
        Staple(name: "Butter", category: .dairy, reason: "Essential for baking and sauces", frequency: .essential),

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
        Staple(name: "Chicken broth", category: .liquid, reason: "Soups, risottos, deglazing", frequency: .common),
        Staple(name: "Canned beans", category: .legume, reason: "Quick protein and fiber", frequency: .recommended),

        // Condiments
        Staple(name: "Soy sauce", category: .condiment, reason: "Umami for Asian and fusion dishes", frequency: .common),
        Staple(name: "Vinegar", category: .condiment, reason: "Dressings, marinades, pickling", frequency: .common),
        Staple(name: "Honey", category: .sweetener, reason: "Natural sweetener and glazes", frequency: .recommended),

        // Dairy
        Staple(name: "Eggs", category: .dairy, reason: "Binding, leavening, protein", frequency: .essential),
        Staple(name: "Milk", category: .dairy, reason: "Baking and cooking", frequency: .common),
        Staple(name: "Parmesan cheese", category: .dairy, reason: "Flavour finishing for pastas and salads", frequency: .recommended),

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

        let pantryNames = Set(pantryItems.map { $0.name.lowercased() })

        // Find frequently used ingredients NOT in pantry
        return ingredientCounts
            .filter { !pantryNames.contains($0.key) }
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
    static func missingStaples(pantryItems: [PantryItem]) -> [Staple] {
        let pantryNames = Set(pantryItems.map { $0.name.lowercased() })

        return universalStaples.filter { staple in
            !pantryNames.contains(staple.name.lowercased())
        }
    }
}
