import Foundation
import SwiftData

// MARK: - User Preferences

enum MeasurementSystem: String, Codable, Sendable {
    case metric, imperial
}

// MARK: - User Profile

@Model
final class UserProfile {
    var id: UUID
    var displayName: String

    // Dietary preferences
    var dietaryRestrictions: [DietaryRestriction]
    var dislikedIngredients: [String]
    var allergens: [String]

    // Cooking preferences
    var preferredCuisines: [Cuisine]
    var skillLevel: RecipeDifficulty
    var measurementSystem: MeasurementSystem
    var maxCookTimeMinutes: Int?

    // Nutritional goals
    var dailyCalorieTarget: Int?
    var dailyProteinTargetGrams: Int?
    var dailyCarbTargetGrams: Int?
    var dailyFatTargetGrams: Int?

    // Budget
    var weeklyGroceryBudget: Double?

    // AI preferences
    var preferredAIProvider: AIProvider
    var enableOnDeviceAI: Bool

    // Stats
    var dateJoined: Date
    var totalRecipesCooked: Int
    var totalTimeCookingMinutes: Int
    var totalTimePrepMinutes: Int
    var totalTimeShoppingMinutes: Int

    init(
        displayName: String = "Chef",
        dietaryRestrictions: [DietaryRestriction] = [],
        preferredCuisines: [Cuisine] = [],
        skillLevel: RecipeDifficulty = .intermediate,
        measurementSystem: MeasurementSystem = .imperial,
        preferredAIProvider: AIProvider = .onDevice
    ) {
        self.id = UUID()
        self.displayName = displayName
        self.dietaryRestrictions = dietaryRestrictions
        self.dislikedIngredients = []
        self.allergens = []
        self.preferredCuisines = preferredCuisines
        self.skillLevel = skillLevel
        self.measurementSystem = measurementSystem
        self.maxCookTimeMinutes = nil
        self.dailyCalorieTarget = nil
        self.dailyProteinTargetGrams = nil
        self.dailyCarbTargetGrams = nil
        self.dailyFatTargetGrams = nil
        self.weeklyGroceryBudget = nil
        self.preferredAIProvider = preferredAIProvider
        self.enableOnDeviceAI = true
        self.dateJoined = .now
        self.totalRecipesCooked = 0
        self.totalTimeCookingMinutes = 0
        self.totalTimePrepMinutes = 0
        self.totalTimeShoppingMinutes = 0
    }
}

// MARK: - AI Provider

enum AIProvider: String, Codable, CaseIterable, Sendable {
    case onDevice     // Apple Foundation Models
    case claude       // Anthropic Claude
    case openAI       // OpenAI GPT
    case hybrid       // On-device first, fallback to cloud
}
