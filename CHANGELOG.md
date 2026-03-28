# Changelog

All notable changes to the Recipes app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added - High-Value Features & AI Polish (2026-03-28)

#### Recipe Ingestion Pipeline
- Full multi-source recipe import: URL, plain text, photos, and Recipe-as-Code
- JSON-LD/schema.org structured data extraction from recipe websites
- HTML stripping with script/style/nav block removal
- ISO 8601 duration parsing for prep/cook times
- Intelligent ingredient amount parsing with fraction support (1/2, unicode fractions)
- Automatic ingredient category inference from names
- `RecipeIngestionResult` to `Recipe` model conversion with full SwiftData integration
- Unified `RecipeImportView` with tabbed source selection and live preview

#### Barcode Scanner & Open Food Facts
- Live camera preview using `CameraPreviewView` (UIViewRepresentable wrapping AVCaptureVideoPreviewLayer)
- Automatic product lookup via Open Food Facts API on barcode scan
- Product category inference from Open Food Facts category tags
- Nutritional data extraction (calories, macros per 100g)
- Manual entry fallback when product not found in database
- Scan-another flow for batch pantry additions
- Full `BarcodeScannerFullView` with scan overlay, result form, and pantry insertion

#### No Waste Recipe Matching Engine
- `NoWasteMatchingEngine` scores recipes against pantry items
- Fuzzy ingredient matching with singular/plural normalization
- 30+ ingredient alias mappings (e.g., "chicken breast" matches "chicken")
- Word-level partial matching for compound ingredient names
- Scoring algorithm weighing: ingredient coverage, expiring item bonus, freshness penalty, missing ingredient penalty, time bonus, seasonal bonus
- `recipesForExpiringItems()` — prioritizes recipes using soon-to-expire ingredients
- `lastMinuteRecipes()` — filters by time constraint
- `NoWasteResultsView` with time filter, full-coverage toggle, and coverage badges
- "Ready to Cook" section on recipe list showing top pantry matches
- "What Can I Make?" navigation from pantry view

#### Guided Shopping Voice Experience
- `GuidedShoppingView` — full-screen shopping interface with voice interaction
- Live progress header with section indicator and item counts
- Large current-item card with Found/Substitute/Skip actions
- Section-by-section item list with purchase state
- Voice status bar showing speaking/listening state with last-heard text
- `SubstitutionSheetView` for in-context ingredient substitution during shopping
- Substitution immediately updates the shopping list item
- Start with voice or shop silently with tap controls

#### Recipe-as-Code End-to-End
- `RecipeAsCodePreviewView` — full editor, parser, AI inference, and save flow
- Live parse preview showing extracted title, servings, cuisine, ingredients, outcomes, equipment
- One-tap AI step inference using Apple FoundationModels (on-device)
- Cloud fallback for step inference when on-device AI unavailable
- Generated steps displayed with step numbers, durations, and ingredient references
- Save button converts parsed definition + inferred steps into a full Recipe model
- Sample recipe code pre-loaded for new users
- Integrated into recipe list via "Recipe as Code" menu option

#### Blind-Spot Recommender & Recommendation Agent
- `RecommendationAgent` — personalized recommendation engine
- 6 recommendation categories: Cook Again, Blind Spot, Seasonal, No Waste, Quick Meal, New Recipe
- "Cook Again" resurfaces highly-rated recipes not made in 30+ days
- "Blind Spot" identifies unexplored cuisines from full Cuisine enum
- AI-powered blind-spot detection via `FoundationModelService.suggestBlindSpots()`
- AI suggests unexplored cuisines, new techniques, and specific recipe ideas
- User context builder summarizes cooking history for AI prompts
- `RecommendationsView` with category-grouped cards and pull-to-refresh
- Integrated "Recommended For You" teaser on recipe list

#### Recommended Pantry Staples
- `RecommendedStaplesService` with 28 universal kitchen staples across 8 categories
- Three frequency tiers: Essential, Common, Nice to Have
- `personalizedStaples()` — analyzes user's recipe collection to find frequently-used but unstocked ingredients
- `missingStaples()` — compares universal staples against current pantry
- `RecommendedStaplesView` with Essential/For You tabs and one-tap add to pantry
- Integrated into pantry view with missing count indicator

#### Tests
- No Waste matching engine tests (empty pantry, time filter)
- Recommended staples tests (universal list populated, empty pantry, essential items)
- Recipe-as-Code parser extended tests (equipment, default amounts, comment handling)
- Open Food Facts service type validation tests

---

## [0.1.0] - 2026-03-28

### Added - Foundation Setup

#### Project Structure
- Complete iOS 26 project architecture with SwiftUI, SwiftData, and FoundationModels
- 7-tab navigation: Recipes, Pantry, Meal Plan, Shopping, Journal, Metrics, Settings

#### Models
- `Recipe` with variations, cooking log, safe temperatures, photos, auto-favorite logic
- `Ingredient` with 14 colour-coded categories and seasonal availability
- `PantryItem` with expiration tracking and barcode support
- `MealPlan` and `PlannedMeal` with budget/calorie/protein targets
- `GroceryList`, `GroceryItem`, `GroceryReceipt` with store section organization
- `RestaurantJournalEntry` and `RestaurantWantToTry`
- `UserProfile` with dietary restrictions, preferences, and AI provider selection
- `NutritionalInfo` with macro percentage calculations
- `RecipeDefinition` and `RecipeDefinitionParser` for Recipe-as-Code
- `CookingMetrics` with year-in-review aggregation

#### AI Services
- `FoundationModelService` — Apple on-device AI with `@Generable` structured output
- `ClaudeService` — Anthropic Messages API with vision support
- `OpenAIService` — GPT-4o API with vision support
- `AIServiceRouter` — Hybrid routing (on-device first, cloud fallback)
- `KeychainService` — Secure API key storage

#### Domain Services
- `MeasurementConversionService` — Imperial/metric conversion and recipe scaling
- `BarcodeScannerService` — AVFoundation barcode detection
- `SubstitutionEngine` — Rule-based ingredient substitutions for 7 common ingredients
- `SeasonalAwarenessService` — 35+ seasonal ingredients with scoring
- `SafeCookingTemperatureService` — USDA temperatures for 30+ proteins
- `ShoppingVoiceService` — Speech synthesis and recognition for guided shopping
- `RecipeIngestionService` — Basic multi-source recipe import

#### Views
- Recipe list with seasonal section, favourites, search, and cuisine filter
- Recipe detail with inline timers, colour-coded ingredients, safe temp badges, serving adjuster
- Nutrition facts card with macro breakdown bar
- AI recipe generator with cuisine/time/dietary filters
- Pantry management with category grouping and expiration alerts
- Meal plan with calendar date picker
- Shopping list with store section grouping
- Restaurant journal with visit log and want-to-try list
- Cooking metrics dashboard with Charts
- Settings with secure API key management and Apple Intelligence status

#### Tests
- Measurement conversion (cups/ml, F/C, oz/g, scaling)
- Substitution engine (lookup, dietary filtering)
- Seasonal awareness (current season, year-round, scoring)
- Safe cooking temperatures (chicken, beef steak)
- Recipe-as-Code parser (basic parsing)
- Nutritional info (macro percentages, zero-calorie edge case)
