import Foundation
import UserNotifications
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.recipes", category: "Notifications")

// MARK: - Smart Notification Service

/// Schedules local notifications for expiring pantry items, upcoming meals, and cooking streaks.
actor SmartNotificationService {

    static let shared = SmartNotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Notification Category Identifiers

    private enum Category {
        static let pantryExpiry = "PANTRY_EXPIRY"
        static let mealReminder = "MEAL_REMINDER"
        static let cookingStreak = "COOKING_STREAK"
    }

    // MARK: - UserDefaults Keys

    enum SettingsKey {
        static let pantryAlerts = "notification_pantryAlerts"
        static let mealReminders = "notification_mealReminders"
        static let streakReminders = "notification_streakReminders"
    }

    private init() {}

    // MARK: - Permission

    /// Requests notification authorization. Returns `true` when granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            logger.error("Notification permission request failed: \(error)")
            return false
        }
    }

    // MARK: - Expiring Pantry Alerts

    /// Schedules notifications for pantry items expiring within the next 3 days.
    /// Creates alerts at both 3-day and 1-day thresholds when applicable.
    func scheduleExpiringPantryAlerts(items: [PantryItem]) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.pantryAlerts) else { return }

        // Remove existing pantry notifications before rescheduling.
        center.removePendingNotificationRequests(withIdentifiers:
            items.flatMap { item in
                ["\(Category.pantryExpiry)_3d_\(item.name)", "\(Category.pantryExpiry)_1d_\(item.name)"]
            }
        )

        let calendar = Calendar.current
        let now = Date.now

        for item in items {
            guard let expirationDate = item.expirationDate else { continue }

            let daysUntilExpiry = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                                          to: calendar.startOfDay(for: expirationDate)).day ?? Int.max

            guard daysUntilExpiry >= 0, daysUntilExpiry <= 3 else { continue }

            // 3-day warning — fires at 9 am today to give the user time to plan.
            if daysUntilExpiry >= 2 {
                let threeDayContent = UNMutableNotificationContent()
                threeDayContent.title = "Expiring Soon"
                threeDayContent.body = "\(item.name) expires in \(daysUntilExpiry) days. Plan a recipe to use it up!"
                threeDayContent.sound = .default
                threeDayContent.categoryIdentifier = Category.pantryExpiry

                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.hour = 9
                components.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(Category.pantryExpiry)_3d_\(item.name)",
                    content: threeDayContent,
                    trigger: trigger
                )
                center.add(request)
            }

            // 1-day warning — fires at 8 am the day before expiration.
            if daysUntilExpiry <= 1 {
                let oneDayContent = UNMutableNotificationContent()
                oneDayContent.title = "Expires Tomorrow!"
                oneDayContent.body = "\(item.name) is about to expire. Use it today or it may go to waste."
                oneDayContent.sound = .default
                oneDayContent.categoryIdentifier = Category.pantryExpiry
                oneDayContent.interruptionLevel = .timeSensitive

                guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: expirationDate) else { continue }
                var components = calendar.dateComponents([.year, .month, .day], from: dayBefore)
                components.hour = 8
                components.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(Category.pantryExpiry)_1d_\(item.name)",
                    content: oneDayContent,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    // MARK: - Meal Plan Reminders

    /// Schedules a reminder 30 minutes before each incomplete meal in the plan.
    func scheduleMealPlanReminders(plan: MealPlan) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.mealReminders) else { return }

        let calendar = Calendar.current
        let now = Date.now

        // Remove stale reminders for this plan.
        let existingIdentifiers = plan.meals.map { "\(Category.mealReminder)_\($0.id)" }
        center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

        for meal in plan.meals where !meal.isCompleted {
            // Only schedule future reminders.
            guard meal.date > now else { continue }

            let reminderDate = calendar.date(byAdding: .minute, value: -30, to: meal.date) ?? meal.date

            // Skip if the reminder time has already passed.
            guard reminderDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Meal Reminder"

            let mealLabel = meal.mealType.rawValue.capitalized
            if let recipe = meal.recipe {
                content.body = "Time to start \(mealLabel): \(recipe.title) in 30 minutes."
            } else {
                content.body = "\(mealLabel) is coming up in 30 minutes."
            }
            content.sound = .default
            content.categoryIdentifier = Category.mealReminder

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(Category.mealReminder)_\(meal.id)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Cooking Streak Reminder

    /// If the user hasn't cooked in 2 or more days, schedule an encouragement notification.
    func scheduleCookingStreakReminder(lastCookDate: Date?) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.streakReminders) else { return }

        let identifier = "\(Category.cookingStreak)_encouragement"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        let now = Date.now

        let daysSinceLastCook: Int
        if let lastCookDate {
            daysSinceLastCook = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastCookDate),
                                                        to: calendar.startOfDay(for: now)).day ?? 0
        } else {
            daysSinceLastCook = Int.max
        }

        guard daysSinceLastCook >= 2 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Keep Your Streak Alive!"
        content.body = "You haven't cooked in \(daysSinceLastCook) days. Pick a quick recipe and get back on track!"
        content.sound = .default
        content.categoryIdentifier = Category.cookingStreak

        // Fire the reminder the same evening at 6 PM.
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Cancel All

    /// Removes all pending notifications managed by this service.
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }
}

// MARK: - Notification Settings View

/// User-facing toggles for each notification category, persisted in UserDefaults.
struct NotificationSettingsView: View {

    @AppStorage(SmartNotificationService.SettingsKey.pantryAlerts)
    private var pantryAlerts = true

    @AppStorage(SmartNotificationService.SettingsKey.mealReminders)
    private var mealReminders = true

    @AppStorage(SmartNotificationService.SettingsKey.streakReminders)
    private var streakReminders = true

    @State private var permissionGranted: Bool?

    var body: some View {
        Form {
            Section {
                permissionStatusRow
            } header: {
                Text("Status")
            }

            Section {
                Toggle("Expiring Pantry Items", systemImage: "refrigerator", isOn: $pantryAlerts)
                    .tint(.orange)

                Toggle("Meal Plan Reminders", systemImage: "fork.knife", isOn: $mealReminders)
                    .tint(.blue)

                Toggle("Cooking Streak Encouragement", systemImage: "flame", isOn: $streakReminders)
                    .tint(.red)
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which notifications you'd like to receive. Changes take effect the next time notifications are scheduled.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Notifications")
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial)
        .toolbarBackground(.automatic, for: .navigationBar)
        .task {
            await checkPermission()
        }
    }

    // MARK: - Permission Status

    @ViewBuilder
    private var permissionStatusRow: some View {
        switch permissionGranted {
        case .some(true):
            Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .some(false):
            Button {
                Task { await requestPermission() }
            } label: {
                Label("Enable Notifications", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.glass)
        case .none:
            ProgressView()
        }
    }

    // MARK: - Helpers

    private func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
    }

    private func requestPermission() async {
        let granted = await SmartNotificationService.shared.requestPermission()
        permissionGranted = granted
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
