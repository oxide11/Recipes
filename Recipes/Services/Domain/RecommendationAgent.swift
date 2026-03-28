import Foundation
import SwiftData
import FoundationModels

// MARK: - Recommendation Agent

/// Personalized recipe recommendation engine that uses cooking history,
/// user reviews, pantry state, and AI to suggest recipes.
/// Includes blind-spot detection for unexplored cuisines and techniques.
@Observable
@MainActor
final class RecommendationAgent {
    private let aiRouter: AIServiceRouter

    init(aiRouter: AIServiceRouter) {
        self.aiRouter = aiRouter
    }

    // MARK: - Types

    struct Recommendation: Identifiable, Sendable {
        let id = UUID()
        var title: String
        var reason: String
        var category: RecommendationCategory
        var score: Double
        var cuisineSuggestion: String?
        var recipeID: UUID?
    }

    enum RecommendationCategory: String, Sendable {
        case tryAgain       // High-rated recipes the user hasn't made recently
        case blindSpot      // Unexplored cuisines or techniques
        case seasonal       // Based on current season
        case noWaste        // Uses expiring pantry items
        case nutritional    // Fills gaps in nutritional goals
        case quickMeal      // Fast recipes for busy days
        case newRecipe      // AI-generated suggestion
    }

    // MARK: - Generate Recommendations

    /// Generate a personalized set of recommendations based on all available signals.
    func generateRecommendations(
        recipes: [Recipe],
        pantryItems: [PantryItem],
        profile: UserProfile?
    ) async -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // 1. "Cook Again" - highly rated recipes not made recently
        recommendations.append(contentsOf: cookAgainRecommendations(recipes: recipes))

        // 2. No Waste - recipes using expiring items
        recommendations.append(contentsOf: noWasteRecommendations(recipes: recipes, pantryItems: pantryItems))

        // 3. Seasonal picks
        recommendations.append(contentsOf: seasonalRecommendations(recipes: recipes))

        // 4. Quick meal suggestions
        recommendations.append(contentsOf: quickMealRecommendations(recipes: recipes, pantryItems: pantryItems))

        // 5. Blind spot detection via AI
        let blindSpots = await blindSpotRecommendations(recipes: recipes, profile: profile)
        recommendations.append(contentsOf: blindSpots)

