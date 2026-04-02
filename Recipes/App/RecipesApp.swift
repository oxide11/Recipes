import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Notification Delegate
// Presents timer notifications (with sound) even when the app is in the foreground.

class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
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
            // Schema migration failed — wipe store and start fresh.
            // This is safe during development; production apps should migrate.
            print("[RecipesApp] Schema migration failed, resetting store: \(error)")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            do {
                let storeURL = URL.applicationSupportDirectory
                    .appending(path: "default.store")
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Cannot create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(aiRouter)
                .environment(timerDeepLink)
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
