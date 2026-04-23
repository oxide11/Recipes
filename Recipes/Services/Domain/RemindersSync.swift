import EventKit
import SwiftData
import SwiftUI

// MARK: - Pantry Ingestion Service

/// Shared logic for turning a purchased GroceryItem into a PantryItem (and
/// reversing it when an item is un-checked). Called from both the Mise UI
/// checkbox path and the Reminders sync pull path so the "checked off → lives
/// in pantry" loop holds regardless of where the check happened.
enum PantryIngestionService {

    /// Create a linked PantryItem for a purchased GroceryItem, unless one
    /// already exists (either linked or matched by canonical name).
    static func addToPantryIfNeeded(
        _ item: GroceryItem,
        existingPantryItems: [PantryItem],
        context: ModelContext
    ) {
        guard let category = item.storeSection.pantryCategory else { return }
        guard item.linkedPantryItemID == nil else { return }

        // Canonical match so "onions" and "medium onion" are treated as the
        // same pantry entry rather than duplicating it.
        let canonical = IngredientNormalizer.canonicalize(item.name)
        guard !existingPantryItems.contains(where: {
            IngredientNormalizer.canonicalize($0.name) == canonical
        }) else { return }

        let pantryItem = PantryItem(
            name: item.name,
            category: category,
            quantity: item.quantity,
            unit: item.unit
        )
        context.insert(pantryItem)
        item.linkedPantryItemID = pantryItem.id
    }

    /// Reverse the link when a user un-checks an item — removes the pantry
    /// entry that was auto-created from the grocery row.
    static func removeFromPantryIfPresent(
        _ item: GroceryItem,
        existingPantryItems: [PantryItem],
        context: ModelContext
    ) {
        guard let linkedID = item.linkedPantryItemID else { return }
        if let pantryItem = existingPantryItems.first(where: { $0.id == linkedID }) {
            context.delete(pantryItem)
        }
        item.linkedPantryItemID = nil
    }
}

// MARK: - Reminders Sync

/// Bidirectional sync between the app's single GroceryList and a chosen
/// Reminders calendar. No AI credits used — pure EventKit.
@Observable
@MainActor
final class RemindersSync {

    // MARK: State

    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    var isSyncing = false

    /// Stored property so @Observable tracks changes and SwiftUI re-renders immediately.
    /// Persisted to UserDefaults via didSet.
    var linkedCalendarIdentifier: String? {
        didSet { UserDefaults.standard.set(linkedCalendarIdentifier, forKey: "remindersCalendarIdentifier") }
    }

    var isLinked: Bool { linkedCalendarIdentifier != nil }

    var linkedCalendar: EKCalendar? {
        guard let id = linkedCalendarIdentifier else { return nil }
        return store.calendar(withIdentifier: id)
    }

    // MARK: Private

    private let store = EKEventStore()

    init() {
        linkedCalendarIdentifier = UserDefaults.standard.string(forKey: "remindersCalendarIdentifier")
    }

