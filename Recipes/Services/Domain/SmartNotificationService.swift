import Foundation
import UserNotifications
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.recipes", category: "Notifications")

// MARK: - Smart Notification Service

/// Schedules local notifications for expiring pantry items, upcoming meals, and cooking streaks.
/// Isolated to @MainActor so SwiftData model objects can be passed directly from SwiftUI views
/// without crossing an actor boundary (which would require Sendable conformance).
@MainActor
final class SmartNotificationService {

    static let shared = SmartNotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Notification Category Identifiers

    private enum Category {
        static let pantryExpiry   = "PANTRY_EXPIRY"
        static let mealReminder   = "MEAL_REMINDER"
        static let cookingStreak  = "COOKING_STREAK"
        static let weeklyPlanning = "WEEKLY_PLANNING"
        static let seasonChange   = "SEASON_CHANGE"
    }

    // MARK: - UserDefaults Keys

    enum SettingsKey {
        static let pantryAlerts    = "notification_pantryAlerts"
        static let mealReminders   = "notification_mealReminders"
        static let streakReminders = "notification_streakReminders"
        static let weeklyPlanning  = "notification_weeklyPlanning"
        static let seasonChange    = "notification_seasonChange"
    }

    private init() {
        Self.registerDefaults()
    }

    /// All notification types are on unless the user turns them off.
    /// `UserDefaults.bool(forKey:)` returns `false` for an unwritten key, so without
    /// this every scheduler below would silently no-op on a fresh install while the
    /// settings screen (which uses `@AppStorage` defaults of `true`) showed them enabled.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.pantryAlerts: true,
            SettingsKey.mealReminders: true,
            SettingsKey.streakReminders: true,
            SettingsKey.weeklyPlanning: true,
            SettingsKey.seasonChange: true,
        ])
    }

    /// Removes every pending request for the category behind a settings key.
    /// Called when the user turns a notification type off, so already-scheduled
    /// alerts don't keep firing.
    func cancelPending(forSettingsKey key: String) {
        let prefix: String
        switch key {
        case SettingsKey.pantryAlerts:    prefix = Category.pantryExpiry
        case SettingsKey.mealReminders:   prefix = Category.mealReminder
        case SettingsKey.streakReminders: prefix = Category.cookingStreak
        case SettingsKey.weeklyPlanning:  prefix = Category.weeklyPlanning
        case SettingsKey.seasonChange:    prefix = Category.seasonChange
        default: return
        }
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Trigger Helpers

    /// A one-shot calendar trigger for `date`, or nil when `date` is already past.
    /// Scheduling a calendar trigger in the past never fires, so callers skip instead.
    private func futureTrigger(for date: Date, calendar: Calendar) -> UNCalendarNotificationTrigger? {
        guard date > .now else { return nil }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    /// `hour:00` today if still ahead, otherwise `hour:00` tomorrow.
    private func nextOccurrence(hour: Int, calendar: Calendar) -> Date? {
        let now = Date.now
        guard let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { return nil }
        if today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
    }

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

        let calendar = Calendar.current
        let now = Date.now

        // Adding a request with an existing identifier replaces it, so items that
        // still qualify are refreshed in place. Identifiers scheduled in this pass are
        // collected so the async cleanup below removes only the leftovers (deleted or
        // no-longer-expiring items) and never races with the fresh adds.
        var scheduledIDs = Set<String>()

        for item in items {
            guard let expirationDate = item.expirationDate else { continue }

            let daysUntilExpiry = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                                          to: calendar.startOfDay(for: expirationDate)).day ?? Int.max

            guard daysUntilExpiry >= 0, daysUntilExpiry <= 3 else { continue }

            // Early warning — fires at the next 9 am while there are still 2+ days left,
            // so the user has time to plan a recipe around it.
            if daysUntilExpiry >= 2,
               let fireDate = nextOccurrence(hour: 9, calendar: calendar),
               fireDate < calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: expirationDate)) ?? expirationDate,
               let trigger = futureTrigger(for: fireDate, calendar: calendar) {
                let threeDayContent = UNMutableNotificationContent()
                threeDayContent.title = "Expiring Soon"
                threeDayContent.body = "\(item.name) expires in \(daysUntilExpiry) days. Plan a recipe to use it up!"
                threeDayContent.sound = .default
                threeDayContent.categoryIdentifier = Category.pantryExpiry

                let request = UNNotificationRequest(
                    identifier: "\(Category.pantryExpiry)_3d_\(item.id.uuidString)",
                    content: threeDayContent,
                    trigger: trigger
                )
                scheduledIDs.insert(request.identifier)
                center.add(request)
            }

            // Last-chance warning — 8 am the day before expiry. If that moment has
            // already passed (item expires today, or it's past 8 am), fire at the next
            // 9 am or 6 pm that is still before the item expires.
            if daysUntilExpiry <= 1 {
                let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: expirationDate)) ?? expirationDate
                var fireDate = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: dayBefore) ?? dayBefore
                if fireDate <= now {
                    let candidates = [9, 18].compactMap { calendar.date(bySettingHour: $0, minute: 0, second: 0, of: now) }
                    guard let next = candidates.first(where: { $0 > now && $0 < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: expirationDate)) ?? expirationDate }) else { continue }
                    fireDate = next
                }
                guard let trigger = futureTrigger(for: fireDate, calendar: calendar) else { continue }

                let oneDayContent = UNMutableNotificationContent()
                oneDayContent.title = daysUntilExpiry == 0 ? "Expires Today" : "Expires Tomorrow!"
                oneDayContent.body = "\(item.name) is about to expire. Use it today or it may go to waste."
                oneDayContent.sound = .default
                oneDayContent.categoryIdentifier = Category.pantryExpiry
                oneDayContent.interruptionLevel = .timeSensitive

                let request = UNNotificationRequest(
                    identifier: "\(Category.pantryExpiry)_1d_\(item.id.uuidString)",
                    content: oneDayContent,
                    trigger: trigger
                )
                scheduledIDs.insert(request.identifier)
                center.add(request)
            }
        }

        // Drop pantry alerts for items that were deleted, eaten, or no longer qualify.
        let keep = scheduledIDs
        center.getPendingNotificationRequests { requests in
            let stale = requests.map(\.identifier).filter { $0.hasPrefix(Category.pantryExpiry) && !keep.contains($0) }
            if !stale.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)
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

        let daysSinceLastCook: Int? = lastCookDate.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: $0),
                                    to: calendar.startOfDay(for: now)).day ?? 0
        }

        if let days = daysSinceLastCook, days < 2 { return }

        let content = UNMutableNotificationContent()
        content.title = daysSinceLastCook == nil ? "Ready to Cook?" : "Keep Your Streak Alive!"
        content.body = daysSinceLastCook.map {
            "You haven't cooked in \($0) days. Pick a quick recipe and get back on track!"
        } ?? "You haven't logged a cook yet. Pick a quick recipe and get started!"
        content.sound = .default
        content.categoryIdentifier = Category.cookingStreak

        // Fire at the next 6 pm (today if still ahead, otherwise tomorrow).
        guard let fireDate = nextOccurrence(hour: 18, calendar: calendar),
              let trigger = futureTrigger(for: fireDate, calendar: calendar) else { return }
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Weekly Meal Planning Reminder

    /// Schedules a Saturday-morning nudge to plan next week's dinners.
    ///
    /// Rules:
    /// - Fires the coming Saturday at 9:00 AM.
    /// - Only fires when fewer than 3 dinners are planned for next week
    ///   (Mon–Sun of the week following that Saturday).
    /// - Cancelled automatically if the user plans enough dinners before Saturday.
    /// - Safe to call repeatedly — always replaces the existing pending request.
    func scheduleWeeklyPlanningReminder(mealPlans: [MealPlan]) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.weeklyPlanning) else { return }

        let identifier = "\(Category.weeklyPlanning)_saturday"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let calendar = Calendar.current
        let now = Date.now

        // Find the next Saturday at 9:00 AM.
        // If today is Saturday before 9 AM, this resolves to today.
        // If today is Saturday after 9 AM, this resolves to next Saturday.
        var satComponents = DateComponents()
        satComponents.weekday = 7  // Saturday (Gregorian: 1 = Sun … 7 = Sat)
        satComponents.hour   = 9
        satComponents.minute = 0

        guard let nextSaturday = calendar.nextDate(
            after: now,
            matching: satComponents,
            matchingPolicy: .nextTime
        ) else { return }

        // "Next week" from that Saturday = Mon–Sun of the immediately following week.
        // Saturday + 2 days = Monday, Monday + 6 days = Sunday.
        guard
            let nextMonday  = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: nextSaturday)),
            let nextSunday  = calendar.date(byAdding: .day, value: 6, to: nextMonday),
            let weekEnd     = calendar.date(byAdding: .day, value: 1, to: nextSunday)   // exclusive upper bound
        else { return }

        // Count dinners planned across all meal plans that fall in next week.
        let dinnerCount = mealPlans
            .flatMap(\.meals)
            .filter { $0.mealType == .dinner && $0.date >= nextMonday && $0.date < weekEnd }
            .count

        // Well-prepared users (3+ dinners) don't need the nudge.
        guard dinnerCount < 3 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Plan Your Week"
        content.sound = .default
        content.categoryIdentifier = Category.weeklyPlanning

        switch dinnerCount {
        case 0:
            content.body = "Next week's dinners aren't planned yet. A few minutes this weekend will make the whole week easier."
        case 1:
            content.body = "Just 1 dinner planned for next week. Fill out the rest while you have time."
        default: // 2
            content.body = "2 dinners planned for next week — a couple more and you'll be set."
        }

        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nextSaturday
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { logger.error("Failed to schedule weekly planning reminder: \(error)") }
        }

        logger.info("Weekly planning reminder scheduled for \(nextSaturday, privacy: .public) — \(dinnerCount) dinners planned")
    }

    // MARK: - Season Change Notification

    /// Schedules a notification for the first day of the next season at 9 AM,
    /// listing ingredients that are newly in season (not carried over from the
    /// previous season). Safe to call repeatedly — always replaces the pending request.
    func scheduleSeasonChangeNotification(hemisphere: Hemisphere) {
        guard UserDefaults.standard.bool(forKey: SettingsKey.seasonChange) else { return }

        let calendar = Calendar.current
        let now = Date.now

        let currentSeason = Season.current(for: hemisphere)
        let nextSeason = currentSeason.next
        let startMonth = nextSeason.startMonth(for: hemisphere)

        // Build the fire date: 1st of the next season's start month at 9 AM.
        // If that month is earlier than today's month the season rolls into next year.
        var year = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        if startMonth <= currentMonth { year += 1 }

        var fireComponents = DateComponents()
        fireComponents.year   = year
        fireComponents.month  = startMonth
        fireComponents.day    = 1
        fireComponents.hour   = 9
        fireComponents.minute = 0

        // Ingredients that are genuinely new — not carried over from the previous season.
        let newIngredients = SeasonalAwarenessService.newIngredients(for: nextSeason, hemisphere: hemisphere)

        let identifier = "\(Category.seasonChange)_\(nextSeason.rawValue)_\(year)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.categoryIdentifier = Category.seasonChange

        let seasonName = nextSeason.rawValue.capitalized
        content.title = "\(seasonName) Produce Is Here"

        // Name up to 3 headline ingredients in the body.
        let highlights = newIngredients.prefix(3).map { $0.name.capitalized }
        switch highlights.count {
        case 0:
            content.body = "A new season means fresh ingredients at the market. See what's in season now."
        case 1:
            content.body = "\(highlights[0]) is hitting its peak. Open Mise to see everything in season."
        default:
            let lead = highlights.dropLast().joined(separator: ", ")
            let last = highlights[highlights.count - 1]
            let remainder = newIngredients.count - highlights.count
            if remainder > 0 {
                content.body = "\(lead) and \(last) are in season now, along with \(remainder) more. Time to cook fresh."
            } else {
                content.body = "\(lead) and \(last) are hitting their peak. Time to cook fresh."
            }
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { logger.error("Failed to schedule season change notification: \(error)") }
        }

        logger.info("Season change notification scheduled: \(nextSeason.rawValue) \(year, privacy: .public)")
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

    @AppStorage(SmartNotificationService.SettingsKey.weeklyPlanning)
    private var weeklyPlanning = true

    @AppStorage(SmartNotificationService.SettingsKey.seasonChange)
    private var seasonChange = true

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

                Toggle("Weekend Meal Planning", systemImage: "calendar", isOn: $weeklyPlanning)
                    .tint(.green)

                Toggle("New Season Highlights", systemImage: "leaf", isOn: $seasonChange)
                    .tint(.mint)
            } header: {
                Text("Notification Types")
            } footer: {
                Text("Choose which notifications you'd like to receive. Turning a type off cancels anything already scheduled.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: pantryAlerts)    { if !pantryAlerts    { SmartNotificationService.shared.cancelPending(forSettingsKey: SmartNotificationService.SettingsKey.pantryAlerts) } }
        .onChange(of: mealReminders)   { if !mealReminders   { SmartNotificationService.shared.cancelPending(forSettingsKey: SmartNotificationService.SettingsKey.mealReminders) } }
        .onChange(of: streakReminders) { if !streakReminders { SmartNotificationService.shared.cancelPending(forSettingsKey: SmartNotificationService.SettingsKey.streakReminders) } }
        .onChange(of: weeklyPlanning)  { if !weeklyPlanning  { SmartNotificationService.shared.cancelPending(forSettingsKey: SmartNotificationService.SettingsKey.weeklyPlanning) } }
        .onChange(of: seasonChange)    { if !seasonChange    { SmartNotificationService.shared.cancelPending(forSettingsKey: SmartNotificationService.SettingsKey.seasonChange) } }
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
