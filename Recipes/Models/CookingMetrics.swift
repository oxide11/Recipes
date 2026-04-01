import Foundation
import SwiftData

// MARK: - Cooking Metrics

/// Aggregated cooking statistics for the user's dashboard and year-in-review.
struct CookingMetrics: Sendable {
    var totalRecipesCooked: Int = 0
    var totalTimeCookingMinutes: Int = 0
    var totalTimePrepMinutes: Int = 0
    var totalTimeShoppingMinutes: Int = 0
    var totalGrocerySpend: Double = 0
    var estimatedDiningOutSavings: Double = 0

    var mostUsedIngredients: [IngredientUsage] = []
    var favoriteCuisines: [CuisineUsage] = []
    var topRecipes: [RecipeUsage] = []

    // Time savings from optimized cooking
    var totalTimeSavedMinutes: Int = 0

    // Restaurant journal stats
    var totalRestaurantsVisited: Int = 0
    var totalDishesOrdered: Int = 0
    var averageRestaurantRating: Double?
    var topRestaurantCuisines: [CuisineUsage] = []
    var lastRestaurantVisitDate: Date?

    var averageCookingSessionMinutes: Double {
        guard totalRecipesCooked > 0 else { return 0 }
        return Double(totalTimeCookingMinutes) / Double(totalRecipesCooked)
    }
}

struct IngredientUsage: Sendable, Identifiable {
    var id: String { name }
    var name: String
    var count: Int
}

struct CuisineUsage: Sendable, Identifiable {
    var id: String { cuisine.rawValue }
    var cuisine: Cuisine
    var count: Int
}

struct RecipeUsage: Sendable, Identifiable {
    var id: UUID { recipeID }
    var recipeID: UUID
    var title: String
    var cookCount: Int
    var averageRating: Double?
}

// MARK: - Metrics Calculator

enum MetricsCalculator {

    static func calculate(
        recipes: [Recipe],
        receipts: [GroceryReceipt],
        restaurantEntries: [RestaurantJournalEntry] = [],
        averageMealOutCost: Double = 18.0
    ) -> CookingMetrics {
        let allLogs = recipes.flatMap(\.cookingLog)

        let totalCooked = allLogs.count
        let totalCookTime = allLogs.compactMap(\.cookTimeMinutes).reduce(0, +)
        let totalPrepTime = allLogs.compactMap(\.prepTimeMinutes).reduce(0, +)
        let totalGrocery = receipts.map(\.totalAmount).reduce(0, +)
        let estimatedSavings = Double(totalCooked) * averageMealOutCost - totalGrocery

        // Time saved
        let totalTimeSaved = allLogs.compactMap(\.timeSavedMinutes).reduce(0, +)

        // Most used ingredients
        var ingredientCounts: [String: Int] = [:]
        for recipe in recipes {
            let count = recipe.cookCount
            guard count > 0 else { continue }
            for ingredient in recipe.ingredients {
                ingredientCounts[ingredient.name, default: 0] += count
            }
        }
        let topIngredients = ingredientCounts
            .map { IngredientUsage(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(20)

        // Favourite cuisines
        var cuisineCounts: [Cuisine: Int] = [:]
        for recipe in recipes {
            cuisineCounts[recipe.cuisine, default: 0] += recipe.cookCount
        }
        let topCuisines = cuisineCounts
            .filter { $0.value > 0 }
            .map { CuisineUsage(cuisine: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        // Top recipes
        let topRecipes = recipes
            .filter { $0.cookCount > 0 }
            .map { RecipeUsage(recipeID: $0.id, title: $0.title, cookCount: $0.cookCount, averageRating: $0.averageRating) }
            .sorted { $0.cookCount > $1.cookCount }
            .prefix(10)

        // Restaurant stats
        let totalRestaurants = restaurantEntries.count
        let allDishes = restaurantEntries.flatMap(\.dishesOrdered)
        let restaurantRatings = restaurantEntries.compactMap(\.rating)
        let avgRestaurantRating: Double? = restaurantRatings.isEmpty ? nil
            : Double(restaurantRatings.reduce(0, +)) / Double(restaurantRatings.count)

        var restaurantCuisineCounts: [Cuisine: Int] = [:]
        for entry in restaurantEntries {
            if let cuisine = entry.cuisine {
                restaurantCuisineCounts[cuisine, default: 0] += 1
            }
        }
        let topRestaurantCuisines = restaurantCuisineCounts
            .map { CuisineUsage(cuisine: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let lastVisit = restaurantEntries.map(\.dateVisited).max()

        return CookingMetrics(
            totalRecipesCooked: totalCooked,
            totalTimeCookingMinutes: totalCookTime,
            totalTimePrepMinutes: totalPrepTime,
            totalTimeShoppingMinutes: 0,
            totalGrocerySpend: totalGrocery,
            estimatedDiningOutSavings: max(0, estimatedSavings),
            mostUsedIngredients: Array(topIngredients),
            favoriteCuisines: topCuisines,
            topRecipes: Array(topRecipes),
            totalTimeSavedMinutes: totalTimeSaved,
            totalRestaurantsVisited: totalRestaurants,
            totalDishesOrdered: allDishes.count,
            averageRestaurantRating: avgRestaurantRating,
            topRestaurantCuisines: topRestaurantCuisines,
            lastRestaurantVisitDate: lastVisit
        )
    }
}
