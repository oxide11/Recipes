# Recipes App Backlog

Audit completed 2026-04-26. Reconciled against the code on 2026-08-30 — a number of
items had been fixed without being checked off; those are now marked with the
evidence that closed them. Line numbers refreshed where they had drifted.

Items are grouped by category and sorted by severity within each group.

---

## Stability — Crash Risks

- [x] **CRITICAL** `RecipesApp.swift:71` — Production `fatalError()` on schema migration failure. ~~No `VersionedSchema` or `MigrationPlan` defined; any model change crashes prod.~~ Fixed: falls back to in-memory store in production.
- [x] **CRITICAL** `ContentView.swift:118` — `try!` on preview `ModelContainer` init; crashes if creation fails. Fixed: uses do/catch with fatalError only in preview context.
- [x] **HIGH** `CookingLogEntryView.swift:199` — Force unwrap `photo!` after optional assignment; crashes if `PhotoStorageService.save()` fails. Fixed: safe binding.
- [x] **HIGH** `RecipeIngestionService.swift` — ~~Unsafe force-unwrap of string indices from malformed JSON.~~ Verified fixed 2026-08-30: `parseIngestionResponse` (now :1167) guards `firstIndex(of: "{")` / `lastIndex(of: "}")` and throws `IngestionError.parsingFailed`.
- [x] **MEDIUM** `RecipeIngestionService.swift` — ~~Force unwrap in `parseFraction()` results without nil check.~~ Verified fixed 2026-08-30: `parseFraction` (now :1108) is fully optional-chained and guards `den != 0`.

## Stability — Network & Timeouts

- [x] **CRITICAL** `APIClient.swift:30` — No request timeout on URLSession; AI calls can hang indefinitely. Fixed: 60s timeout.
- [x] **CRITICAL** `RecipeIngestionService.swift:30,615` — URL fetch and image download with no timeout configured. Fixed: 30s/15s timeouts.
- [x] **MEDIUM** `OpenFoodFactsService.swift:46,83` — No timeout on barcode lookup network requests. Fixed: 15s timeout.

## Stability — Silent Error Swallowing

- [x] **HIGH** `RemindersSync.swift` — ~~Bare `try?` on EventKit operations; sync failures are invisible.~~ Fixed 2026-08-30: all 8 save/commit sites now route through logged `save(_:commit:operation:)` / `commitPendingWrites(operation:)` helpers. Also fixed a latent bug — a failed save no longer links `remindersIdentifier` to a reminder that was never stored.
- [x] **HIGH** `PhotoStorageService.swift` — ~~Silent `try?` on directory creation and file deletion; orphaned files accumulate.~~ Fixed 2026-08-30: both sites are do/catch with OSLog; `delete` treats `CocoaError.fileNoSuchFile` as a legitimate no-op.
- [x] **HIGH** `RecipeIngestionService.swift` — ~~Vision OCR errors silently ignored.~~ Verified fixed 2026-08-30: `recognizeText(in:)` (now :221) resumes its continuation with the Vision error, the empty-result case, and any `handler.perform` throw.
- [x] **MEDIUM** `ClaudeService.swift` — ~~`try?` swallows JSON serialization error in streaming request.~~ Verified fixed 2026-08-30: the `guard let bodyData` at :164 finishes the stream with `AIServiceError.invalidResponse` rather than swallowing.
- [x] **MEDIUM** `SmartNotificationService.swift` — ~~Notification scheduling failures invisible.~~ Verified fixed 2026-08-30: both `center.add` completion handlers log via `logger.error`.
- [x] **MEDIUM** `SampleData.swift` — ~~`clearAll()` silently ignores deletion errors.~~ Fixed 2026-08-30: per-model deletes go through a local generic helper that logs failures, so a partial wipe is no longer indistinguishable from a clean one.

## Concurrency & Task Management

- [x] **HIGH** `ShoppingVoiceService.swift` — ~~`speechFinishedContinuation` accessed without synchronization; race on concurrent `speak()`.~~ Verified fixed 2026-08-30: the class is `@MainActor`, and `speak()` stamps a `speakToken` UUID so a cancelled call can't clear a newer call's continuation.
- [ ] **LOW** `ShoppingVoiceService.swift:42` — `guidanceTask` is cancelled in `stopSession()` and re-armed in `advance`, but still not cancelled from `deinit`. Only leaks if a view is torn down without calling `stopSession()`. Downgraded from HIGH — a `deinit` cancel needs care since Swift 6 `deinit` is nonisolated and the property is `@MainActor`-isolated.
- [x] **HIGH** `RecipeIngestionService.swift:194` — Streaming loop doesn't check `Task.isCancelled`; leaked task on view dismiss. Fixed: added `Task.checkCancellation()` in both streaming loops.
- [ ] **HIGH** `BarcodeScannerService.swift:78,87` — `DispatchQueue.global()` instead of structured concurrency; no cancellation support.
- [x] **HIGH** `DashboardView.swift:170-173` — Four `onChange` handlers spawn async tasks without cancellation; rapid fires create concurrent task pile-up. Already handled: `scheduleSuggestionRebuild()` cancels previous task; other handlers are synchronous.
- [x] **MEDIUM** `FoundationModelService.swift` — ~~Cached `_session` is not atomic; concurrent access could create duplicates.~~ Verified fixed 2026-08-30: the class is `@MainActor`, so `cachedSession` (:14) cannot be reached concurrently.
- [ ] **MEDIUM** `RemindersSync.swift:68` — `authorizationStatus` is refreshed on the permission-request path (:97) but not before `sync`/`pushAdd` (:193, :306). A revoke while backgrounded leaves a stale `.fullAccess`.

## Performance — View Layer

- [ ] **HIGH** `DashboardView.swift:206-305` — `rebuildSuggestions()` does O(n²) substring matching across recipes × pantry items on every rebuild.
- [x] **HIGH** `MealPlanView.swift:660-661` — `onChange(of: pantryItems.map { ... })` creates a new array every render and triggers expensive recompute. Fixed: removed redundant onChange, kept count-based trigger.
- [x] **HIGH** `MetricsView.swift:29-35` — Duplicate `.task` calls with same trigger, calling calculation function twice. Fixed: merged into single `.task(id:)`.
- [x] **MEDIUM** `CookingModeView.swift:41-47` — `ingredientColors` dictionary rebuilt on every body evaluation; should be `@State`. Fixed: moved to `@State`, populated once on appear.
- [ ] **MEDIUM** `RecipeListView.swift:59-94` — Multiple filter passes instead of single combined predicate.
- [x] **MEDIUM** `MealPlanView.swift` — ~~`ISO8601DateFormatter` allocated inside function body on every call.~~ Fixed 2026-08-30: hoisted to `GenerateMealPlanSheet.isoDateFormatter` (:858), shared by `buildPrompt` and `applyMeals`, matching the cached-formatter idiom in `RecipeExportService`.

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

*Last updated: 2026-08-30*
