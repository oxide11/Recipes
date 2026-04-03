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
            DashboardView().tag(AppTab.mise)
            PlanAndShopView().tag(AppTab.planAndShop)
            RecipeListView().tag(AppTab.recipes)
            ActivityView().tag(AppTab.activity)
            SettingsView().tag(AppTab.settings)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MiseTabBar(selectedTab: $selectedTab)
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

    init() {
        // Hide the system tab bar so our custom one is the only one shown
        UITabBar.appearance().isHidden = true
    }
}

// MARK: - Custom Tab Bar

struct MiseTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            // Hairline separator
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                            Text(tab.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Brand.warmTan : Brand.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 20)  // home indicator clearance
        }
        .background(Brand.midnight)
    }
}

// MARK: - App Tab

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case mise, planAndShop, recipes, activity, settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mise:        return "Mise"
        case .planAndShop: return "Plan & Shop"
        case .recipes:     return "Recipes"
        case .activity:    return "Activity"
        case .settings:    return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .mise:        return "sparkles"
        case .planAndShop: return "cart"
        case .recipes:     return "book.pages"
        case .activity:    return "chart.bar"
        case .settings:    return "gear"
        }
    }
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
