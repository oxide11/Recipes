# Changelog

## Unreleased

### Fixed
- Fixed main actor-isolated property warning in `RecipeGeneratorView` where `selectedImage` was referenced from a Sendable closure (line 182)
- Fixed identical main actor-isolated property warning in `BulkPhotoAddView` (line 46)
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

### Improved
- Optimized O(n²) pantry matching in `NoWasteMatchingEngine` with word-level O(1) lookup before substring fallback, capped at 200 entries
- Cached `LanguageModelSession` in `FoundationModelService` to avoid per-call recreation
- Added `syncTotalTime()` to `Recipe` to keep stored `totalTimeMinutes` in sync with prep+cook
- Cached `DateFormatter` in `RecipeExportService` as static instance instead of per-call allocation
- Cached `DateFormatter` pair in `PantryView` as static instances instead of per-call allocation
- Added O(1) dictionary lookup in `SeasonalAwarenessService.isInSeason` replacing linear scan
- Cached expensive `matches` computation in `NoWasteResultsView` via `@State` + `.task` instead of recomputing on every render
- Cached `MetricsView.metrics` and `NutritionTrackingView.trackedDays/totals` via `@State` + `.task`

### Added
- Extracted reusable `StarRatingView` component — replaces 8 duplicated star rating patterns across 5 files
- Extracted `.glassCard(cornerRadius:)` view modifier — replaces 20+ duplicated `.background(in:) + .glassEffect()` pairs
- Extracted shared `formatTime(_:)` utility — replaces 3 identical implementations across DirectionStepView, CookingModeView, and RecipesWidgets
