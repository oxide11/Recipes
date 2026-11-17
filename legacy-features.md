# Legacy Features

Features of the existing iOS app (SwiftUI, SwiftData, iOS 26), compiled from the Swift source on 2026-11-16. This is the baseline the new "Bright Kitchen" concept (see `concept/`) is being designed against. Compiled by reading the code and screen labels; the app was not built or run for this list.

## App shell
- Five tabs: Mise (dashboard), Cook, Pantry & Shop, Activity, Settings
- Onboarding: name, goals, cuisines, dietary restrictions, voice pantry setup, cuisine-based starter pantry
- Dark mode forced; iPad multi-column layouts
- "Temporary mode" banner if the data store cannot open
- Dashboard: quick actions, pantry health, today's meals, cooking activity and streak, weekly budget, seasonal spotlight, quick meals (iPad)

## Recipes
- Create and edit, with step ingredient chips linked to ingredient rows
- Import from URL (schema.org JSON-LD), in-app browser with saved sites, pasted text, photo
- AI recipe generator (typed or spoken request, meal type, cuisine, max time, dietary restrictions)
- AI Edit: quick edits or a described change, with a preview before applying
- Variations under one recipe, servings scaling, unit conversion
- Tags and tag management, favourites, search, filters by cuisine, meal type and dietary restriction
- Recipe photos; ingredient lookup with substitutes
- Export as PDF, card image or plain text

## Cooking
- Step-by-step cooking mode with per-step ingredients and timers
- Hands-free: voice readback, auto-advance when a timer ends, screen stays awake, Switch Control support
- Timers as Live Activities with deep links back to the step
- Safe cooking temperatures and rest times
- Multi-recipe cooking plan that interleaves steps (AI, with a non-AI fallback)
- Cooking log: rating, notes, photos, substitutions; quick log sheet

## Pantry
- Barcode scan with Open Food Facts lookup
- Add by photo (bulk), by voice, or manually
- Expiry tracking and "do you still have these?" checks
- "What can I make?" matching with coverage percent and expiry priority (No Waste)
- Recommended staples; seasonal flags
- Auto-deduct quantities after a cook

## Meal planning
- Weekly plan by breakfast, lunch and dinner
- AI plan generation honouring allergens, dislikes, max cook time and pantry priority
- Meal prep mode (daily or weekly) with grouped prep tasks
- "Today's Meals" home screen widget

## Shopping
- List generated from the meal plan, merged and minus pantry stock, grouped by store section
- Voice-guided shopping, section by section, with substitutions
- Two-way sync with Apple Reminders
- Receipt scan (OCR), fuzzy or AI matching to the list, actual vs estimated cost
- Purchased items flow into the pantry

## Activity and tracking
- Metrics: cooks, time spent, favourite cuisines, most used ingredients, money saved, streaks
- Nutrition tracking with daily calorie and protein goals
- Nutrition facts card with AI estimation
- Recommendations: blind spots, cook again, seasonal picks, quick meals
- Restaurant journal: visits, ratings, dishes, want-to-try list, map, share

## AI and settings
- On-device Apple Intelligence, Claude and OpenAI, with hybrid routing and an on-device-only mode
- API keys stored in the Keychain; currency; measurement system
- Smart notifications: pantry expiry, meal reminders, streaks, weekly planning, season change
- iCloud sync and sharing toggles are present but marked "coming soon"

## Notes
- The app already has daily calorie and protein goals in nutrition tracking, which overlaps with the "Nutritional goals" item in `backlog.md`.
