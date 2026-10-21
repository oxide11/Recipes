# Recipes App Backlog

Audit completed 2026-04-26. Items are grouped by category and sorted by severity within each group.

---

## Stability — Crash Risks

- [x] **CRITICAL** `RecipesApp.swift:71` — Production `fatalError()` on schema migration failure. ~~No `VersionedSchema` or `MigrationPlan` defined; any model change crashes prod.~~ Fixed: falls back to in-memory store in production, and the app now shows a persistent "Temporary mode" banner plus an explanatory alert so the user knows changes won't persist.
- [x] **HIGH** `RecipesApp.swift` — Define a `VersionedSchema` + `SchemaMigrationPlan` so model changes migrate instead of triggering the in-memory fallback. Fixed: `RecipesSchemaV1` + `RecipesMigrationPlan` in Models/RecipesSchema.swift; add V2 + a stage for the next model change.
- [x] **CRITICAL** `ContentView.swift:118` — `try!` on preview `ModelContainer` init; crashes if creation fails. Fixed: uses do/catch with fatalError only in preview context.
- [x] **HIGH** `CookingLogEntryView.swift:199` — Force unwrap `photo!` after optional assignment; crashes if `PhotoStorageService.save()` fails. Fixed: safe binding.
- [ ] **HIGH** `RecipeIngestionService.swift:1194` — Unsafe force-unwrap of string indices from malformed JSON.
- [ ] **MEDIUM** `RecipeIngestionService.swift:1056,1062` — Force unwrap in `parseFraction()` results without nil check.

## Stability — Network & Timeouts

- [x] **CRITICAL** `APIClient.swift:30` — No request timeout on URLSession; AI calls can hang indefinitely. Fixed: shared `NetworkSession.ai` with `timeoutIntervalForResource` (total-duration cap). Note: `URLRequest.timeoutInterval` is idle-only and defaults to 60s, so the earlier per-request value was a no-op.
- [x] **CRITICAL** `RecipeIngestionService.swift:30,615` — URL fetch and image download with no timeout configured. Fixed: uses `NetworkSession.standard` (20s idle / 45s total).
- [x] **MEDIUM** `OpenFoodFactsService.swift:46,83` — No timeout on barcode lookup network requests. Fixed: uses `NetworkSession.standard`.

## Stability — Silent Error Swallowing

- [x] **HIGH** `MealPlanView.swift` — Meal-plan generation dismissed the sheet then failed silently. Fixed: parent view shows a progress pill while generating and an alert with "Try Again" on failure or when no meals could be added.
- [x] **HIGH** `MealPlanView.swift:applyMeals` — `Dictionary(uniqueKeysWithValues:)` trapped when two recipes shared a title case-insensitively. Fixed: `uniquingKeysWith:`.
- [x] **MEDIUM** `RecipeEditorView.swift` — Step ingredient chips snapshotted name/amount, so editing the ingredient row left chips and saved directions stale; `.popover` on the `Section` presented on every row. Fixed: chips reference ingredients by ID and resolve on save; each step row owns its popover.

- [ ] **HIGH** `RemindersSync.swift:157,266,278,309` — Bare `try?` on EventKit operations; sync failures are invisible.
- [x] **HIGH** `RemindersSync.sync` — a reminder deleted in the Reminders app was recreated on every sync. Fixed: linked items whose reminder vanished are deleted (guarded on a non-empty fetch).
- [x] **HIGH** Guided shopping, substitutions and receipt matching set `isPurchased` without `pushCompletion`, so the next pull reverted them. Fixed: all three push; substitutions and receipt matches also ingest into the pantry.
- [ ] **HIGH** `PhotoStorageService.swift:15,54` — Silent `try?` on directory creation and file deletion; orphaned files accumulate.
- [ ] **HIGH** `RecipeIngestionService.swift:277,301` — Vision OCR errors silently ignored.
- [ ] **MEDIUM** `ClaudeService.swift:164` — `try?` swallows JSON serialization error in streaming request.
- [x] **CRITICAL** `SmartNotificationService.swift` — Every scheduler guarded on `UserDefaults.bool(forKey:)` for keys never written, so nothing fired on a fresh install. Fixed: `registerDefaults()` at launch; past-dated triggers now roll to the next slot; streak body no longer prints `Int.max`; turning a type off cancels its pending requests; alerts for deleted pantry items are removed.
- [ ] **MEDIUM** `SmartNotificationService.swift:280,348` — Notification scheduling failures invisible.
- [ ] **MEDIUM** `SmartNotificationService.scheduleMealPlanReminders` — never called. Blocked on PlannedMeal having a time of day; `meal.date` is start-of-day so "30 minutes before" would fire at 23:30 the previous evening.
- [ ] **MEDIUM** `SampleData.swift:12-27` — `clearAll()` silently ignores deletion errors.

