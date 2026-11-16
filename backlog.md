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

- [x] **HIGH** `DashboardView.swift` — ~~`rebuildSuggestions()` does O(n²) substring matching across recipes × pantry items on every rebuild.~~ Fixed 2026-09-19: pantry, expiring and seasonal names are now built into a file-private `IngredientMatchIndex` once per rebuild (canonicalised + plural-varied via `IngredientNormalizer`, mirroring `NoWasteMatchingEngine`), so each ingredient lookup is a bounded set of dictionary hits instead of a scan. Also removed a `Bool.random()` sort comparator that violated strict weak ordering — only the top-scoring recipe is used, so it is now picked with `shuffled().max(by:)` in one pass.
- [x] **HIGH** `MealPlanView.swift:660-661` — `onChange(of: pantryItems.map { ... })` creates a new array every render and triggers expensive recompute. Fixed: removed redundant onChange, kept count-based trigger.
- [x] **HIGH** `MetricsView.swift:29-35` — Duplicate `.task` calls with same trigger, calling calculation function twice. Fixed: merged into single `.task(id:)`.
- [x] **MEDIUM** `CookingModeView.swift:41-47` — `ingredientColors` dictionary rebuilt on every body evaluation; should be `@State`. Fixed: moved to `@State`, populated once on appear.
- [ ] **MEDIUM** `RecipeListView.swift:59-94` — Multiple filter passes instead of single combined predicate.
- [x] **MEDIUM** `MealPlanView.swift` — ~~`ISO8601DateFormatter` allocated inside function body on every call.~~ Fixed 2026-08-30: hoisted to `GenerateMealPlanSheet.isoDateFormatter` (:858), shared by `buildPrompt` and `applyMeals`, matching the cached-formatter idiom in `RecipeExportService`.

## Performance — Data Layer

- [x] **HIGH** `MetricsView.swift` — ~~`@Query` fetches ALL Recipes, Receipts, and JournalEntries without predicates; loads entire tables.~~ Partly fixed 2026-09-19: `recipes` now filters on `!$0.cookingLog.isEmpty`. This is behaviour-preserving, not an approximation — `Recipe.cookCount` *is* `cookingLog.count`, and every recipe-derived metric skips zero-count recipes, so an uncooked recipe cannot affect the output. `receipts` and `restaurantEntries` are genuine whole-table aggregates (total spend, every visit) and are left unfiltered by design. **Needs a runtime smoke test** — a SwiftData predicate over a to-many relationship fails at fetch time, not compile time, if it can't be translated.
- [x] **MEDIUM** `MetricsView.swift` — `.task(id:)` summed three counts, so adding one recipe while deleting one receipt left the id unchanged and the metrics silently stale. Fixed 2026-09-19: the id is now an array, compared element-wise.
- [ ] **LOW** `RecipeGeneratorView.swift:418-420` — Multiple unfiltered `@Query` for pantry, recipes, profiles. Re-assessed 2026-09-19 and downgraded from HIGH: `existingRecipes` feeds whole-library aggregates (cuisine histogram at :527, total count in the prompt at :539-547), so no predicate preserves behaviour. Reducing this means fetching a count/aggregate instead of the objects, or moving prompt assembly behind a `FetchDescriptor` with `propertiesToFetch` — a real change, not a predicate.
- [ ] **LOW** `MealPlanView.swift:16-18` — Child views declare duplicate `@Query` for PantryItems and UserProfile. Re-assessed 2026-09-19 and downgraded from HIGH: the item is mis-scoped. `MealPlanView` never queries `PantryItem`, so `DayMealView:277` is the only fetch of it rather than a duplicate; the genuine duplication is `UserProfile`, which is a single row in practice. Threading it down through `DayMealView`/`GenerateMealPlanSheet` initialisers would churn several call sites for no measurable gain. The unfiltered `Recipe` fetches in `GenerateMealPlanSheet:867` and `AddMealView:1156` are the real cost here, and both are load-bearing — `AddMealView` filters the full library client-side for its picker (:1211-1220).
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

## Feature Ideas

Captured 2026-11-16, not yet scoped. Notes record what already exists so the
first hour of each isn't spent rediscovering it.

