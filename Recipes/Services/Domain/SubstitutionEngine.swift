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
        "rice vinegar": [
            Substitution(original: "rice vinegar", replacement: "apple cider vinegar", ratio: "1:1", notes: "Slightly more tart, works well in most recipes", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "rice vinegar", replacement: "white wine vinegar", ratio: "1:1", notes: "Similar mild acidity", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "rice vinegar", replacement: "lemon juice", ratio: "1:1", notes: "Brighter flavour, use in dressings and marinades", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "olive oil": [
            Substitution(original: "olive oil", replacement: "avocado oil", ratio: "1:1", notes: "Neutral flavour, high smoke point", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "olive oil", replacement: "vegetable oil", ratio: "1:1", notes: "Neutral flavour, good for high heat", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "olive oil", replacement: "coconut oil", ratio: "1:1", notes: "Adds slight coconut flavour", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "buttermilk": [
            Substitution(original: "buttermilk", replacement: "milk + vinegar", ratio: "1 cup milk + 1 tbsp white vinegar, let sit 5 min", notes: "Stir and let curdle before using", dietaryBenefit: []),
            Substitution(original: "buttermilk", replacement: "plain yogurt", ratio: "1:1", notes: "Thin with a little milk if needed", dietaryBenefit: []),
            Substitution(original: "buttermilk", replacement: "oat milk + lemon juice", ratio: "1 cup oat milk + 1 tbsp lemon juice", notes: "Let sit 5 min to curdle", dietaryBenefit: [.dairyFree, .vegan]),
        ],
        "sour cream": [
            Substitution(original: "sour cream", replacement: "Greek yogurt", ratio: "1:1", notes: "Works in dips, dressings, and baked goods", dietaryBenefit: []),
            Substitution(original: "sour cream", replacement: "coconut cream", ratio: "1:1", notes: "Dairy-free, slight coconut flavour", dietaryBenefit: [.dairyFree, .vegan]),
        ],
        "breadcrumbs": [
            Substitution(original: "breadcrumbs", replacement: "panko", ratio: "1:1", notes: "Lighter, crispier texture", dietaryBenefit: []),
            Substitution(original: "breadcrumbs", replacement: "rolled oats", ratio: "1:1", notes: "Pulse in food processor for finer texture", dietaryBenefit: [.glutenFree]),
            Substitution(original: "breadcrumbs", replacement: "crushed crackers", ratio: "1:1", notes: "Use plain crackers for neutral flavour", dietaryBenefit: []),
        ],
        "baking powder": [
            Substitution(original: "baking powder", replacement: "baking soda + cream of tartar", ratio: "1/4 tsp baking soda + 1/2 tsp cream of tartar per 1 tsp baking powder", notes: "Mix together before adding", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "baking soda": [
            Substitution(original: "baking soda", replacement: "baking powder", ratio: "3 tsp baking powder per 1 tsp baking soda", notes: "Will affect flavour slightly", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "lemon juice": [
            Substitution(original: "lemon juice", replacement: "lime juice", ratio: "1:1", notes: "Similar acidity, slightly different flavour", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "lemon juice", replacement: "white wine vinegar", ratio: "1:1", notes: "Less fruity, more sharp", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "lemon juice", replacement: "apple cider vinegar", ratio: "1:1", notes: "Slightly fruity acidity", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "vanilla extract": [
            Substitution(original: "vanilla extract", replacement: "maple syrup", ratio: "1:1", notes: "Adds sweetness and warmth", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "vanilla extract", replacement: "almond extract", ratio: "1/2 tsp per 1 tsp vanilla", notes: "Stronger flavour, use less", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "parmesan": [
            Substitution(original: "parmesan", replacement: "pecorino romano", ratio: "1:1", notes: "Saltier and sharper", dietaryBenefit: [.glutenFree]),
            Substitution(original: "parmesan", replacement: "nutritional yeast", ratio: "1:1", notes: "Nutty, cheesy flavour without dairy", dietaryBenefit: [.dairyFree, .vegan, .glutenFree]),
            Substitution(original: "parmesan", replacement: "grana padano", ratio: "1:1", notes: "Milder flavour, melts well", dietaryBenefit: [.glutenFree]),
        ],
        "cream cheese": [
            Substitution(original: "cream cheese", replacement: "ricotta", ratio: "1:1", notes: "Slightly grainy, works well in baked goods", dietaryBenefit: [.glutenFree]),
            Substitution(original: "cream cheese", replacement: "mascarpone", ratio: "1:1", notes: "Richer and creamier", dietaryBenefit: [.glutenFree]),
            Substitution(original: "cream cheese", replacement: "cashew cream cheese", ratio: "1:1", notes: "Blend soaked cashews with lemon juice", dietaryBenefit: [.dairyFree, .vegan, .glutenFree]),
        ],
        "honey": [
            Substitution(original: "honey", replacement: "maple syrup", ratio: "1:1", notes: "Vegan, slightly different flavour", dietaryBenefit: [.vegan]),
            Substitution(original: "honey", replacement: "agave nectar", ratio: "1:1", notes: "Milder, vegan-friendly", dietaryBenefit: [.vegan]),
        ],
        "yogurt": [
            Substitution(original: "yogurt", replacement: "sour cream", ratio: "1:1", notes: "Richer and tangier", dietaryBenefit: []),
            Substitution(original: "yogurt", replacement: "coconut yogurt", ratio: "1:1", notes: "Dairy-free alternative", dietaryBenefit: [.dairyFree, .vegan]),
            Substitution(original: "yogurt", replacement: "kefir", ratio: "1:1", notes: "Thinner, works well in baking", dietaryBenefit: []),
        ],
        "chicken broth": [
            Substitution(original: "chicken broth", replacement: "vegetable broth", ratio: "1:1", notes: "Vegan, slightly lighter flavour", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "chicken broth", replacement: "water + bouillon cube", ratio: "1 cup water + 1 cube", notes: "Adjust salt accordingly", dietaryBenefit: []),
        ],
        "white wine": [
            Substitution(original: "white wine", replacement: "chicken broth", ratio: "1:1", notes: "Non-alcoholic, adds savory depth", dietaryBenefit: []),
            Substitution(original: "white wine", replacement: "apple juice + splash of vinegar", ratio: "1:1", notes: "For a slightly sweet-acid balance", dietaryBenefit: [.vegan]),
            Substitution(original: "white wine", replacement: "white grape juice", ratio: "1:1", notes: "Sweet, non-alcoholic", dietaryBenefit: [.vegan]),
        ],
        "garlic": [
            Substitution(original: "garlic", replacement: "garlic powder", ratio: "1/8 tsp per clove", notes: "Use sparingly, more concentrated", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "garlic", replacement: "shallots", ratio: "1 shallot per 2 cloves", notes: "Milder, slightly sweet", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "onion": [
            Substitution(original: "onion", replacement: "onion powder", ratio: "1 tsp per medium onion", notes: "No texture, adjust to taste", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "onion", replacement: "shallots", ratio: "3 shallots per 1 medium onion", notes: "Milder, sweeter flavour", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "onion", replacement: "leeks", ratio: "1:1 by volume", notes: "Milder, use white and light green parts", dietaryBenefit: [.vegan, .glutenFree]),
        ],
        "cocoa powder": [
            Substitution(original: "cocoa powder", replacement: "dark chocolate (melted)", ratio: "1 oz chocolate per 3 tbsp cocoa + reduce fat by 1 tbsp", notes: "Richer flavour", dietaryBenefit: [.vegan, .glutenFree]),
            Substitution(original: "cocoa powder", replacement: "carob powder", ratio: "1:1", notes: "Naturally sweet, caffeine-free", dietaryBenefit: [.vegan, .glutenFree]),
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
