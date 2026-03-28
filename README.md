# Recipes

A comprehensive iOS 26 app for foodies — powered by on-device AI, with cloud AI augmentation via OpenAI and Claude.

Built with SwiftUI, SwiftData, and Apple's FoundationModels framework. Designed to conform to Apple's Human Interface Guidelines.

## Features

### Recipe Management
- **Recipe as Code** — Define recipes declaratively with ingredients and desired outcomes. AI infers the cooking steps automatically.
- **Recipe Ingestion Pipeline** — Import recipes from URLs (with JSON-LD/schema.org extraction), plain text, markdown, photos, and Recipe-as-Code definitions.
- **Recipe Variations** — Stack multiple variations under a single recipe card (e.g., vegan version, gluten-free version).
- **Colour-Coded Ingredients** — 14 ingredient categories, each with a distinct colour for quick visual scanning.
- **Inline Timers** — Directions include built-in countdown timers and ingredient measurements directly in step text.
- **Safe Cooking Temperatures** — USDA-recommended temperatures for 30+ proteins at various doneness levels, shown inline in recipe steps.
- **Markdown Support** — Recipe source text preserved for reference.
- **Easy Sharing** — Export recipes as plain text without proprietary formats.

### AI Capabilities
- **Apple Intelligence (On-Device)** — Uses iOS 26 FoundationModels with `@Generable` structured output for recipe generation, nutritional estimation, ingredient substitution, step inference, and blind-spot detection. All processing stays on-device.
- **Claude (Anthropic)** — Cloud AI for recipe generation, image analysis (recipe photos, restaurant dishes), and recipe ingestion. Supports vision for extracting recipes from images.
- **OpenAI** — Cloud AI alternative with GPT-4o for recipe generation and image analysis.
- **Hybrid Mode** — On-device first with automatic cloud fallback. Configurable per user preference.
- **AI Service Router** — Intelligent routing based on task type, provider availability, and user settings.

### No Waste Cooking
- **Pantry-to-Recipe Matching** — Scores recipes against current pantry items with fuzzy ingredient matching and alias support.
- **Expiry Priority** — Surfaces recipes that use ingredients expiring soon.
- **Last Minute Recipes** — Filter by time constraint to find quick meals with available ingredients.
- **Coverage Indicators** — Shows what percentage of a recipe's ingredients you already have and what you still need.

### Pantry Management
- **Barcode Scanner** — Live camera preview with AVFoundation barcode detection (EAN-8, EAN-13, UPC-E, Code128, and more).
- **Open Food Facts Integration** — Automatic product lookup from scanned barcodes with category inference and nutritional data.
- **Expiration Tracking** — Visual alerts for expiring and expired items.
- **Recommended Staples** — Universal kitchen essentials and personalized suggestions based on recipe frequency analysis.
- **Seasonal Awareness** — 35+ ingredients with peak season data. Recipes scored by seasonality.

### Meal Planning
- **Weekly Meal Plans** — Assign recipes to breakfast, lunch, dinner, snacks across date ranges.
- **Budget Tracking** — Set weekly grocery budgets and calorie/protein targets.
- **Automated Recipe Selection** — AI-powered suggestions based on nutritional goals, budget, and available ingredients.

### Shopping Experience
- **Guided Voice Shopping** — Full audio-based shopping assistant using Speech framework. Reads items section by section, waits for voice confirmation.
- **Store Section Organization** — Items automatically categorized into 15 store sections (Produce, Meat, Dairy, etc.).
- **Real-Time Substitutions** — Can't find an item? Get instant substitution suggestions with recipe impact notes.
- **Progress Tracking** — Visual progress bar with estimated vs actual cost tracking.

### Recommendations
- **Blind-Spot Detection** — AI identifies cuisines and techniques you haven't explored yet.
- **Cook Again** — Resurfaces highly-rated recipes you haven't made recently.
- **Seasonal Picks** — Recommends recipes using currently in-season ingredients.
- **Quick Meals** — Fast recipes matching your pantry for busy days.
- **User Context** — Cooking history, ratings, and preferences inform all recommendations.

### Nutritional Tracking
- **Macro Nutrients** — Calories, protein, carbs, fat, fiber, sugar per serving.
- **Nutrition Facts Card** — FDA-style label with macro breakdown bar chart.
- **AI Estimation** — On-device nutritional estimation from ingredient lists.

