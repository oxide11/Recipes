import SwiftData

// MARK: - Versioned Schema

/// Version 1 of the SwiftData schema. Matches the models exactly as they
/// shipped before versioning was introduced, so existing stores open as V1.
///
/// When a model changes:
/// 1. Add `RecipesSchemaV2` with the new model definitions.
/// 2. Append it to `RecipesMigrationPlan.schemas`.
/// 3. Add a `MigrationStage` (lightweight where possible) to `stages`.
/// Never edit a released version in place.
enum RecipesSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Recipe.self,
            Ingredient.self,
            PantryItem.self,
            MealPlan.self,
            PlannedMeal.self,
            GroceryList.self,
            GroceryItem.self,
            GroceryReceipt.self,
            RecipePhoto.self,
            CookingLogEntry.self,
            RecipeVariation.self,
            RestaurantJournalEntry.self,
            RestaurantWantToTry.self,
            UserProfile.self,
        ]
    }
}

// MARK: - Migration Plan

enum RecipesMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [RecipesSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
