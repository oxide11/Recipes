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