### Restaurant Journal
- **Visit Logging** — Record restaurant visits with ratings, reviews, dishes ordered, and photos.
- **Want to Try List** — Save restaurants for future visits.
- **Price Range Tracking** — Budget to fine dining categorization.

### Cooking Metrics
- **Year in Review** — Total recipes cooked, time spent cooking/prepping/shopping.
- **Favourite Cuisines** — Bar chart of most-cooked cuisine types.
- **Most Used Ingredients** — Track your go-to ingredients.
- **Money Saved** — Estimated savings vs dining out.
- **Cooking Log** — Every cook is recorded with timestamps, ratings, and substitutions made.

### Grocery Budget
- **Receipt Scanning** — Capture receipt photos for spend tracking.
- **Estimated vs Actual** — Compare planned grocery costs with actual spend.

## Architecture

```
Recipes/
├── App/                          # App entry point and root navigation
├── Models/                       # SwiftData models
│   ├── Recipe.swift              # Core recipe model with variations
│   ├── Ingredient.swift          # Ingredients, pantry items, measurements
│   ├── MealPlan.swift            # Meal planning models
│   ├── NutritionalInfo.swift     # Nutrition data + @Generable estimation
│   ├── GroceryList.swift         # Shopping lists, items, receipts
│   ├── RestaurantJournal.swift   # Restaurant visits and want-to-try
│   ├── UserProfile.swift         # User preferences and stats
│   ├── RecipeAsCode.swift        # Declarative recipe definitions
│   └── CookingMetrics.swift      # Aggregated cooking statistics
├── Services/
│   ├── AI/                       # AI provider integrations
│   │   ├── FoundationModelService.swift  # Apple on-device AI
│   │   ├── ClaudeService.swift           # Anthropic Claude API
│   │   ├── OpenAIService.swift           # OpenAI API
│   │   ├── AIServiceRouter.swift         # Hybrid routing
│   │   └── KeychainService.swift         # Secure API key storage
│   └── Domain/                   # Business logic services
│       ├── NoWasteMatchingEngine.swift      # Pantry-to-recipe matching
│       ├── RecipeIngestionService.swift     # Multi-source import pipeline
│       ├── BarcodeScannerService.swift      # AVFoundation barcode scanning
│       ├── OpenFoodFactsService.swift       # Product database API
│       ├── RecommendationAgent.swift        # Personalized recommendations
│       ├── RecommendedStaplesService.swift  # Pantry staple suggestions
│       ├── SubstitutionEngine.swift         # Ingredient substitutions
│       ├── SeasonalAwarenessService.swift   # Seasonal produce data
│       ├── SafeCookingTemperatureService.swift  # USDA safe temps
│       ├── MeasurementConversion.swift      # Unit conversion
│       └── ShoppingVoiceService.swift       # Voice-guided shopping
└── Views/
    ├── Components/               # Reusable UI components
    ├── Recipes/                  # Recipe list, detail, editor, generator
    ├── Pantry/                   # Pantry management and barcode scanning
    ├── MealPlan/                 # Meal planning interface
    ├── Shopping/                 # Shopping lists and guided shopping
    ├── Journal/                  # Restaurant journal
    ├── Metrics/                  # Cooking statistics dashboard
    └── Settings/                 # API keys and preferences
```

## Requirements

- iOS 26.0+
- Xcode 26.0+
- Swift 6.0+
- Device with Apple Intelligence support (for on-device AI features)

## Setup

1. Clone the repository
2. Open `Recipes/` in Xcode 26
3. Create a new iOS App project targeting iOS 26 and add the source files
4. Build and run on a device or simulator

### API Keys (Optional)

Cloud AI features require API keys configured in Settings:

- **OpenAI**: Get a key at [platform.openai.com](https://platform.openai.com)
- **Claude**: Get a key at [console.anthropic.com](https://console.anthropic.com)

Keys are stored securely in the iOS Keychain — they never leave the device except to authenticate with the respective APIs.

On-device AI via Apple Intelligence works without any API keys.

## Privacy

- On-device AI processes all data locally
- API keys stored in iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- No analytics or tracking
- Recipe data stored locally via SwiftData
- Camera access used only for barcode scanning and recipe photo capture
- Microphone access used only for voice-guided shopping
- Open Food Facts API calls send only barcode numbers

## License

Private repository. All rights reserved.