        // Sort by score and deduplicate
        let seen = NSMutableSet()
        return recommendations
            .sorted { $0.score > $1.score }
            .filter { rec in
                let key = (rec.recipeID?.uuidString ?? rec.title) as NSString
                if seen.contains(key) { return false }
                seen.add(key)
                return true
            }
    }

    // MARK: - Cook Again

    private func cookAgainRecommendations(recipes: [Recipe]) -> [Recommendation] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now

        return recipes
            .filter { recipe in
                guard let avgRating = recipe.averageRating, avgRating >= 4.0 else { return false }
                let lastCooked = recipe.cookingLog.map(\.date).max()
                return lastCooked == nil || lastCooked! < thirtyDaysAgo
            }
            .prefix(3)
            .map { recipe in
                Recommendation(
                    title: recipe.title,
                    reason: "You rated this \(String(format: "%.1f", recipe.averageRating ?? 0)) stars — time to make it again!",
                    category: .tryAgain,
                    score: (recipe.averageRating ?? 0) * 10,
                    recipeID: recipe.id
                )
            }
    }

    // MARK: - No Waste

    private func noWasteRecommendations(recipes: [Recipe], pantryItems: [PantryItem]) -> [Recommendation] {
        let expiring = NoWasteMatchingEngine.recipesForExpiringItems(recipes: recipes, pantryItems: pantryItems)

        return expiring.prefix(3).map { match in
            let expiringNames = match.expiringIngredientsUsed.joined(separator: ", ")
            return Recommendation(
                title: match.recipe.title,
                reason: "Uses expiring ingredients: \(expiringNames)",
                category: .noWaste,
                score: match.score + 20, // Boost urgency
                recipeID: match.recipe.id
            )
        }
    }

    // MARK: - Seasonal

    private func seasonalRecommendations(recipes: [Recipe]) -> [Recommendation] {
        let season = Season.current
        let inSeason = SeasonalAwarenessService.recommendations(for: season)
        let seasonalNames = Set(inSeason.map(\.name))

        return recipes
            .filter { recipe in
                let names = Set(recipe.ingredients.map { $0.name.lowercased() })
                return !names.intersection(seasonalNames).isEmpty
            }
            .sorted { r1, r2 in
                let s1 = SeasonalAwarenessService.seasonalityScore(ingredientNames: r1.ingredients.map(\.name))
                let s2 = SeasonalAwarenessService.seasonalityScore(ingredientNames: r2.ingredients.map(\.name))
                return s1 > s2
            }
            .prefix(2)
            .map { recipe in
                Recommendation(
                    title: recipe.title,
                    reason: "Perfect for \(season.rawValue) with fresh seasonal ingredients",
                    category: .seasonal,
                    score: 35,
                    recipeID: recipe.id
                )
            }
    }

    // MARK: - Quick Meals

    private func quickMealRecommendations(recipes: [Recipe], pantryItems: [PantryItem]) -> [Recommendation] {
        let quick = NoWasteMatchingEngine.lastMinuteRecipes(
            recipes: recipes,
            pantryItems: pantryItems,
            maxMinutes: 30
        )

        return quick.prefix(2).map { match in
            Recommendation(
                title: match.recipe.title,
                reason: "Ready in \(match.recipe.formattedDuration) with ingredients you have",
                category: .quickMeal,
                score: match.score + 10,
                recipeID: match.recipe.id
            )
        }
    }

    // MARK: - Blind Spot Detection

    private func blindSpotRecommendations(
        recipes: [Recipe],
        profile: UserProfile?
    ) async -> [Recommendation] {
        guard !recipes.isEmpty else { return [] }

        // Analyze user's cooking history
        let cuisineCounts = Dictionary(grouping: recipes.filter { $0.cookCount > 0 }, by: \.cuisine)
            .mapValues { $0.map(\.cookCount).reduce(0, +) }
        let topCuisines = cuisineCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key.rawValue }

        let allIngredients = recipes
            .filter { $0.cookCount > 0 }
            .flatMap { $0.ingredients.map(\.name) }
        let ingredientCounts = Dictionary(allIngredients.map { ($0, 1) }, uniquingKeysWith: +)
        let topIngredients = ingredientCounts.sorted { $0.value > $1.value }.prefix(10).map(\.key)

        // Find unexplored cuisines locally first
        let cookedCuisines = Set(cuisineCounts.keys)
        let unexploredCuisines = Cuisine.allCases.filter { !cookedCuisines.contains($0) }

        var recommendations: [Recommendation] = []

        // Local blind spots
        for cuisine in unexploredCuisines.prefix(2) {
            recommendations.append(Recommendation(
                title: "Explore \(cuisine.rawValue.capitalized) Cooking",
                reason: "You haven't tried any \(cuisine.rawValue.capitalized) recipes yet",
                category: .blindSpot,
                score: 30,
                cuisineSuggestion: cuisine.rawValue
            ))
        }

        // AI-powered blind spots for deeper insights
        do {
            let preferences = profile.map {
                "Skill: \($0.skillLevel.rawValue), Restrictions: \($0.dietaryRestrictions.map(\.rawValue).joined(separator: ", "))"
            } ?? "No specific preferences"

            let suggestions = try await aiRouter.foundationModelService.suggestBlindSpots(
                cookedCuisines: topCuisines,
                cookedIngredients: topIngredients,
                preferences: preferences
            )

            for idea in suggestions.recipeIdeas.prefix(3) {
                recommendations.append(Recommendation(
                    title: idea,
                    reason: "AI-suggested recipe to broaden your repertoire",
                    category: .blindSpot,
                    score: 25
                ))
            }

            for technique in suggestions.newTechniques.prefix(2) {
                recommendations.append(Recommendation(
                    title: "Try: \(technique)",
                    reason: "A cooking technique you haven't explored",
                    category: .blindSpot,
                    score: 20
                ))
            }
        } catch {
            // AI unavailable — local recommendations are sufficient
        }

        return recommendations
    }

    // MARK: - User Context Summary

    /// Build a summary of the user's cooking context for AI prompts.
    static func buildUserContext(
        recipes: [Recipe],
        profile: UserProfile?
    ) -> String {
        let cookedRecipes = recipes.filter { $0.cookCount > 0 }
        let totalCooked = cookedRecipes.map(\.cookCount).reduce(0, +)
        let favoriteCuisines = Dictionary(grouping: cookedRecipes, by: \.cuisine)
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)
            .map { $0.key.rawValue }

        let avgRating = cookedRecipes.compactMap(\.averageRating).reduce(0, +) / max(Double(cookedRecipes.count), 1)

        var context = "User has cooked \(totalCooked) meals across \(cookedRecipes.count) recipes. "
        context += "Favorite cuisines: \(favoriteCuisines.joined(separator: ", ")). "
        context += "Average recipe rating: \(String(format: "%.1f", avgRating))/5. "

        if let profile {
            if !profile.dietaryRestrictions.isEmpty {
                context += "Dietary restrictions: \(profile.dietaryRestrictions.map(\.rawValue).joined(separator: ", ")). "
            }
            context += "Skill level: \(profile.skillLevel.rawValue). "
        }

        return context
    }
}
