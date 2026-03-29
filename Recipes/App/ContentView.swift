import SwiftUI
import SwiftData

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @State private var selectedTab: AppTab = .recipes
    @State private var showingOnboarding = false
    @Query private var profiles: [UserProfile]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Recipes", systemImage: "book.pages", value: .recipes) {
                RecipeListView()
            }

            Tab("Plan & Shop", systemImage: "cart", value: .planAndShop) {
                PlanAndShopView()
            }

            Tab("Activity", systemImage: "chart.bar", value: .activity) {
                ActivityView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear {
            if profiles.isEmpty {
                showingOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }
}

// MARK: - App Tab

enum AppTab: String, Hashable {
    case recipes, planAndShop, activity, settings
}

#Preview("Empty") {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}

#Preview("With Sample Data") {
    ContentView()
        .environment(AIServiceRouter())
        .modelContainer(previewContainer)
}

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema([
        Recipe.self, Ingredient.self, PantryItem.self,
        MealPlan.self, PlannedMeal.self,
        GroceryList.self, GroceryItem.self, GroceryReceipt.self,
        RecipePhoto.self, CookingLogEntry.self, RecipeVariation.self,
        RestaurantJournalEntry.self, RestaurantWantToTry.self,
        UserProfile.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    SampleData.populate(container.mainContext)
    return container
}()
