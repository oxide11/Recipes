import Foundation
import FoundationModels

// MARK: - AI Meal Plan Generator

/// Uses on-device AI or cloud services to auto-generate a balanced meal plan
/// from the user's recipe collection, dietary preferences, and pantry state.
@Observable
final class MealPlanGenerator: Sendable {

    /// Reusable session — allocating a fresh LanguageModelSession costs 10-30 MB
    /// that isn't freed until the session is released. One session per generator
    /// instance avoids repeated allocation overhead across plan generations.
    private nonisolated(unsafe) lazy var session = LanguageModelSession()

    /// Generate a meal plan using AI, selecting from the user's existing recipes.
    /// Accepts pre-extracted string data to avoid sending non-Sendable SwiftData models across isolation boundaries.
    func generatePlan(
        recipeDescriptions: [String],
        pantryItemNames: [String],
        constraintsText: String,
        startDate: Date,
        days: Int,
        mealsPerDay: [MealType] = [.breakfast, .lunch, .dinner]
    ) async throws -> GeneratedMealPlan {

        let recipeList = recipeDescriptions.map(\.sanitizedForAI).joined(separator: "\n")
        let pantryList = pantryItemNames.map(\.sanitizedForAI).joined(separator: ", ")
        let constraints = constraintsText.sanitizedForAI

        let mealTypeNames = mealsPerDay.map(\.rawValue).joined(separator: ", ")

        let prompt = """
        Generate a \(days)-day meal plan with these meals each day: \(mealTypeNames).

        Available recipes:
        \(recipeList)

        Currently in pantry: \(pantryList.isEmpty ? "not specified" : pantryList)
        \(constraints.isEmpty ? "" : "Constraints: \(constraints)")

        Rules:
        - Prefer recipes that use pantry ingredients to minimize waste
        - Vary cuisines and proteins across days
        - Balance meal complexity (mix quick and involved meals)
        - Avoid repeating the same recipe within 2 days
        - Each meal assignment must reference an exact recipe title from the list above
        """

        let response = try await session.respond(to: prompt, generating: GeneratedMealPlan.self)
        return response.content
    }


    /// Convert an AI-generated plan into PlannedMeal objects.
    func convertToPlannedMeals(
        plan: GeneratedMealPlan,
        recipes: [Recipe],
        startDate: Date
    ) -> [PlannedMeal] {
        var meals: [PlannedMeal] = []

        for day in plan.days {
            let dayOffset = day.dayNumber - 1
            guard let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }

            for assignment in day.meals {
                let mealType = MealType.allCases.first { $0.rawValue == assignment.mealType.lowercased() }
                    ?? .dinner

                // Match to an existing recipe by title
                let recipe = recipes.first { $0.title.localizedCaseInsensitiveContains(assignment.recipeTitle) }

                let meal = PlannedMeal(
                    mealType: mealType,
                    date: date,
                    recipe: recipe,
                    servings: assignment.servings,
                    notes: assignment.reasoning.isEmpty ? nil : assignment.reasoning
                )
                meals.append(meal)
            }
        }

        return meals
    }
}

// MARK: - Generable Types

@Generable
struct GeneratedMealPlan {
    @Guide(description: "The planned days with meal assignments")
    var days: [GeneratedDay]

    @Guide(description: "Brief summary of the plan's balance and variety")
    var summary: String
}

@Generable
struct GeneratedDay {
    @Guide(description: "Day number starting from 1")
    var dayNumber: Int

    @Guide(description: "Meal assignments for this day")
    var meals: [GeneratedMealAssignment]
}

@Generable
struct GeneratedMealAssignment {
    @Guide(description: "Meal type: breakfast, lunch, dinner, snack, or dessert")
    var mealType: String

    @Guide(description: "Exact recipe title from the provided list")
    var recipeTitle: String

    @Guide(description: "Number of servings")
    var servings: Int

    @Guide(description: "Brief reasoning for choosing this recipe")
    var reasoning: String
}