    // MARK: - Access

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToReminders()
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return granted
        } catch {
            return false
        }
    }

    func availableCalendars() -> [EKCalendar] {
        store.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    func createAndLink(named name: String) throws {
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = name
        calendar.source = store.defaultCalendarForNewReminders()?.source
        try store.saveCalendar(calendar, commit: true)
        linkedCalendarIdentifier = calendar.calendarIdentifier
    }

    func link(to calendar: EKCalendar) {
        linkedCalendarIdentifier = calendar.calendarIdentifier
    }

    func unlink() {
        linkedCalendarIdentifier = nil
    }

    // MARK: - Initial Migration

    /// Run once when the user first links a Reminders list.
    /// 1. Removes completed Mise items (they're done).
    /// 2. Pushes remaining Mise items to Reminders (so Reminders gets them too).
    /// 3. Pulls incomplete Reminders items not already in Mise (by name, case-insensitive).
    /// Result: both lists contain exactly the same active items with no duplicates.
    func performInitialMigration(groceryList: GroceryList, context: ModelContext) async {
        guard let identifier = linkedCalendarIdentifier,
              let calendar = store.calendar(withIdentifier: identifier) else { return }

        isSyncing = true
        defer { isSyncing = false }

        let reminders = await fetchAllReminders(in: calendar)
        let incompleteReminders = reminders.filter { !$0.isCompleted }
        let remindersByTitle = Dictionary(grouping: incompleteReminders) {
            ($0.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        }

        // Snapshot before mutating
        let completedItems = groceryList.items.filter(\.isPurchased)
        let activeItems    = groceryList.items.filter { !$0.isPurchased }

        // Step 1 — remove completed Mise items
        completedItems.forEach { context.delete($0) }

        // Step 2 — push active Mise items to Reminders (link or create)
        for item in activeItems {
            let key = item.name.lowercased().trimmingCharacters(in: .whitespaces)
            if let existing = remindersByTitle[key]?.first {
                item.remindersIdentifier = existing.calendarItemIdentifier
            } else {
                let reminder = EKReminder(eventStore: store)
                reminder.title = item.name
                reminder.calendar = calendar
                try? store.save(reminder, commit: false)
                item.remindersIdentifier = reminder.calendarItemIdentifier
            }
        }

        // Step 3 — pull incomplete Reminders items not already in Mise
        let activeKeys = Set(activeItems.map { $0.name.lowercased().trimmingCharacters(in: .whitespaces) })
        for reminder in incompleteReminders {
            guard let title = reminder.title, !title.isEmpty else { continue }
            let key = title.lowercased().trimmingCharacters(in: .whitespaces)
            guard !activeKeys.contains(key) else { continue }

            let item = GroceryItem(
                name: title,
                quantity: 1,
                unit: .piece,
                storeSection: guessSection(for: title)
            )
            item.remindersIdentifier = reminder.calendarItemIdentifier
            context.insert(item)
            groceryList.items.append(item)
        }

        try? store.commit()
    }

    // MARK: - Sync

    /// Pull from Reminders → app, push app → Reminders. Safe to call on every foreground.
    func sync(groceryList: GroceryList, context: ModelContext) async {
        guard let identifier = linkedCalendarIdentifier,
              let calendar = store.calendar(withIdentifier: identifier) else { return }
        guard authorizationStatus == .fullAccess else { return }

        isSyncing = true
        defer { isSyncing = false }

        // Fetch all reminders (completed + incomplete) from the linked calendar
        let reminders = await fetchAllReminders(in: calendar)

        let remindersByID    = Dictionary(uniqueKeysWithValues: reminders.map { ($0.calendarItemIdentifier, $0) })
        let remindersByTitle = Dictionary(grouping: reminders) {
            ($0.title ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        }

        // Build a map of GroceryItems that already have a Reminders link
        var itemsByReminderID: [String: GroceryItem] = [:]
        for item in groceryList.items {
            if let rid = item.remindersIdentifier {
                itemsByReminderID[rid] = item
            }
        }

        // Fetch pantry once for ingestion cross-reference. Cheaper than fetching
        // per item, and we re-read the context's live objects (no snapshot drift).
        let pantryItems = (try? context.fetch(FetchDescriptor<PantryItem>())) ?? []

        // ── Pull: Reminders → GroceryList ───────────────────────────────────
        for reminder in reminders {
            guard let title = reminder.title, !title.isEmpty else { continue }
            let key = title.lowercased().trimmingCharacters(in: .whitespaces)
            let rid = reminder.calendarItemIdentifier

            if let item = itemsByReminderID[rid] {
                // Already linked — sync completion state both ways (Reminders wins for pulls)
                if reminder.isCompleted != item.isPurchased {
                    item.isPurchased = reminder.isCompleted
                    // Mirror the Mise UI checkbox behaviour so checking off in the
                    // Reminders app also flows through to the pantry.
                    if reminder.isCompleted {
                        PantryIngestionService.addToPantryIfNeeded(
                            item,
                            existingPantryItems: pantryItems,
                            context: context
                        )
                    } else {
                        PantryIngestionService.removeFromPantryIfPresent(
                            item,
                            existingPantryItems: pantryItems,
                            context: context
                        )
                    }
                }
            } else if !reminder.isCompleted,
                      !groceryList.items.contains(where: { $0.name.lowercased() == key }) {
                // New incomplete reminder not yet in the app → add it
                // (skip completed reminders — they were either checked off elsewhere
                // or marked done by Mise when the item was deleted, and should not return)
                let item = GroceryItem(
                    name: title,
                    quantity: 1,
                    unit: .piece,
                    storeSection: guessSection(for: title)
                )
                item.remindersIdentifier = rid
                item.isPurchased = reminder.isCompleted
                context.insert(item)
                groceryList.items.append(item)
                itemsByReminderID[rid] = item
            }
        }

        // ── Push: GroceryList → Reminders ───────────────────────────────────
        for item in groceryList.items {
            if let rid = item.remindersIdentifier, let reminder = remindersByID[rid] {
                // Already linked — push completion state if app is ahead
                if item.isPurchased != reminder.isCompleted {
                    reminder.isCompleted = item.isPurchased
                    if item.isPurchased { reminder.completionDate = .now }
                    try? store.save(reminder, commit: false)
                }
            } else {
                // Not linked yet — match by name or create new reminder
                let key = item.name.lowercased().trimmingCharacters(in: .whitespaces)
                if let existing = remindersByTitle[key]?.first {
                    item.remindersIdentifier = existing.calendarItemIdentifier
                } else {
                    let reminder = EKReminder(eventStore: store)
                    reminder.title = item.name
                    reminder.calendar = calendar
                    reminder.isCompleted = item.isPurchased
                    try? store.save(reminder, commit: false)
                    item.remindersIdentifier = reminder.calendarItemIdentifier
                }
            }
        }

        try? store.commit()
    }

    /// Create a Reminders entry for a newly-added GroceryItem immediately, without
    /// waiting for the next throttled sync. Call this from any add-item code path
    /// (AddShoppingItemView, meal-plan "add missing to shopping," recommended
    /// staples, receipt OCR). Idempotent — skips items already linked.
    func pushAdd(_ item: GroceryItem) {
        pushAdd([item])
    }

    /// Bulk variant for callers that add many items at once (e.g. generating a
    /// shopping list from a meal plan's missing ingredients). Uses a single
    /// EventKit commit for the entire batch instead of one-per-item.
    func pushAdd(_ items: [GroceryItem]) {
        guard isLinked,
              let calendar = linkedCalendar,
              authorizationStatus == .fullAccess else { return }

        var saved = false
        for item in items where item.remindersIdentifier == nil {
            let reminder = EKReminder(eventStore: store)
            reminder.title = item.name
            reminder.calendar = calendar
            reminder.isCompleted = item.isPurchased
            do {
                try store.save(reminder, commit: false)
                item.remindersIdentifier = reminder.calendarItemIdentifier
                saved = true
            } catch {
                // Continue with remaining items; next full sync will retry this one.
            }
        }
        if saved { try? store.commit() }
    }

    /// Push the current isPurchased state to Reminders immediately when the user
    /// taps the checkbox. Without this, the next sync pull sees the reminder still
    /// incomplete and overwrites the local change back to false.
    func pushCompletion(for item: GroceryItem) {
        guard isLinked,
              let rid = item.remindersIdentifier,
              let reminder = store.calendarItem(withIdentifier: rid) as? EKReminder else { return }
        reminder.isCompleted = item.isPurchased
        if item.isPurchased { reminder.completionDate = .now } else { reminder.completionDate = nil }
        try? store.save(reminder, commit: true)
    }

    /// When an item is removed from Mise, mark the corresponding reminder as completed
    /// rather than deleting it — this preserves the user's Reminders data and prevents
    /// the sync from re-adding the item on the next pass (sync skips completed reminders).
    func completeReminder(for item: GroceryItem) {
        completeReminderByID(item.remindersIdentifier)
    }

    /// ID-based variant — call this after the GroceryItem has already been deleted
    /// from SwiftData so the UI update isn't blocked by the EventKit write.
    func completeReminderByID(_ identifier: String?) {
        guard isLinked,
              let rid = identifier,
              let reminder = store.calendarItem(withIdentifier: rid) as? EKReminder else { return }
        reminder.isCompleted = true
        reminder.completionDate = .now
        try? store.save(reminder, commit: true)
    }

    // MARK: - Helpers

    /// EKReminder isn't Sendable, so we fetch on the EventKit callback queue
    /// and immediately convert to a plain struct before crossing the concurrency boundary.
    private struct ReminderSnapshot: Sendable {
        var calendarItemIdentifier: String
        var title: String
        var isCompleted: Bool
    }

    private func fetchAllReminders(in calendar: EKCalendar) async -> [EKReminder] {
        let snapshots: [ReminderSnapshot] = await withCheckedContinuation { cont in
            let predicate = store.predicateForReminders(in: [calendar])
            // The completion fires on com.apple.eventkit.reminders.search — a background
            // queue. A closure defined inside a @MainActor method is @MainActor-bound,
            // which causes a dispatch_assert_queue crash. Extract via a nonisolated static
            // factory so the block carries no actor requirement (same fix as installTap).
            store.fetchReminders(matching: predicate, completion: Self.makeSnapshotBlock(continuation: cont))
        }
        // Re-fetch live EKReminder objects by identifier now that we're back on the
        // MainActor so EventKit property access is safe.
        return snapshots.compactMap {
            store.calendarItem(withIdentifier: $0.calendarItemIdentifier) as? EKReminder
        }
    }

    /// Returns a completion block with no actor isolation. Must be nonisolated and
    /// static so the returned closure is not @MainActor-bound — EventKit fires the
    /// completion on its own serial queue.
    private nonisolated static func makeSnapshotBlock(
        continuation: CheckedContinuation<[ReminderSnapshot], Never>
    ) -> (([EKReminder]?) -> Void) {
        { reminders in
            let snaps = (reminders ?? []).map {
                ReminderSnapshot(
                    calendarItemIdentifier: $0.calendarItemIdentifier,
                    title: $0.title ?? "",
                    isCompleted: $0.isCompleted
                )
            }
            continuation.resume(returning: snaps)
        }
    }

    private func guessSection(for name: String) -> StoreSection {
        StoreSection.guess(for: name)
    }
}