### Ingredient Sankey — flow of ingredients and quantities through a recipe

- [ ] **IDEA** Sankey/alluvial view of a recipe: ingredients on the left, flowing
      into the steps that consume them.

  **Already there.** The edge list exists — `RecipeDirection.ingredients` is
  `[DirectionIngredientRef]`, and each ref carries `ingredientName` plus an
  `IngredientAmount` (`Recipe.swift:92,112`). So "which ingredient goes into
  which step, and how much" is already modelled; this is a rendering problem,
  not a data problem. Band colours come free from
  `IngredientCategory` → `IngredientColor.swiftUIColor`, 14 branded colours
  already used elsewhere (`Ingredient.swift:102`). Swift Charts is already a
  dependency (`MetricsView`, `NutritionTrackingView`).

  **The real blocker: band width needs one comparable number, and we don't have
  one.** `MeasurementConversionService` keeps two *separate* bases —
  `volumeToMilliliters` and `weightToGrams` (`MeasurementConversion.swift:10,21`)
  — with no bridge between them. Putting "2 cups flour" and "1 lb chicken" on a
  shared axis needs density (g/ml) per ingredient, which the app has nowhere.
  Nine units (`piece, pinch, dash, bunch, clove, slice, whole, can, asNeeded`)
  have no magnitude at all (`Ingredient.swift:186`). Three ways out, cheapest
  first:
  1. **Don't scale by mass.** Equal-weight strands grouped by category. Honest,
     reads well, ships in a day, and arguably communicates structure better than
     true proportions would.
  2. **Scale within a unit family only** — weight-vs-weight, volume-vs-volume —
     and render count units as fixed-width strands.
  3. **Add a density / typical-weight table** keyed by canonical name
     (`IngredientNormalizer.canonicalize` already collapses "2 Medium Onions" →
     "onion", so the keys are stable). Most accurate, most upkeep.

  **Also note:** Swift Charts has no Sankey or alluvial mark, so the ribbons are
  a custom `Canvas`/`Path` with cubic Béziers. Budget the layout pass (node
  ordering to minimise crossings) as the bulk of the work, not the drawing.
  Recipes with many ingredients will need a minimum band height and a scroll or
  a "+N more" collapse — check it at Dynamic Type sizes before committing.

### Substitution mindmap — a node that expands into alternatives

- [ ] **IDEA** Tap an ingredient to expand a radial/mindmap node of substitutes,
      each showing conversion ratio and trade-off.

  **Already there.** `SubstitutionEngine.findSubstitutions(for:restrictions:)`
  returns `[Substitution]` carrying exactly what the node needs to display —
  `replacement`, `ratio`, `notes`, `dietaryBenefit`
  (`SubstitutionEngine.swift:10,135`). `IngredientNormalizer.substitutionGroups`
  adds interchangeable sets (oils, acids, vinegars, creams), and
  `AITaskType.ingredientSubstitution` can fill gaps the static table misses.

  **The gap is surfacing, not data.** `SubstitutionEngine` is currently wired
  into exactly one screen — `GuidedShoppingView` — so substitutions exist only
  while shopping. Natural homes: `IngredientRow` in `RecipeDetailView`, and
  `CookingModeView`, where "I'm out of buttermilk" actually happens.

  **Fix this first, it's a one-liner and it blocks the feature:**
  `findSubstitutions` keys `knownSubstitutions` on the raw lowercased name
  (`SubstitutionEngine.swift:139`) with no canonicalisation — so "butter" hits
  and "Unsalted Butter" silently returns nothing. Route the lookup through
  `IngredientNormalizer.canonicalize` and most real recipe text starts matching.
  Worth doing on its own merits even if the mindmap never ships.

  **Design questions to settle before building:** does picking a substitute
  mutate the recipe, create a `RecipeVariation` (the model already supports
  stacked variations), or just annotate the current cook? Does the chosen ratio
  rescale the amount via `MeasurementConversionService.scale`? And a radial
  layout needs a VoiceOver story — a disclosure list may serve better on iPhone
  with a radial treatment reserved for iPad.

---

*Last updated: 2026-11-16*
