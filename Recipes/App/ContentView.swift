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

            Tab("Pantry", systemImage: "refrigerator", value: .pantry) {
                PantryView()
            }

            Tab("Meal Plan", systemImage: "calendar", value: .mealPlan) {
                MealPlanView()
            }

            Tab("Shopping", systemImage: "cart", value: .shopping) {
                ShoppingListView()
            }

            Tab("Journal", systemImage: "fork.knife.circle", value: .journal) {
                RestaurantJournalView()
            }

            Tab("Metrics", systemImage: "chart.bar", value: .metrics) {
                MetricsView()
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
    case recipes, pantry, mealPlan, shopping, journal, metrics, settings
}

#Preview {
    ContentView()
}
