import SwiftUI
import SwiftData
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.recipes", category: "App")

// MARK: - Notification Delegate
// Presents timer notifications (with sound) even when the app is in the foreground.

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is open
        completionHandler([.banner, .sound])
    }
}

// Stored at file scope so the weak UNUserNotificationCenter.delegate reference
// doesn't deallocate the object when the App struct is recreated.
private let sharedNotificationDelegate = AppNotificationDelegate()

// MARK: - App Entry Point

@main
struct RecipesApp: App {
    @State private var aiRouter = AIServiceRouter()
    @State private var timerDeepLink = TimerDeepLink()
    @State private var remindersSync = RemindersSync()

    private static let schema = Schema([
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

    private static var container: ModelContainer = {
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            logger.error("Schema migration failed: \(error)")
#if DEBUG
            // Wipe and recreate during development only — never in production.
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                let storeURL = URL.applicationSupportDirectory
                    .appending(path: "default.store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Cannot create ModelContainer after reset: \(error)")
            }
#else
            // Fall back to in-memory store so the app stays usable instead of crashing.
            logger.critical("Falling back to in-memory store — data will not persist.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                fatalError("Cannot create even in-memory ModelContainer: \(error)")
            }
#endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.aiRouter, aiRouter)
                .environment(timerDeepLink)
                .environment(remindersSync)
                .preferredColorScheme(.dark)
                .onOpenURL { timerDeepLink.handle($0) }
                .task {
                    let center = UNUserNotificationCenter.current()
                    center.delegate = sharedNotificationDelegate
                    _ = try? await center.requestAuthorization(options: [.alert, .sound])
                }
        }
        .modelContainer(Self.container)
    }
}
