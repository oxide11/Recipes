import Foundation
import SwiftData

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Sendable, Identifiable {
    var id: String { rawValue }
    case breakfast, lunch, dinner, snack, dessert, appetizer, side

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        case .dessert:   return "Dessert"
        case .appetizer: return "Appetizer"
        case .side:      return "Side"
        }
    }
}

extension MealType {
    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch:     return 1
        case .dinner:    return 2
        case .snack:     return 3
        case .dessert:   return 4
        case .appetizer: return 5
        case .side:      return 6
        }
    }

    var systemImageName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "carrot.fill"
        case .dessert:   return "birthday.cake.fill"
        case .appetizer: return "fork.knife"
        case .side:      return "leaf.fill"
        }
    }
}

// MARK: - Planned Meal

@Model
final class PlannedMeal {
    var id: UUID
    var mealType: MealType
    var date: Date

    @Relationship(deleteRule: .nullify, inverse: \Recipe.plannedMeals)
    var recipe: Recipe?

    @Relationship(deleteRule: .nullify)
    var variation: RecipeVariation?

    var servings: Int
    var notes: String?
    var isAISuggested: Bool

    /// True when the recipe has a cooking log entry on this meal's date.
    /// Derived — not persisted by SwiftData.
    var isCompleted: Bool {
        guard let recipe else { return false }
        return recipe.cookingLog.contains {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    init(
        mealType: MealType,
        date: Date,
        recipe: Recipe? = nil,
        variation: RecipeVariation? = nil,
        servings: Int = 1,
        notes: String? = nil,
        isAISuggested: Bool = false
    ) {
        self.id = UUID()
        self.mealType = mealType
        self.date = date
        self.recipe = recipe
        self.variation = variation
        self.servings = servings
        self.notes = notes
        self.isAISuggested = isAISuggested
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
