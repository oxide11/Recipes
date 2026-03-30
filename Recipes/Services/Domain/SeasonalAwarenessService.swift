import Foundation

// MARK: - Seasonal Awareness Service

/// Tracks ingredient seasonality to favor fresh, in-season produce.
enum SeasonalAwarenessService {

    struct SeasonalIngredient: Sendable {
        var name: String
        var category: IngredientCategory
        var peakSeasons: [Season]
        var availableAllYear: Bool
    }

    /// Seasonal produce database (North America-focused, extensible).
    private static let seasonalData: [SeasonalIngredient] = [
        // Spring
        SeasonalIngredient(name: "asparagus", category: .vegetable, peakSeasons: [.spring], availableAllYear: false),
        SeasonalIngredient(name: "artichoke", category: .vegetable, peakSeasons: [.spring], availableAllYear: false),
        SeasonalIngredient(name: "peas", category: .vegetable, peakSeasons: [.spring], availableAllYear: true),
        SeasonalIngredient(name: "radish", category: .vegetable, peakSeasons: [.spring], availableAllYear: true),
        SeasonalIngredient(name: "strawberry", category: .fruit, peakSeasons: [.spring, .summer], availableAllYear: true),
        SeasonalIngredient(name: "rhubarb", category: .fruit, peakSeasons: [.spring], availableAllYear: false),

        // Summer
        SeasonalIngredient(name: "tomato", category: .vegetable, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "corn", category: .vegetable, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "zucchini", category: .vegetable, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "bell pepper", category: .vegetable, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "peach", category: .fruit, peakSeasons: [.summer], availableAllYear: false),
        SeasonalIngredient(name: "watermelon", category: .fruit, peakSeasons: [.summer], availableAllYear: false),
        SeasonalIngredient(name: "blueberry", category: .fruit, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "basil", category: .herb, peakSeasons: [.summer], availableAllYear: true),
        SeasonalIngredient(name: "eggplant", category: .vegetable, peakSeasons: [.summer], availableAllYear: true),

        // Autumn
        SeasonalIngredient(name: "pumpkin", category: .vegetable, peakSeasons: [.autumn], availableAllYear: false),
        SeasonalIngredient(name: "sweet potato", category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: true),
        SeasonalIngredient(name: "apple", category: .fruit, peakSeasons: [.autumn], availableAllYear: true),
        SeasonalIngredient(name: "pear", category: .fruit, peakSeasons: [.autumn], availableAllYear: true),
        SeasonalIngredient(name: "cranberry", category: .fruit, peakSeasons: [.autumn], availableAllYear: false),
        SeasonalIngredient(name: "butternut squash", category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "brussels sprout", category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: true),
        SeasonalIngredient(name: "fig", category: .fruit, peakSeasons: [.autumn], availableAllYear: false),

        // Winter
        SeasonalIngredient(name: "citrus", category: .fruit, peakSeasons: [.winter], availableAllYear: true),
        SeasonalIngredient(name: "kale", category: .vegetable, peakSeasons: [.winter, .autumn], availableAllYear: true),
        SeasonalIngredient(name: "cauliflower", category: .vegetable, peakSeasons: [.winter], availableAllYear: true),
        SeasonalIngredient(name: "parsnip", category: .vegetable, peakSeasons: [.winter], availableAllYear: false),
        SeasonalIngredient(name: "turnip", category: .vegetable, peakSeasons: [.winter], availableAllYear: true),
        SeasonalIngredient(name: "pomegranate", category: .fruit, peakSeasons: [.winter], availableAllYear: false),
        SeasonalIngredient(name: "leek", category: .vegetable, peakSeasons: [.winter, .spring], availableAllYear: true),

        // Year-round staples
        SeasonalIngredient(name: "onion", category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "garlic", category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "potato", category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "carrot", category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "lemon", category: .fruit, peakSeasons: [.winter, .spring], availableAllYear: true),
        SeasonalIngredient(name: "banana", category: .fruit, peakSeasons: Season.allCases, availableAllYear: true),
    ]

    /// Get ingredients that are currently in season.
    static func currentlyInSeason() -> [SeasonalIngredient] {
        let current = Season.current
        return seasonalData.filter { $0.peakSeasons.contains(current) }
    }

    /// Pre-built dictionary for O(1) lookups instead of linear scan.
    private static let seasonalLookup: [String: SeasonalIngredient] = {
        Dictionary(uniqueKeysWithValues: seasonalData.map { ($0.name, $0) })
    }()

    /// Check if a specific ingredient is in season.
    static func isInSeason(_ ingredientName: String) -> Bool {
        let current = Season.current
        let name = ingredientName.lowercased()
        guard let ingredient = seasonalLookup[name] else {
            return true // Unknown ingredients assumed available
        }
        return ingredient.peakSeasons.contains(current)
    }

    /// Get seasonal recommendations for a given season.
    static func recommendations(for season: Season) -> [SeasonalIngredient] {
        seasonalData.filter { $0.peakSeasons.contains(season) }
    }

    /// Score a recipe based on how seasonal its ingredients are.
    static func seasonalityScore(ingredientNames: [String]) -> Double {
        guard !ingredientNames.isEmpty else { return 0 }
        let inSeasonCount = ingredientNames.filter { isInSeason($0) }.count
        return Double(inSeasonCount) / Double(ingredientNames.count)
    }
}
