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
        // SPRING
        SeasonalIngredient(name: "asparagus",      category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "artichoke",      category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "rhubarb",        category: .fruit,     peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "peas",           category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "snap peas",      category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "radish",         category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "spinach",        category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "arugula",        category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "fava beans",     category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "mint",           category: .herb,      peakSeasons: [.spring, .summer], availableAllYear: false),
        SeasonalIngredient(name: "watercress",     category: .vegetable, peakSeasons: [.spring],          availableAllYear: false),
        SeasonalIngredient(name: "fennel",         category: .vegetable, peakSeasons: [.spring, .autumn], availableAllYear: false),
        SeasonalIngredient(name: "strawberry",     category: .fruit,     peakSeasons: [.spring, .summer], availableAllYear: false),
        SeasonalIngredient(name: "leek",           category: .vegetable, peakSeasons: [.winter, .spring], availableAllYear: false),

        // SUMMER
        SeasonalIngredient(name: "tomato",         category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "cherry tomato",  category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "corn",           category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "zucchini",       category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "yellow squash",  category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "bell pepper",    category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "jalapeño",       category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "shishito pepper",category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "eggplant",       category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "cucumber",       category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "green bean",     category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "okra",           category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "tomatillo",      category: .vegetable, peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "basil",          category: .herb,      peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "lemongrass",     category: .herb,      peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "peach",          category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "nectarine",      category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "watermelon",     category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "cantaloupe",     category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "blueberry",      category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "blackberry",     category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "raspberry",      category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "plum",           category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "fig",            category: .fruit,     peakSeasons: [.summer, .autumn], availableAllYear: false),
        SeasonalIngredient(name: "mango",          category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "lime",           category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),
        SeasonalIngredient(name: "passion fruit",  category: .fruit,     peakSeasons: [.summer],          availableAllYear: false),

        // AUTUMN
        SeasonalIngredient(name: "pumpkin",        category: .vegetable, peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "sweet potato",   category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "butternut squash",category: .vegetable,peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "acorn squash",   category: .vegetable, peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "delicata squash",category: .vegetable, peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "brussels sprout",category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "kale",           category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "beet",           category: .vegetable, peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "parsnip",        category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "turnip",         category: .vegetable, peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "chestnut",       category: .other,     peakSeasons: [.autumn, .winter], availableAllYear: false),
        SeasonalIngredient(name: "persimmon",      category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "apple",          category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "pear",           category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "cranberry",      category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "grape",          category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "quince",         category: .fruit,     peakSeasons: [.autumn],          availableAllYear: false),
        SeasonalIngredient(name: "pomegranate",    category: .fruit,     peakSeasons: [.autumn, .winter], availableAllYear: false),

        // WINTER
        SeasonalIngredient(name: "cauliflower",    category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "celery root",    category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "sunchoke",       category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "rutabaga",       category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "radicchio",      category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "endive",         category: .vegetable, peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "meyer lemon",    category: .fruit,     peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "blood orange",   category: .fruit,     peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "grapefruit",     category: .fruit,     peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "navel orange",   category: .fruit,     peakSeasons: [.winter],          availableAllYear: false),
        SeasonalIngredient(name: "clementine",     category: .fruit,     peakSeasons: [.winter],          availableAllYear: false),

        // YEAR-ROUND STAPLES — kept for scoring only, badge suppressed by availableAllYear: true
        SeasonalIngredient(name: "onion",          category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "garlic",         category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "potato",         category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "carrot",         category: .vegetable, peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "lemon",          category: .fruit,     peakSeasons: Season.allCases, availableAllYear: true),
        SeasonalIngredient(name: "banana",         category: .fruit,     peakSeasons: Season.allCases, availableAllYear: true),
    ]

    /// Get ingredients that are currently in season.
    static func currentlyInSeason(hemisphere: Hemisphere = .northern) -> [SeasonalIngredient] {
        let current = Season.current(for: hemisphere)
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
        guard let ingredient = seasonalLookup[name], !ingredient.availableAllYear else {
            return false // Unknown ingredients and year-round staples don't get the badge
        }
        return ingredient.peakSeasons.contains(current)
    }

    /// Get seasonal recommendations for a given season.
    static func recommendations(for season: Season) -> [SeasonalIngredient] {
        seasonalData.filter { $0.peakSeasons.contains(season) }
    }

    /// Score a recipe based on how seasonal its ingredients are.
    /// Only considers ingredients that exist in the seasonal database — pantry staples
    /// and unknown ingredients are ignored so they don't inflate the score.
    static func seasonalityScore(ingredientNames: [String]) -> Double {
        let known = ingredientNames.filter { seasonalLookup[$0.lowercased()] != nil }
        guard !known.isEmpty else { return 0 }
        let inSeasonCount = known.filter { isInSeason($0) }.count
        return Double(inSeasonCount) / Double(known.count)
    }
}
