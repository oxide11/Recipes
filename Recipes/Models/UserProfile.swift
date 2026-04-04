import Foundation
import SwiftData

// MARK: - User Preferences

enum MeasurementSystem: String, Codable, Sendable {
    case metric, imperial
}

enum Hemisphere: String, Codable, CaseIterable, Sendable {
    case northern = "Northern"
    case southern = "Southern"
}

enum MealPrepMode: String, Codable, CaseIterable, Sendable {
    case daily   // Prep each day's meals individually
    case weekly  // Shop Saturday, prep Sunday for the whole week
}

// MARK: - Cooking Goal

enum CookingGoal: String, Codable, CaseIterable, Sendable {
    case quickAndEasy      = "quickAndEasy"
    case eatingHealthier   = "eatingHealthier"
    case highProtein       = "highProtein"
    case expandingCooking  = "expandingCooking"
    case greatFood         = "greatFood"

    var title: String {
        switch self {
        case .quickAndEasy:     return "Quick & easy"
        case .eatingHealthier:  return "Eating healthier"
        case .highProtein:      return "High protein"
        case .expandingCooking: return "Expanding my cooking"
        case .greatFood:        return "Just cook great food"
        }
    }

    var description: String {
        switch self {
        case .quickAndEasy:     return "30 minutes or less, minimal steps"
        case .eatingHealthier:  return "Balanced, whole ingredients, lighter meals"
        case .highProtein:      return "Muscle building, filling meals"
        case .expandingCooking: return "More interesting techniques and ingredients"
        case .greatFood:        return "No specific goal — show me everything"
        }
    }

    /// Short context string injected into AI prompts.
    var promptContext: String {
        switch self {
        case .quickAndEasy:
            return "The user prioritises speed — prefer recipes under 30 minutes with minimal steps and few dishes."
        case .eatingHealthier:
            return "The user wants to eat healthier — prefer balanced, whole-ingredient meals; avoid heavy or highly processed dishes."
        case .highProtein:
            return "The user is focused on high-protein meals — prioritise protein-rich ingredients and filling, muscle-building recipes."
        case .expandingCooking:
            return "The user wants to grow their skills — suggest recipes with interesting techniques, less familiar ingredients, or higher complexity."
        case .greatFood:
            return ""  // No constraint — show everything
        }
    }
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

    // Budget & Currency
    var weeklyGroceryBudget: Double?
    var preferredCurrencyCode: String

    // Meal planning
    var defaultMealPrepMode: MealPrepMode

    // AI preferences
    var preferredAIProvider: AIProvider
    var enableOnDeviceAI: Bool

    // Location
    var hemisphere: Hemisphere

    // Pantry
    /// nil for profiles created before this field existed — treated as .greatFood everywhere.
    var cookingGoal: CookingGoal?
    var autoDeductPantry: Bool

    // iCloud & Sharing (stubs for future CloudKit)
    var iCloudSyncEnabled: Bool
    var shareRecipesEnabled: Bool
    var shareStatsEnabled: Bool
    var shareJournalEnabled: Bool

    // Stats
    var dateJoined: Date
    var totalRecipesCooked: Int
    var totalTimeCookingMinutes: Int
    var totalTimePrepMinutes: Int
    var totalTimeShoppingMinutes: Int

    // MARK: - Skill Inference

    /// Call this once per new cooking log entry to keep skill level up to date.
    /// Skill only ever ratchets upward — a bad week won't demote you.
    func recordCook(ofRecipeWithDifficulty difficulty: RecipeDifficulty) {
        totalRecipesCooked += 1
        let proposed = Self.proposedSkillLevel(cookCount: totalRecipesCooked, difficulty: difficulty)
        if proposed.rank > skillLevel.rank {
            skillLevel = proposed
        }
    }

    private static func proposedSkillLevel(cookCount: Int, difficulty: RecipeDifficulty) -> RecipeDifficulty {
        switch difficulty {
        case .advanced, .expert:
            return .advanced
        case .intermediate:
            return .intermediate
        case .beginner:
            // Upgrade to intermediate once they've cooked 5+ times
            return cookCount >= 5 ? .intermediate : .beginner
        }
    }

    /// Human-readable description of how the skill level was determined.
    var skillLevelDescription: String {
        switch skillLevel {
        case .beginner:
            return "Based on your cooking history — keep logging cooks to level up."
        case .intermediate:
            return "You've built a solid base. Inferred from your cooking history."
        case .advanced:
            return "You've tackled advanced recipes. Inferred from your cooking history."
        case .expert:
            return "Expert level. Inferred from your cooking history."
        }
    }

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
        self.preferredCurrencyCode = "CAD"
        self.defaultMealPrepMode = .daily
        self.preferredAIProvider = preferredAIProvider
        self.enableOnDeviceAI = true
        self.hemisphere = .northern
        self.cookingGoal = nil  // set during onboarding; nil = .greatFood behaviour
        self.autoDeductPantry = true
        self.iCloudSyncEnabled = false
        self.shareRecipesEnabled = false
        self.shareStatsEnabled = false
        self.shareJournalEnabled = false
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
