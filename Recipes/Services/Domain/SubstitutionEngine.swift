import Foundation

// MARK: - Substitution Engine

/// Suggests ingredient substitutions based on dietary restrictions,
/// availability, and user preferences.
enum SubstitutionEngine {

    struct Substitution: Sendable {
        var original: String
        var replacement: String
        var ratio: String
        var notes: String
        var dietaryBenefit: [DietaryRestriction]
    }

    /// Common substitution rules that don't require AI.
    private static let knownSubstitutions: [String: [Substitution]] = [
        "butter": [
            Substitution(original: "butter", replacement: "coconut oil", ratio: "1:1", notes: "Works well in baking", dietaryBenefit: [.dairyFree, .vegan]),
            Substitution(original: "butter", replacement: "olive oil", ratio: "3/4 cup per 1 cup butter", notes: "Best for savory dishes", dietaryBenefit: [.dairyFree, .vegan]),
            Substitution(original: "butter", replacement: "applesauce", ratio: "1:1", notes: "Reduces fat in baking, adds moisture", dietaryBenefit: [.dairyFree, .vegan]),
        ],
        "all-purpose flour": [
            Substitution(original: "all-purpose flour", replacement: "almond flour", ratio: "1:1", notes: "Denser result, nutty flavor", dietaryBenefit: [.glutenFree]),
            Substitution(original: "all-purpose flour", replacement: "oat flour", ratio: "1:1", notes: "Good for cookies and pancakes", dietaryBenefit: [.glutenFree]),
            Substitution(original: "all-purpose flour", replacement: "coconut flour", ratio: "1/4 cup per 1 cup flour", notes: "Very absorbent, increase liquids", dietaryBenefit: [.glutenFree]),
        ],
        "milk": [
            Substitution(original: "milk", replacement: "oat milk", ratio: "1:1", notes: "Creamy, good for baking", dietaryBenefit: [.dairyFree, .vegan, .nutFree]),
            Substitution(original: "milk", replacement: "almond milk", ratio: "1:1", notes: "Light, slightly nutty", dietaryBenefit: [.dairyFree, .vegan]),
            Substitution(original: "milk", replacement: "coconut milk", ratio: "1:1", notes: "Rich, slight coconut flavor", dietaryBenefit: [.dairyFree, .vegan, .nutFree]),
        ],
        "egg": [
            Substitution(original: "egg", replacement: "flax egg (1 tbsp ground flax + 3 tbsp water)", ratio: "1 egg", notes: "Let sit 5 min to gel", dietaryBenefit: [.vegan]),
            Substitution(original: "egg", replacement: "1/4 cup applesauce", ratio: "1 egg", notes: "Adds moisture and sweetness", dietaryBenefit: [.vegan]),
            Substitution(original: "egg", replacement: "1/4 cup mashed banana", ratio: "1 egg", notes: "Adds banana flavor", dietaryBenefit: [.vegan]),
        ],
        "soy sauce": [
            Substitution(original: "soy sauce", replacement: "coconut aminos", ratio: "1:1", notes: "Slightly sweeter, less sodium", dietaryBenefit: [.glutenFree]),
            Substitution(original: "soy sauce", replacement: "tamari", ratio: "1:1", notes: "Similar flavor, check label for GF", dietaryBenefit: [.glutenFree]),
        ],
        "heavy cream": [
            Substitution(original: "heavy cream", replacement: "full-fat coconut cream", ratio: "1:1", notes: "Chill can overnight, use solid portion", dietaryBenefit: [.dairyFree, .vegan]),
            Substitution(original: "heavy cream", replacement: "cashew cream", ratio: "1:1", notes: "Blend soaked cashews with water", dietaryBenefit: [.dairyFree, .vegan]),
        ],
        "sugar": [
            Substitution(original: "sugar", replacement: "honey", ratio: "3/4 cup per 1 cup sugar", notes: "Reduce other liquids slightly", dietaryBenefit: []),
            Substitution(original: "sugar", replacement: "maple syrup", ratio: "3/4 cup per 1 cup sugar", notes: "Adds distinct flavor", dietaryBenefit: [.vegan]),
            Substitution(original: "sugar", replacement: "stevia", ratio: "1 tsp per 1 cup sugar", notes: "Zero calorie, very concentrated", dietaryBenefit: [.keto, .lowCarb]),
        ],
    ]

    /// Find substitutions for an ingredient, filtered by dietary restrictions.
    static func findSubstitutions(
        for ingredient: String,
        restrictions: [DietaryRestriction] = []
    ) -> [Substitution] {
        let key = ingredient.lowercased().trimmingCharacters(in: .whitespaces)

        guard let subs = knownSubstitutions[key] else {
            return []
        }

        if restrictions.isEmpty {
            return subs
        }

        return subs.filter { sub in
            restrictions.allSatisfy { restriction in
                sub.dietaryBenefit.contains(restriction)
            }
        }
    }

    /// Check if any ingredients in a recipe need substitution for given restrictions.
    static func findRequiredSubstitutions(
        ingredients: [Ingredient],
        restrictions: [DietaryRestriction]
    ) -> [(Ingredient, [Substitution])] {
        ingredients.compactMap { ingredient in
            let subs = findSubstitutions(for: ingredient.name, restrictions: restrictions)
            return subs.isEmpty ? nil : (ingredient, subs)
        }
    }
}
