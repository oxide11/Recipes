import SwiftUI
import SwiftData

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(TimerDeepLink.self) private var timerDeepLink
    @State private var selectedTab: AppTab = .mise
    @State private var showingOnboarding = false
    @Query private var profiles: [UserProfile]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mise", systemImage: "sparkles", value: .mise) {
                DashboardView()
            }

            Tab("Plan & Shop", systemImage: "cart", value: .planAndShop) {
                PlanAndShopView()
            }

            Tab("Recipes", systemImage: "book.pages", value: .recipes) {
                RecipeListView()
            }

            Tab("Activity", systemImage: "chart.bar", value: .activity) {
                ActivityView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.tabBar)
        .onChange(of: timerDeepLink.pendingRecipeID) { _, newID in
            if newID != nil { selectedTab = .recipes }
        }
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
    case mise, recipes, planAndShop, activity, settings
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
