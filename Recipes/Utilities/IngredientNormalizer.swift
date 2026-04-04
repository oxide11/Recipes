import Foundation

// MARK: - Ingredient Normalizer

/// Shared utility for consistent ingredient name normalization and category inference.
/// Used by NoWasteMatchingEngine, RecipeIngestionService, OpenFoodFactsService,
/// PantryDeductionService, ShoppingListGenerator, and SubstitutionEngine.
enum IngredientNormalizer {

    /// Normalize an ingredient name: lowercase, trim whitespace.
    static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Normalize and collapse known synonym forms to a single canonical name.
    /// "extra-virgin olive oil" → "olive oil", "kosher salt" → "salt", etc.
    static func canonicalize(_ name: String) -> String {
        let normalized = normalize(name)
        return synonymMap[normalized] ?? normalized
    }

    // Maps every variant spelling/qualifier to one canonical ingredient name.
    static let synonymMap: [String: String] = [
        // Olive oil
        "extra-virgin olive oil": "olive oil",
        "extra virgin olive oil": "olive oil",
        "evoo": "olive oil",
        "light olive oil": "olive oil",
        // Salt
        "kosher salt": "salt",
        "sea salt": "salt",
        "table salt": "salt",
        "coarse salt": "salt",
        "fine salt": "salt",
        "iodized salt": "salt",
        // Flour
        "all-purpose flour": "flour",
        "all purpose flour": "flour",
        "plain flour": "flour",
        "ap flour": "flour",
        // Butter
        "unsalted butter": "butter",
        "salted butter": "butter",
        // Milk
        "whole milk": "milk",
        "2% milk": "milk",
        "skim milk": "milk",
        "nonfat milk": "milk",
        "low-fat milk": "milk",
        "full-fat milk": "milk",
        // Stock/broth (treat as same)
        "chicken stock": "chicken broth",
        "beef stock": "beef broth",
        "vegetable stock": "vegetable broth",
        // Cream
        "heavy whipping cream": "heavy cream",
        "whipping cream": "heavy cream",
        "double cream": "heavy cream",
        // Onion varieties
        "yellow onion": "onion",
        "white onion": "onion",
        "red onion": "onion",
        "sweet onion": "onion",
        "vidalia onion": "onion",
        "brown onion": "onion",
        // Sugar
        "granulated sugar": "sugar",
        "white sugar": "sugar",
        "caster sugar": "sugar",
        "superfine sugar": "sugar",
        // Garlic
        "garlic clove": "garlic",
        "garlic cloves": "garlic",
        "minced garlic": "garlic",
        "chopped garlic": "garlic",
        "crushed garlic": "garlic",
        "fresh garlic": "garlic",
        // Scallion / green onion
        "green onion": "scallion",
        "spring onion": "scallion",
        // Fresh / dried herb forms — collapse to one name
        "fresh basil": "basil",
        "dried basil": "basil",
        "fresh parsley": "parsley",
        "dried parsley": "parsley",
        "fresh thyme": "thyme",
        "dried thyme": "thyme",
        "fresh rosemary": "rosemary",
        "dried rosemary": "rosemary",
        "fresh oregano": "oregano",
        "dried oregano": "oregano",
        "fresh cilantro": "cilantro",
        "fresh dill": "dill",
        "dried dill": "dill",
        "fresh mint": "mint",
        "fresh chives": "chive",
        "chives": "chive",
        // Black pepper
        "black pepper": "pepper",
        "ground black pepper": "pepper",
        "freshly ground pepper": "pepper",
        "freshly ground black pepper": "pepper",
        // Tomatoes
        "canned diced tomatoes": "diced tomatoes",
        "canned crushed tomatoes": "crushed tomatoes",
        "canned tomatoes": "diced tomatoes",
        // Cheese
        "parmesan cheese": "parmesan",
        "parmigiano reggiano": "parmesan",
        "parmigiano-reggiano": "parmesan",
        "mozzarella cheese": "mozzarella",
        "cheddar cheese": "cheddar",
        // Soy sauce
        "soya sauce": "soy sauce",
        "tamari": "soy sauce",
    ]

    // MARK: - Substitution

