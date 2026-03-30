# Changelog

## Unreleased

### Fixed
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