## Concurrency & Task Management

- [ ] **HIGH** `ShoppingVoiceService.swift:232-237` — `speechFinishedContinuation` accessed without synchronization; race on concurrent `speak()`.
- [x] **HIGH** `ShoppingVoiceService.swift:42` — `guidanceTask` stored but never cancelled on deinit; leaks if view dismissed. Fixed: `GuidedShoppingView` calls `stopSession()` in `onDisappear`, so a swiped-away sheet cancels guidance and speech.
- [x] **HIGH** `RecipeIngestionService.swift:194` — Streaming loop doesn't check `Task.isCancelled`; leaked task on view dismiss. Fixed: added `Task.checkCancellation()` in both streaming loops.
- [ ] **HIGH** `BarcodeScannerService.swift:78,87` — `DispatchQueue.global()` instead of structured concurrency; no cancellation support.
- [x] **HIGH** `DashboardView.swift:170-173` — Four `onChange` handlers spawn async tasks without cancellation; rapid fires create concurrent task pile-up. Already handled: `scheduleSuggestionRebuild()` cancels previous task; other handlers are synchronous.
- [ ] **MEDIUM** `FoundationModelService.swift:37` — Cached `_session` is not atomic; concurrent access could create duplicates.
- [ ] **MEDIUM** `RemindersSync.swift:65` — Authorization status queried once at init, not refreshed before operations.

## Performance — View Layer

- [ ] **HIGH** `DashboardView.swift:206-305` — `rebuildSuggestions()` does O(n²) substring matching across recipes × pantry items on every rebuild.
- [x] **HIGH** `MealPlanView.swift:660-661` — `onChange(of: pantryItems.map { ... })` creates a new array every render and triggers expensive recompute. Reverted to a name-based trigger: count-only missed renames, leaving "missing ingredient" state stale. `onChange` only fires when the mapped array actually differs, so the cost is negligible.
- [x] **HIGH** `MetricsView.swift:29-35` — Duplicate `.task` calls with same trigger, calling calculation function twice. Fixed: merged into single `.task(id:)` keyed on an array of counts (a sum let offsetting changes cancel out).
- [x] **MEDIUM** `CookingModeView.swift:41-47` — `ingredientColors` dictionary rebuilt on every body evaluation; should be `@State`. Fixed: moved to `@State`, populated once on appear.
- [ ] **MEDIUM** `RecipeListView.swift:59-94` — Multiple filter passes instead of single combined predicate.
- [x] **MEDIUM** `MealPlanView.swift:975,1088` — `ISO8601DateFormatter` allocated inside function body on every call. Fixed: static formatter on `GenerateMealPlanSheet`.

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

## Build & Packaging

- [x] **CRITICAL** `Views/Components/AIRecipeEditView.swift` — duplicate `struct AIRecipeEditView` (also in Views/Recipes). XcodeGen compiles the whole folder, so the default branch failed with an invalid redeclaration. Fixed: dead Components copy deleted.
- [x] **CRITICAL** `project.yml` — widget target excluded its Info.plist and generated one without `NSExtensionPointIdentifier`. Fixed: `INFOPLIST_FILE` set so the generated plist merges with it.

## AI & Privacy

