import Foundation
import SwiftData

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack, dessert
}

// MARK: - Planned Meal

@Model
final class PlannedMeal {
    var id: UUID
    var mealType: MealType
    var date: Date

    @Relationship
    var recipe: Recipe?

    @Relationship
    var variation: RecipeVariation?

    var servings: Int
    var notes: String?
    var isCompleted: Bool

    init(
        mealType: MealType,
        date: Date,
        recipe: Recipe? = nil,
        variation: RecipeVariation? = nil,
        servings: Int = 1,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.mealType = mealType
        self.date = date
        self.recipe = recipe
        self.variation = variation
        self.servings = servings
        self.notes = notes
        self.isCompleted = false
    }
}

// MARK: - Meal Plan

@Model
final class MealPlan {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date

    @Relationship(deleteRule: .cascade)
    var meals: [PlannedMeal]

    var budgetTarget: Double?
    var calorieTarget: Int?
    var proteinTargetGrams: Int?

    var dateCreated: Date

    /// Total estimated prep time for the entire meal plan.
    var totalPrepTimeMinutes: Int {
        meals.compactMap { $0.recipe?.estimatedTotalMinutes }.reduce(0, +)
    }

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        budgetTarget: Double? = nil,
        calorieTarget: Int? = nil,
        proteinTargetGrams: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.meals = []
        self.budgetTarget = budgetTarget
        self.calorieTarget = calorieTarget
        self.proteinTargetGrams = proteinTargetGrams
        self.dateCreated = .now
    }
}
