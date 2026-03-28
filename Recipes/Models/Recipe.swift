import Foundation
import SwiftData
import FoundationModels

// MARK: - Cuisine

enum Cuisine: String, Codable, CaseIterable, Sendable {
    case mexican, italian, japanese, chinese, indian, thai, french
    case korean, vietnamese, greek, mediterranean, american, brazilian
    case ethiopian, moroccan, turkish, spanish, german, british, other
}

// MARK: - Dietary Restriction

enum DietaryRestriction: String, Codable, CaseIterable, Sendable {
    case vegetarian, vegan, glutenFree, dairyFree, nutFree
    case halal, kosher, lowSodium, lowCarb, keto, paleo
    case whole30, fodmap, pescatarian
}

// MARK: - Difficulty

enum RecipeDifficulty: String, Codable, CaseIterable, Sendable {
    case beginner, intermediate, advanced, expert
}

// MARK: - Timer Step

struct TimerStep: Codable, Hashable, Sendable {
    var durationSeconds: Int
    var label: String

    var displayDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes > 0 && seconds > 0 {
            return "\(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds) sec"
        }
    }
}

// MARK: - Recipe Direction

struct RecipeDirection: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var stepNumber: Int
    var instruction: String
    var timer: TimerStep?
    var ingredients: [DirectionIngredientRef]
    var safeTemperature: SafeTemperature?

    init(
        stepNumber: Int,
        instruction: String,
        timer: TimerStep? = nil,
        ingredients: [DirectionIngredientRef] = [],
        safeTemperature: SafeTemperature? = nil
    ) {
        self.id = UUID()
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.timer = timer
        self.ingredients = ingredients
        self.safeTemperature = safeTemperature
    }
}

/// References an ingredient with its measurement inline in a direction step.
struct DirectionIngredientRef: Codable, Hashable, Sendable {
    var ingredientName: String
    var amount: IngredientAmount
}

// MARK: - Safe Cooking Temperature

struct SafeTemperature: Codable, Hashable, Sendable {
    var protein: String
    var minimumFahrenheit: Double
    var minimumCelsius: Double
    var restTimeMinutes: Int?
    var notes: String?
}

// MARK: - Recipe Photo

@Model
final class RecipePhoto {
    var id: UUID
    var imageData: Data
    var caption: String?
    var dateTaken: Date

    init(imageData: Data, caption: String? = nil) {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.dateTaken = .now
    }
}

// MARK: - Cooking Log Entry

@Model
final class CookingLogEntry {
    var id: UUID
    var date: Date
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var rating: Int?  // 1-5
    var notes: String?
    var photo: RecipePhoto?
    var substitutionsMade: [String]

    init(
        date: Date = .now,
        prepTimeMinutes: Int? = nil,
        cookTimeMinutes: Int? = nil,
        rating: Int? = nil,
        notes: String? = nil,
        substitutionsMade: [String] = []
    ) {
        self.id = UUID()
        self.date = date
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.rating = rating
        self.notes = notes
        self.substitutionsMade = substitutionsMade
    }
}

// MARK: - Recipe Variation

@Model
final class RecipeVariation {
    var id: UUID
    var name: String
    var recipeDescription: String?
    var ingredientOverrides: [IngredientOverride]
    var directionOverrides: [RecipeDirection]?
    var dietaryRestrictions: [DietaryRestriction]

    init(
        name: String,
        description: String? = nil,
        ingredientOverrides: [IngredientOverride] = [],
        directionOverrides: [RecipeDirection]? = nil,
        dietaryRestrictions: [DietaryRestriction] = []
    ) {
        self.id = UUID()
        self.name = name
        self.recipeDescription = description
        self.ingredientOverrides = ingredientOverrides
        self.directionOverrides = directionOverrides
        self.dietaryRestrictions = dietaryRestrictions
    }
}

struct IngredientOverride: Codable, Hashable, Sendable {
    var originalIngredient: String
    var replacementIngredient: String
    var replacementAmount: IngredientAmount
    var reason: String?
}

// MARK: - Recipe Model

@Model
final class Recipe {
    var id: UUID
    var title: String
    var summary: String?
    var cuisine: Cuisine
    var difficulty: RecipeDifficulty
    var servings: Int
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var totalTimeMinutes: Int

    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]

    var directions: [RecipeDirection]

    @Relationship(deleteRule: .cascade)
    var variations: [RecipeVariation]

    @Relationship(deleteRule: .cascade)
    var photos: [RecipePhoto]

    @Relationship(deleteRule: .cascade)
    var cookingLog: [CookingLogEntry]

    var nutritionalInfo: NutritionalInfo?
    var safeTemperatures: [SafeTemperature]
    var dietaryRestrictions: [DietaryRestriction]
    var tags: [String]
    var sourceURL: String?
    var sourceMarkdown: String?
    var isFavorite: Bool
    var dateCreated: Date
    var dateModified: Date

    /// The number of times this recipe has been cooked.
    var cookCount: Int {
        cookingLog.count
    }

    /// Average rating across all cooking log entries.
    var averageRating: Double? {
        let ratings = cookingLog.compactMap(\.rating)
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    /// Whether the recipe is considered a favorite based on cook count threshold.
    var isAutoFavorite: Bool {
        cookCount >= 5
    }

    /// Estimated total meal prep time including prep and cook time.
    var estimatedTotalMinutes: Int {
        prepTimeMinutes + cookTimeMinutes
    }

    init(
        title: String,
        summary: String? = nil,
        cuisine: Cuisine = .other,
        difficulty: RecipeDifficulty = .intermediate,
        servings: Int = 4,
        prepTimeMinutes: Int = 0,
        cookTimeMinutes: Int = 0,
        ingredients: [Ingredient] = [],
        directions: [RecipeDirection] = [],
        nutritionalInfo: NutritionalInfo? = nil,
        safeTemperatures: [SafeTemperature] = [],
        dietaryRestrictions: [DietaryRestriction] = [],
        tags: [String] = [],
        sourceURL: String? = nil,
        sourceMarkdown: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.cuisine = cuisine
        self.difficulty = difficulty
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = prepTimeMinutes + cookTimeMinutes
        self.ingredients = ingredients
        self.directions = directions
        self.variations = []
        self.photos = []
        self.cookingLog = []
        self.nutritionalInfo = nutritionalInfo
        self.safeTemperatures = safeTemperatures
        self.dietaryRestrictions = dietaryRestrictions
        self.tags = tags
        self.sourceURL = sourceURL
        self.sourceMarkdown = sourceMarkdown
        self.isFavorite = false
        self.dateCreated = .now
        self.dateModified = .now
    }
}