- [x] **HIGH** `AIServiceRouter.preferredProvider` — in-memory only; reset to Hybrid every launch. Fixed: persisted in UserDefaults (`ai_preferredProvider`). `UserProfile.preferredAIProvider` / `enableOnDeviceAI` remain dead fields to remove.
- [x] **HIGH** `AIServiceRouter` — "On-Device Only" still sent images and streaming prompts to Claude/OpenAI. Fixed: images throw `cloudRequiredForImages` with guidance; streaming surfaces the on-device error instead of falling back.
- [x] **HIGH** Prompts ignored `UserProfile.allergens`, `dislikedIngredients`, `maxCookTimeMinutes`. Fixed: `UserProfile.aiConstraintClause` / `aiHardLimitsClause` appended in RecipeGeneratorView (both builders) and MealPlanView generation.
- [x] **HIGH** `FoundationModelService` — one cached `LanguageModelSession` shared across every task; transcript grows, concurrent calls throw. Fixed: recycled after 12 transcript entries, throwaway session while responding, retry on context overflow.
- [x] **HIGH** `FoundationModelService:327` — `ParsedRecipeFromOCR` capped at 10 ingredients but used for real parsing. Fixed: cap moved to the generation prompt only.
- [x] **HIGH** `AIServiceRouter.hybridGeneration` — accepts on-device prose as success so JSON parse fails with no cloud retry. Fixed: JSON tasks validate on-device output and fall through.
- [x] **HIGH** `RecipeIngestionService:284` — URL imports without JSON-LD truncated to ~2000 chars by the sanitizer. Fixed: 6,000 for page content; injection phrases neutralised in place instead of dropping lines.
- [x] **MEDIUM** `RecipeIngestionService.parseIngestionResponse` — strict Decodable fails on `servings: "4-6"`, numeric amounts, float nutrition. Fixed: lenient `init(from:)` and a decode reason in `parsingFailed`.

## Features Completed From the Inventory

- [x] Pantry quantities: Add, Edit and barcode manual-add take quantity + unit (`PantryQuantityRow`).
- [x] Auto-deduct pantry: `PantryDeductionService` (canonical names, unit conversion) runs from the full log, quick log and Cooking Mode when `autoDeductPantry` is on.
- [x] Seasonality follows the profile hemisphere (`Season.activeHemisphere`); seasonal lookup matches canonical names.
- [x] Recommendations referencing a saved recipe open it instead of the generator.
- [x] Onboarding: Skip pantry setup skips; custom ingredients are kept.
- [x] Settings: "(todo)" iCloud toggles removed; Developer/Debug sections DEBUG-only; Measurements picker saves to profile.
- [x] Measurement system applied to recipe-detail ingredient rows and step chips.
- [x] Currency from the profile used in Metrics, Bulk Photo Add, receipt matching and the budget placeholder.
- [x] Receipt scanner reaches a grocery list (Dashboard and a new Shopping row), records actual prices, moves matched items to the pantry and closes their reminders.
- [x] Tag management case-insensitive; journal dish photo removal deferred to Save.
- [x] Receipt scanner "Photo OCR" stub removed; the live text scan + regex parse is the one path.
- [ ] Meal plan reminders need a meal time on `PlannedMeal` before `scheduleMealPlanReminders` can be wired.
- [x] `ShoppingListGenerator` wired: Shopping list "Add This Week's Meal Plan" (empty state and progress section) merges the next 7 days' ingredients into the single list, net of pantry and items already listed.
- [x] `SafeCookingTemperatureService` wired: ingestion attaches USDA temperatures to protein ingredients and badges the step where the protein is cooked.
- [x] `SubstitutionEngine` lookup is canonical ("unsalted butter", "eggs", "whole milk" now resolve).
- [x] Dead code removed: `MealPlanGenerator`, `SeasonalRecipesView`, `QuickMealsView`, `IngredientFilter`, `CuisineFilterSheet`, `ImportPhotoPickerButton`, four unused `AITaskType` cases.
- [ ] `MultiRecipeCookingService` / Cook All remains built but hidden (`MealPlanView` "hidden for now"). Decide: ship or delete.
- [ ] Variations have no create UI; widget timeline still returns placeholder data; dead model fields (`isFavorite`, `sourceMarkdown`, carb/fat targets, iCloud flags, profile time totals) need a schema V2 to remove.

## Architecture

- [x] **HIGH** `ContentView.swift:62-73` — Overlapping `onChange` handlers all call `SmartNotificationService` methods; duplicate notifications. Fixed: all onChange handlers now call unified `scheduleAllNotifications()`.
- [ ] **MEDIUM** `PlanAndShopView.swift:30-39,72-81` — ZStack opacity swap keeps both sub-views in memory; doubles RAM with full `@Query` datasets.
- [ ] **MEDIUM** `DashboardView.swift:97-100` — `currentMealType` depends on `.now`, recalculated every render.
- [ ] **LOW** `DashboardView.swift:41-44` — Cached state renders empty before `.task` populates; brief flicker on first render.

---

*Last updated: 2026-10-21*
