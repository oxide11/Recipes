# Recipes App Backlog

Audit completed 2026-04-26. Items are grouped by category and sorted by severity within each group.

---

## Stability — Crash Risks

- [x] **CRITICAL** `RecipesApp.swift:71` — Production `fatalError()` on schema migration failure. ~~No `VersionedSchema` or `MigrationPlan` defined; any model change crashes prod.~~ Fixed: falls back to in-memory store in production.
- [x] **CRITICAL** `ContentView.swift:118` — `try!` on preview `ModelContainer` init; crashes if creation fails. Fixed: uses do/catch with fatalError only in preview context.
- [x] **HIGH** `CookingLogEntryView.swift:199` — Force unwrap `photo!` after optional assignment; crashes if `PhotoStorageService.save()` fails. Fixed: safe binding.
- [ ] **HIGH** `RecipeIngestionService.swift:1194` — Unsafe force-unwrap of string indices from malformed JSON.
- [ ] **MEDIUM** `RecipeIngestionService.swift:1056,1062` — Force unwrap in `parseFraction()` results without nil check.

## Stability — Network & Timeouts

- [x] **CRITICAL** `APIClient.swift:30` — No request timeout on URLSession; AI calls can hang indefinitely. Fixed: 60s timeout.
- [x] **CRITICAL** `RecipeIngestionService.swift:30,615` — URL fetch and image download with no timeout configured. Fixed: 30s/15s timeouts.
- [x] **MEDIUM** `OpenFoodFactsService.swift:46,83` — No timeout on barcode lookup network requests. Fixed: 15s timeout.

## Stability — Silent Error Swallowing

- [ ] **HIGH** `RemindersSync.swift:157,266,278,309` — Bare `try?` on EventKit operations; sync failures are invisible.
- [ ] **HIGH** `PhotoStorageService.swift:15,54` — Silent `try?` on directory creation and file deletion; orphaned files accumulate.
- [ ] **HIGH** `RecipeIngestionService.swift:277,301` — Vision OCR errors silently ignored.
- [ ] **MEDIUM** `ClaudeService.swift:164` — `try?` swallows JSON serialization error in streaming request.
- [ ] **MEDIUM** `SmartNotificationService.swift:280,348` — Notification scheduling failures invisible.
- [ ] **MEDIUM** `SampleData.swift:12-27` — `clearAll()` silently ignores deletion errors.

## Concurrency & Task Management

- [ ] **HIGH** `ShoppingVoiceService.swift:232-237` — `speechFinishedContinuation` accessed without synchronization; race on concurrent `speak()`.
- [ ] **HIGH** `ShoppingVoiceService.swift:42` — `guidanceTask` stored but never cancelled on deinit; leaks if view dismissed.
- [x] **HIGH** `RecipeIngestionService.swift:194` — Streaming loop doesn't check `Task.isCancelled`; leaked task on view dismiss. Fixed: added `Task.checkCancellation()` in both streaming loops.
- [ ] **HIGH** `BarcodeScannerService.swift:78,87` — `DispatchQueue.global()` instead of structured concurrency; no cancellation support.
- [x] **HIGH** `DashboardView.swift:170-173` — Four `onChange` handlers spawn async tasks without cancellation; rapid fires create concurrent task pile-up. Already handled: `scheduleSuggestionRebuild()` cancels previous task; other handlers are synchronous.
- [ ] **MEDIUM** `FoundationModelService.swift:37` — Cached `_session` is not atomic; concurrent access could create duplicates.
- [ ] **MEDIUM** `RemindersSync.swift:65` — Authorization status queried once at init, not refreshed before operations.

## Performance — View Layer

- [ ] **HIGH** `DashboardView.swift:206-305` — `rebuildSuggestions()` does O(n²) substring matching across recipes × pantry items on every rebuild.
- [x] **HIGH** `MealPlanView.swift:660-661` — `onChange(of: pantryItems.map { ... })` creates a new array every render and triggers expensive recompute. Fixed: removed redundant onChange, kept count-based trigger.
- [x] **HIGH** `MetricsView.swift:29-35` — Duplicate `.task` calls with same trigger, calling calculation function twice. Fixed: merged into single `.task(id:)`.
- [x] **MEDIUM** `CookingModeView.swift:41-47` — `ingredientColors` dictionary rebuilt on every body evaluation; should be `@State`. Fixed: moved to `@State`, populated once on appear.
- [ ] **MEDIUM** `RecipeListView.swift:59-94` — Multiple filter passes instead of single combined predicate.
- [ ] **MEDIUM** `MealPlanView.swift:975,1088` — `ISO8601DateFormatter` allocated inside function body on every call.

## Performance — Data Layer

- [ ] **HIGH** `MetricsView.swift:8-10` — `@Query` fetches ALL Recipes, Receipts, and JournalEntries without predicates; loads entire tables.
- [ ] **HIGH** `RecipeGeneratorView.swift:418-420` — Multiple unfiltered `@Query` for pantry, recipes, profiles.
- [ ] **HIGH** `MealPlanView.swift:16-18` — Child views declare duplicate `@Query` for PantryItems and UserProfile.
- [ ] **MEDIUM** `All models` — No `@Index` attributes defined; queries do full table scans. Recommended indexes: Recipe.dateModified, PantryItem.dateAdded, PlannedMeal.date, GroceryList.dateCreated.
- [ ] **MEDIUM** `PantryView.swift:47-48` — Loads entire pantry inventory on view load; no pagination.
- [ ] **MEDIUM** `DashboardView.swift:27-36` — Eight `@Query` properties fetched simultaneously with no predicate filtering.
- [ ] **MEDIUM** `ShoppingListView.swift:222` — Batch delete in loop without transaction wrapping.
- [ ] **MEDIUM** `RecipeDetailView.swift:911,913` — Loop-based ingredient delete + re-insert is non-atomic.
- [ ] **MEDIUM** `OnboardingView.swift:653,684,719` — Multiple `modelContext.insert()` without transaction wrapping.

## Architecture

- [x] **HIGH** `ContentView.swift:62-73` — Overlapping `onChange` handlers all call `SmartNotificationService` methods; duplicate notifications. Fixed: all onChange handlers now call unified `scheduleAllNotifications()`.
- [ ] **MEDIUM** `PlanAndShopView.swift:30-39,72-81` — ZStack opacity swap keeps both sub-views in memory; doubles RAM with full `@Query` datasets.
- [ ] **MEDIUM** `DashboardView.swift:97-100` — `currentMealType` depends on `.now`, recalculated every render.
- [ ] **LOW** `DashboardView.swift:41-44` — Cached state renders empty before `.task` populates; brief flicker on first render.

---

*Last updated: 2026-04-26*