    /// Returns the pantry item name that can substitute for `ingredientName`,
    /// or nil if nothing in the pantry covers it.
    /// `pantryCanonicalNames` should be built from `canonicalize()` applied to each pantry item name.
    static func findSubstitute(
        for ingredientName: String,
        inPantryCanonicals pantryCanonicalNames: Set<String>
    ) -> String? {
        let canonical = canonicalize(ingredientName)
        // Check direct canonical match first (caller should already do this, but be safe)
        if pantryCanonicalNames.contains(canonical) { return nil }

        guard let group = substitutionGroups.first(where: { $0.contains(canonical) }) else { return nil }

        for substitute in group where substitute != canonical {
            if pantryCanonicalNames.contains(substitute) {
                return substitute
            }
            // Also check singular/plural variant
            for variant in variants(of: substitute) where pantryCanonicalNames.contains(variant) {
                return substitute
            }
        }
        return nil
    }

    /// Groups of interchangeable ingredients. Shared between NoWasteMatchingEngine and ShoppingListGenerator.
    static let substitutionGroups: [[String]] = [
        // Cooking oils — generally interchangeable for sautéing/roasting
        ["olive oil", "vegetable oil", "canola oil", "sunflower oil", "grapeseed oil", "avocado oil", "neutral oil"],
        // Acid / brightness
        ["lemon juice", "lime juice", "white wine vinegar", "apple cider vinegar"],
        ["lemon", "lime"],
        // Vinegars
        ["white wine vinegar", "apple cider vinegar", "rice vinegar", "rice wine vinegar"],
        // Dairy fat — sour cream / yogurt interchangeable in most recipes
        ["sour cream", "greek yogurt", "plain yogurt", "creme fraiche"],
        // Cream
        ["heavy cream", "half and half", "coconut cream"],
        // Plant milks interchangeable with dairy milk in cooking/baking
        ["milk", "oat milk", "almond milk", "soy milk", "coconut milk"],
        // Sweeteners
        ["honey", "maple syrup", "agave", "agave syrup"],
        ["sugar", "brown sugar"],
        // Broth / stock / bouillon — all interchangeable as a liquid base
        ["chicken broth", "chicken stock", "chicken bouillon",
         "vegetable broth", "vegetable stock", "vegetable bouillon",
         "stock cube", "stock cubes", "bouillon cube", "bouillon cubes"],
        // Hard Italian cheeses
        ["parmesan", "pecorino"],
        // Alliums
        ["scallion", "chive"],
        ["onion", "shallot"],
        // Butter alternatives in baking
        ["butter", "coconut oil", "margarine"],
        // Soy sauce
        ["soy sauce", "coconut aminos"],
        // Tomato products
        ["diced tomatoes", "crushed tomatoes", "canned tomatoes"],
    ]

    /// Return singular and plural variants of a normalized name.
    static func variants(of normalizedName: String) -> [String] {
        var results = [normalizedName]
        if normalizedName.hasSuffix("s") {
            results.append(String(normalizedName.dropLast()))
        } else {
            results.append(normalizedName + "s")
        }
        return results
    }

    // MARK: - Category Inference from Name

    /// Infer ingredient category from an ingredient name using keyword matching.
    static func inferCategory(fromName name: String) -> IngredientCategory {
        let lower = normalize(name)

        if proteinKeywords.contains(where: lower.contains) { return .protein }
        if herbKeywords.contains(where: lower.contains) { return .herb }
        if vegetableKeywords.contains(where: lower.contains) { return .vegetable }
        if fruitKeywords.contains(where: lower.contains) { return .fruit }
        if dairyKeywords.contains(where: lower.contains) { return .dairy }
        if grainKeywords.contains(where: lower.contains) { return .grain }
        if nutKeywords.contains(where: lower.contains) { return .nut }
        if legumeKeywords.contains(where: lower.contains) { return .legume }
        if spiceKeywords.contains(where: lower.contains) { return .spice }
        if oilKeywords.contains(where: lower.contains) { return .oil }
        if condimentKeywords.contains(where: lower.contains) { return .condiment }
        if sweetenerKeywords.contains(where: lower.contains) { return .sweetener }
        if liquidKeywords.contains(where: lower.contains) { return .liquid }

        return .other
    }

