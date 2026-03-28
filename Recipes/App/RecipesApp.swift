import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct RecipesApp: App {
    @State private var aiRouter = AIServiceRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(aiRouter)
        }
        .modelContainer(for: [
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
        ])
    }
}
