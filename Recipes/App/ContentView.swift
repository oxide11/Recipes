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
            DashboardView()
                .tabItem { Label("Mise", systemImage: "sparkles") }
                .tag(AppTab.mise)

            PlanAndShopView()
                .tabItem { Label("Plan & Shop", systemImage: "cart") }
                .tag(AppTab.planAndShop)

            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book.pages") }
                .tag(AppTab.recipes)

            ActivityView()
                .tabItem { Label("Activity", systemImage: "chart.bar") }
                .tag(AppTab.activity)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppTab.settings)
        }
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