    // MARK: - Category Inference from Tags

    /// Infer ingredient category from product category tags (e.g. Open Food Facts).
    static func inferCategory(fromTags tags: [String]) -> IngredientCategory {
        let joined = tags.joined(separator: " ").lowercased()

        if joined.contains("meat") || joined.contains("poultry") || joined.contains("fish") || joined.contains("seafood") { return .protein }
        if joined.contains("herb") || joined.contains("basil") || joined.contains("parsley") || joined.contains("cilantro") { return .herb }
        if joined.contains("vegetable") || joined.contains("salad") { return .vegetable }
        if joined.contains("fruit") || joined.contains("berry") { return .fruit }
        if joined.contains("dairy") || joined.contains("milk") || joined.contains("cheese") || joined.contains("yogurt") { return .dairy }
        if joined.contains("grain") || joined.contains("bread") || joined.contains("pasta") || joined.contains("cereal") || joined.contains("rice") { return .grain }
        if joined.contains("nut") || joined.contains("almond") || joined.contains("cashew") || joined.contains("peanut") { return .nut }
        if joined.contains("bean") || joined.contains("lentil") || joined.contains("legume") || joined.contains("chickpea") { return .legume }
        if joined.contains("spice") || joined.contains("seasoning") { return .spice }
        if joined.contains("oil") { return .oil }
        if joined.contains("sauce") || joined.contains("condiment") || joined.contains("ketchup") || joined.contains("mustard") { return .condiment }
        if joined.contains("sugar") || joined.contains("honey") || joined.contains("syrup") || joined.contains("sweetener") { return .sweetener }
        if joined.contains("beverage") || joined.contains("drink") || joined.contains("juice") || joined.contains("water") { return .liquid }

        return .other
    }

    // MARK: - Keyword Lists

    private static let proteinKeywords = [
        "chicken", "beef", "pork", "lamb", "turkey", "fish", "salmon", "tuna",
        "shrimp", "tofu", "egg", "sausage", "bacon", "ham", "steak", "prawn",
    ]

    private static let vegetableKeywords = [
        "onion", "garlic", "tomato", "pepper", "carrot", "potato", "celery",
        "broccoli", "spinach", "mushroom", "zucchini", "lettuce", "cucumber",
        "corn", "pea", "cabbage", "kale", "cauliflower", "asparagus", "artichoke",
        "radish", "eggplant", "leek", "turnip", "parsnip", "squash",
    ]

    private static let fruitKeywords = [
        "apple", "banana", "lemon", "lime", "orange", "berry", "strawberry",
        "blueberry", "avocado", "mango", "peach", "pear", "cranberry",
        "pomegranate", "fig", "rhubarb", "watermelon",
    ]

    private static let grainKeywords = [
        "flour", "rice", "pasta", "bread", "oat", "quinoa", "noodle",
        "tortilla", "couscous", "cereal",
    ]

    private static let dairyKeywords = [
        "milk", "cream", "butter", "cheese", "yogurt", "sour cream",
    ]

    private static let spiceKeywords = [
        "salt", "pepper", "cumin", "paprika", "cinnamon", "turmeric",
        "oregano", "thyme", "chili", "nutmeg", "ginger",
    ]

    private static let herbKeywords = [
        "basil", "parsley", "cilantro", "rosemary", "sage", "dill", "mint", "chive",
    ]

    private static let oilKeywords = [
        "oil", "olive oil", "vegetable oil", "coconut oil", "sesame oil",
    ]

    private static let condimentKeywords = [
        "soy sauce", "vinegar", "ketchup", "mustard", "mayo", "hot sauce",
        "worcestershire",
    ]

    private static let sweetenerKeywords = [
        "sugar", "honey", "syrup", "molasses", "agave",
    ]

    private static let liquidKeywords = [
        "broth", "stock", "wine", "juice", "water",
    ]

    private static let nutKeywords = [
        "almond", "walnut", "cashew", "peanut", "pecan", "pistachio", "hazelnut",
    ]

    private static let legumeKeywords = [
        "bean", "lentil", "chickpea", "edamame",
    ]
}
