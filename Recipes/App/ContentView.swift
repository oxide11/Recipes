import SwiftUI
import SwiftData

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TimerDeepLink.self) private var timerDeepLink
    @State private var selectedTab: AppTab = .mise
    @State private var cookSegment: CookSegment = .mealPlan
    @State private var pantryShopSegment: PantryShopSegment = .pantry
    @State private var showingOnboarding = false
    @State private var showingStorageAlert = false
    @Query private var profiles: [UserProfile]
    @Query private var mealPlans: [MealPlan]
    @Query private var plannedMeals: [PlannedMeal]  // granular change tracking
    @Query private var pantryItems: [PantryItem]
    @Query(sort: \CookingLogEntry.date, order: .reverse) private var cookingLogs: [CookingLogEntry]

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Mise", systemImage: "house", value: .mise) {
                DashboardView(
                    selectedTab: $selectedTab,
                    cookSegment: $cookSegment,
                    pantryShopSegment: $pantryShopSegment
                )
            }

            Tab("Cook", systemImage: "book.pages", value: .cook) {
                CookView(segment: $cookSegment)
            }

            Tab("Pantry & Shop", systemImage: "cart", value: .pantryShop) {
                PantryShopView(segment: $pantryShopSegment)
            }

            Tab("Activity", systemImage: "chart.bar", value: .activity) {
                ActivityView()
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .safeAreaInset(edge: .top, spacing: 0) {
            if RecipesApp.isUsingEphemeralStore {
                storageWarningBanner
            }
        }
        .alert("Your data couldn't be opened", isPresented: $showingStorageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Recipes is running in a temporary mode. Your saved recipes, pantry, and plans are still on this device, but nothing you add now will be kept after you close the app. Please update the app or contact support.")
        }
        .onChange(of: timerDeepLink.pendingRecipeID) { _, newID in
            // Deep-link into the Recipes segment of the Cook tab
            if newID != nil {
                cookSegment = .recipes
                selectedTab = .cook
            }
        }
        // Schedule all smart notifications on launch and keep them current
        // as data changes or the app returns to the foreground.
        .onAppear {
            Season.activeHemisphere = profiles.first?.hemisphere ?? .northern
            scheduleAllNotifications()
            if RecipesApp.isUsingEphemeralStore {
                // Don't stack onboarding on top of a data-loss warning.
                showingStorageAlert = true
            } else if profiles.isEmpty {
                showingOnboarding = true
            }
        }
        .onChange(of: profiles.first?.hemisphere) { _, hemisphere in
            Season.activeHemisphere = hemisphere ?? .northern
            scheduleAllNotifications()
        }
        .onChange(of: pantryItems.count) { scheduleAllNotifications() }
        .onChange(of: cookingLogs.count) { scheduleAllNotifications() }
        // Meals are edited in place (moved, retyped, recipe swapped) without changing
        // the count, so reschedule on any change to what a reminder depends on.
        .onChange(of: mealReminderSignature) { scheduleAllNotifications() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { scheduleAllNotifications() }
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }

    private var storageWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Temporary mode: changes won't be saved")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("Details") { showingStorageAlert = true }
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundStyle(.black)
        .background(.yellow)
        .accessibilityElement(children: .combine)
    }

    private var mealReminderSignature: [String] {
        plannedMeals.map { meal in
            let title = meal.recipe?.title ?? meal.customTitle ?? ""
            let minutes = meal.recipe?.estimatedTotalMinutes ?? -1
            return "\(meal.id.uuidString)|\(meal.date.timeIntervalSince1970)|\(meal.mealType.rawValue)|\(minutes)|\(title)"
        }
    }

    private func scheduleAllNotifications() {
        let hemisphere = profiles.first?.hemisphere ?? .northern
        SmartNotificationService.shared.scheduleExpiringPantryAlerts(items: pantryItems)
        SmartNotificationService.shared.scheduleMealReminders(for: plannedMeals)
        SmartNotificationService.shared.scheduleCookingStreakReminder(lastCookDate: cookingLogs.first?.date)
        SmartNotificationService.shared.scheduleWeeklyPlanningReminder(mealPlans: mealPlans)
        SmartNotificationService.shared.scheduleSeasonChangeNotification(hemisphere: hemisphere)
    }
}

// MARK: - App Tab

enum AppTab: String, Hashable {
    case mise, cook, pantryShop, activity, settings
}


#Preview("Empty") {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(\.aiRouter, AIServiceRouter())
}

#Preview("With Sample Data") {
    ContentView()
        .environment(\.aiRouter, AIServiceRouter())
        .modelContainer(previewContainer)
}

@MainActor
let previewContainer: ModelContainer = {
    let schema = Schema(versionedSchema: RecipesSchemaV1.self)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    do {
        let container = try ModelContainer(for: schema, configurations: [config])
        SampleData.populate(container.mainContext)
        return container
    } catch {
        fatalError("Preview ModelContainer creation failed: \(error)")
    }
}()
