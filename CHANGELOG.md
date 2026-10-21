# Changelog

## Unreleased

### Added
- Pantry items have editable quantities and units in every manual add/edit form
- Auto-Deduct Pantry now works: logging a cook reduces pantry quantities (scaled to servings cooked, with unit conversion) and offers to remove items that ran out
- Shopping list has a "Scan a Receipt" entry; matched receipt lines record actual prices, move items to the pantry and close their Reminders entries
- Profile allergens, disliked ingredients and max cook time are enforced in recipe generation and meal plan prompts

### Fixed
- Seasonal badges, filters and picks follow the profile's hemisphere; plural and qualified ingredient names match the seasonal table
- Recommendation cards for saved recipes open the recipe instead of the AI generator
- Onboarding "Skip pantry setup" no longer seeds the pantry; typed or spoken ingredients outside the starter kit are kept
- Settings: removed disabled "(todo)" iCloud toggles, Developer/Debug tools are DEBUG-only, Measurements picker persists and is applied to ingredient rows and step chips
- Currency from the profile replaces hard-coded "$"/"CAD" in Metrics, Bulk Photo Add and receipt matching
- Reminders deleted in the Reminders app are no longer recreated on sync; guided shopping, substitutions and receipt matches push completion so sync doesn't revert them
- On-device AI session is recycled before its transcript overflows and retried once on context-window errors; the parsing schema no longer drops ingredients past the tenth
- Hybrid AI mode falls back to the cloud when the on-device model answers in prose for a JSON task
- Recipe import tolerates ranges, "30 min" times, numeric amounts and other schema drift from AI output, and reports the decode reason on failure
- URL imports without structured data send up to 6,000 characters of page text instead of 2,000
- Tag filter/delete match case-insensitively; removing a dish photo in the journal waits for Save
- Removed a duplicate `AIRecipeEditView` declaration under Views/Components that broke the build after the XcodeGen migration
- Widget extension now keeps its `NSExtensionPointIdentifier` Info.plist entry so WidgetKit recognises it
- Introduced `RecipesSchemaV1` and `RecipesMigrationPlan`; future model changes migrate instead of falling back to an in-memory store
- Notification defaults are registered at launch, so expiry, streak, weekly planning and season alerts actually schedule on a fresh install
- Notification triggers that would have landed in the past now roll to the next 9 am / 6 pm slot; streak reminder no longer prints an absurd day count when nothing has been cooked
- Turning a notification type off cancels its already-scheduled requests; alerts for deleted pantry items are cleaned up
- AI provider choice is persisted across launches
- "On-Device Only" now refuses photo analysis with a clear message instead of silently sending images to a cloud provider, and streaming no longer falls back to the cloud in that mode
- Allergens, disliked ingredients and max cook time from the profile are now included as hard constraints in recipe generation and meal plan prompts
- Recipe editor: step ingredient chips now reference the ingredient row by ID, so renaming or re-measuring an ingredient updates every step that uses it and the saved directions always match the ingredient list
- Recipe editor: the unit-conversion popover is owned per step row instead of being attached to the Form section (which presented it on every row at once)
- Meal plan generation now shows a progress indicator after the sheet dismisses and an alert with "Try Again" if the AI call fails or no meals could be added, instead of failing silently
- Fixed a crash in meal plan generation when two recipes shared a title in different letter case
- Meal cards now refresh their missing/substitutable ingredient lists when a pantry item is renamed, not only when the item count changes
- Metrics recompute correctly when one record is added and another removed in the same session
- Network timeouts are now real total-duration caps via shared `NetworkSession` configurations; the previous `URLRequest.timeoutInterval = 60` matched the system default and only bounded idle time
- When the persistent store can't be opened and the app falls back to an in-memory store, a persistent "Temporary mode" banner and an explanatory alert tell the user that changes won't be saved
- Guided shopping stops voice guidance and speech recognition when the sheet is swiped away without tapping Done
- Dashboard library-pick ranking uses shuffle-then-stable-sort instead of a random tie-break comparator
- Starter recipe generation failures during onboarding are logged instead of dropped
- Fixed main actor-isolated property warning in `RecipeGeneratorView` where `selectedImage` was referenced from a Sendable closure (line 182)
- Fixed identical main actor-isolated property warning in `BulkPhotoAddView` (line 46)
- Added missing `IngredientNormalizer.swift` to Xcode project (file existed on disk but wasn't in project navigator)
- Added missing `APIClient.swift` to Xcode project (same issue)
- Added missing `DashboardView.swift` to Xcode project with `Views/Dashboard` group
- Added missing `StarRatingView.swift` to Xcode project
- Added missing `FormatTime.swift` to Xcode project
- Fixed `Cannot infer contextual base in reference to member 'whitespaces'` in `NoWasteMatchingEngine` by using explicit `CharacterSet.whitespaces`
- Fixed `Sending 'body' risks causing data races` in `ClaudeService` and `OpenAIService` by serializing `[String: Any]` body to `Data` before the async boundary in `APIClient`
- Fixed trailing closure warning in `ShoppingVoiceService.speak()` by extracting `AsyncStream` into a local variable
- Removed deprecated `.previewDevice()` modifier from `DashboardView` `#Preview` macro
- Fixed `NSRange` crash on emoji/multibyte strings in `RecipeIngestionService.stripHTML` by using `NSRange(startIndex..., in:)` instead of `NSRange(location:length:)`
- Fixed `CheckedContinuation` double-resume crash in `ShoppingVoiceService.listenForConfirmation` with `hasResumed` guard
- Fixed unsafe `MainActor.assumeIsolated` in `AVSpeechSynthesizerDelegate` callback — replaced with `Task { @MainActor in }`
- Replaced polling loop in `ShoppingVoiceService.speak()` with `AsyncStream`-based waiting
- Removed "done" keyword from `positiveWords` that shadowed `doneWords` in voice shopping
- Fixed force unwrap on `RecommendationAgent.cookAgainRecommendations` with nil-coalescing
- Removed dead `where true` clause in `MeasurementConversion`
- Fixed URL injection risk in `OpenFoodFactsService` by percent-encoding barcode input
- Fixed 4 force unwraps on `Calendar.date(...)` in `MealPlanView` (ensurePlan, weekStart, weekDays)
- Fixed force unwrap in widget timeline provider with fallback `addingTimeInterval(3600)`
- Fixed silent error swallowing in `RecipeDetailView.estimateNutrition()` — now shows user-facing error state
- Fixed force cast `as!` in `BarcodeScannerService.CameraPreviewUIView` — replaced with safe `as?` guard

### Changed
- Rewrote `DashboardView` with data-driven, actionable content replacing static/mock placeholders:
  - **Quick Actions row** — scan receipt, generate recipe, add pantry, quick meal shortcuts
  - **Pantry Health card** — live expired/expiring-soon counts with item names, replaces static "all fresh" text
  - **Today's Meals** — shows real planned meals sorted by type with completion status, duration, and empty-state guidance instead of mock data
  - **Cooking Activity card** — this-week cook count, streak tracker, total recipes, favorites count, last-cooked recipe with star rating
  - **Weekly Budget** — progress bar against user's `weeklyGroceryBudget` with color-coded thresholds, replaces fake donut chart
  - **Seasonal Spotlight** — flow-layout tags from `SeasonalAwarenessService.currentlyInSeason()` for non-year-round ingredients
  - **Quick Meals card** (iPad) — ≤30 min recipes sorted by cook count with ratings
- Removed redundant custom tab bar (`DashboardTab` enum + `customTabBar`) that duplicated the system `TabView` in `ContentView`
- Replaced mock `BudgetCardView` / `MealCardView` subviews with inline data-driven sections
- Greeting header now shows user's display name from `UserProfile`
- Date string uses `Date.formatted()` instead of manually created `DateFormatter`

### Improved
- Optimized O(n²) pantry matching in `NoWasteMatchingEngine` with word-level O(1) lookup before substring fallback, capped at 200 entries
- Cached `LanguageModelSession` in `FoundationModelService` to avoid per-call recreation
- Added `syncTotalTime()` to `Recipe` to keep stored `totalTimeMinutes` in sync with prep+cook
- Cached `DateFormatter` in `RecipeExportService` as static instance instead of per-call allocation
- Cached `DateFormatter` pair in `PantryView` as static instances instead of per-call allocation
- Added O(1) dictionary lookup in `SeasonalAwarenessService.isInSeason` replacing linear scan
- Cached expensive `matches` computation in `NoWasteResultsView` via `@State` + `.task` instead of recomputing on every render
- Cached `MetricsView.metrics` and `NutritionTrackingView.trackedDays/totals` via `@State` + `.task`

### Removed
- Deleted non-functional `inferStepsViaCloud` from `RecipeIngestionService` — always returned nil

### Added
- New `DashboardView` ("Mise" tab) — obsidian-themed home screen with serif headers, AI insight card with glow border, today's meals, weekly budget donut chart, and custom tab bar
- iPad-optimized multi-column layout — DashboardView uses `horizontalSizeClass` to show side-by-side meals + budget columns on iPad, single column on iPhone
- Quick Stats card on iPad — shows recipe count, pantry items, and today's meals at a glance
- App now forces dark mode via `preferredColorScheme(.dark)` at the app level
- "Mise" tab added to ContentView as the default landing tab with `sparkles` icon
- Extracted reusable `StarRatingView` component — replaces 8 duplicated star rating patterns across 5 files
- Extracted `.glassCard(cornerRadius:)` view modifier — replaces 20+ duplicated `.background(in:) + .glassEffect()` pairs
- Extracted shared `formatTime(_:)` utility — replaces 3 identical implementations across DirectionStepView, CookingModeView, and RecipesWidgets
- Extracted `IngredientNormalizer` utility — unifies ingredient name normalization and category inference previously duplicated in RecipeIngestionService, OpenFoodFactsService, and NoWasteMatchingEngine
- Extracted `APIClient` shared networking layer — deduplicates HTTP request/response handling between ClaudeService and OpenAIService
- Fixed `RecipeExportService` double generation — share sheet now reuses preview data instead of regenerating
