import SwiftUI
import SwiftData

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TimerDeepLink.self) private var timerDeepLink
    @State private var selectedTab: AppTab = .mise
    @State private var planAndShopSegment: PlanAndShopSegment = .mealPlan
    @State private var showingOnboarding = false
    @Query private var profiles: [UserProfile]
    @Query private var mealPlans: [MealPlan]
    @Query private var plannedMeals: [PlannedMeal]  // granular change tracking
    @Query private var pantryItems: [PantryItem]
    @Query(sort: \CookingLogEntry.date, order: .reverse) private var cookingLogs: [CookingLogEntry]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mise", systemImage: "sparkles", value: .mise) {
                DashboardView(selectedTab: $selectedTab, planAndShopSegment: $planAndShopSegment)
            }

            Tab("Plan & Shop", systemImage: "cart", value: .planAndShop) {
                PlanAndShopView(segment: $planAndShopSegment)
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
        .tabViewStyle(.sidebarAdaptable)
        .onChange(of: timerDeepLink.pendingRecipeID) { _, newID in
            if newID != nil { selectedTab = .recipes }
        }
        // Schedule all smart notifications on launch and keep them current
        // as data changes or the app returns to the foreground.
        .onAppear {
            scheduleAllNotifications()
            if profiles.isEmpty {
                showingOnboarding = true
            }
        }
        .onChange(of: pantryItems.count) {
            SmartNotificationService.shared.scheduleExpiringPantryAlerts(items: pantryItems)
        }
        .onChange(of: cookingLogs.count) {
            SmartNotificationService.shared.scheduleCookingStreakReminder(lastCookDate: cookingLogs.first?.date)
        }
        .onChange(of: plannedMeals.count) {
            SmartNotificationService.shared.scheduleWeeklyPlanningReminder(mealPlans: mealPlans)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { scheduleAllNotifications() }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }

    private func scheduleAllNotifications() {
        let hemisphere = profiles.first?.hemisphere ?? .northern
        SmartNotificationService.shared.scheduleExpiringPantryAlerts(items: pantryItems)
        SmartNotificationService.shared.scheduleCookingStreakReminder(lastCookDate: cookingLogs.first?.date)
        SmartNotificationService.shared.scheduleWeeklyPlanningReminder(mealPlans: mealPlans)
        SmartNotificationService.shared.scheduleSeasonChangeNotification(hemisphere: hemisphere)
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
