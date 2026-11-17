# Build brief: Recipes rewrite ("Mark 2")

Written 2026-11-17. This is the first document to read before writing any code. It is meant for Claude Code running on a Mac with Xcode.

## 1. What we are building

A new recipe and cooking app for iPhone, iPad and Mac, written from scratch. It replaces the existing iOS app in this repository (see `legacy-features.md` for what that app does).

The design is fixed by the Mark 2 prototype:

- Prototype source: `concept/prototype-mk2/` (open `index.html`; `README.md` lists what is real and what is mocked).
- It is an HTML prototype. Treat it as the specification for screens, flows and behaviour, not as code to port.

Design principles that must survive the build:

1. A bright, clean kitchen. Interface and text are black, white and grey only.
2. Colour means food. Ingredient colours are used only for ingredient data.
3. Signal colours are a separate small palette that no ingredient uses (blue = better, magenta = worse, urgent or saved, teal = calm).
4. Estimates are shown as estimates (rounded, marked "~").
5. Things you tap and things you read look different.
6. Full screen for anything with its own navigation; sheet for a single answer.

## 2. Decisions already made

| Decision | Choice |
| --- | --- |
| Rewrite or evolve | Rewrite: new project, new data model, new UI. Carry over proven service code from the legacy app selectively. |
| Platforms | One native SwiftUI multiplatform app: iPhone, iPad, Mac (not Catalyst). iOS 26, iPadOS 26, macOS 26. |
| Repository | New repository. The old repository stays as a reference to copy services from. |
| Sharing | Required in version 1. See section 4. |
| Sync technology | CloudKit shared record zones, driven by our own sync layer on `CKSyncEngine`. Not SwiftData's built-in CloudKit sync, which has no sharing support. |
| Local store | To be chosen in phase 0 (SwiftData as a local cache with no CloudKit option, or GRDB). The sync layer owns CloudKit either way. |

## 3. Screens (from the prototype)

- Home: tonight's pick, use-it-up, cook with what you have, recipe cards.
- Recipes (library): search, show filter, sort, tag filter, saved, "still on paper".
- Recipe: description, tags, actions, stats, Sankey ("Where it all goes") with weight / volume / cost / calories, ingredients, method, card source, time at the stove, your cooks.
- Swap (full screen): mind map per ingredient, on-hand tags, never-suggested list, nutrition change against the user's goal.
- Shopping list for one recipe; weekly shopping list for a kitchen.
- Cooking mode: large step text with colour-coded ingredients, tap-to-convert units, pencil strike-outs, timer dock, safe temperature badges, hands-free.
- Plated: photo, rating, note, save to cooking log.
- Your cooks: history, times, swaps made, promote a swap to default.
- Pantry: inventory by aisle, use first, spice rack, item detail (amount by weight, volume or count; bought date; use-by; enough for).
- Plan: week, several recipes per day, prep days, prep session (merged timeline, "get out once").
- Cook together: merged timeline for two recipes.
- Questions for Ashley; card import.
- Settings: never suggested, appearance (dark mode), measurements, nutrition goal, cooking preferences, sharing.

## 4. Sharing model (critical)

Three independent spaces. Membership of one never implies membership of another.

1. **Library**: recipes, recipe cards, card questions, cooking notes. Shared by a whole family. One CloudKit zone, one share.
2. **Kitchen**: meal plan, shopping list, pantry stock, spice rack. Shared by the people who plan and shop together. One zone and one share per kitchen. A family can have many kitchens (for example three sibling couples, each with a private kitchen), and a person can belong to several (a couple's kitchen and a "cottage weekend" kitchen). A person chooses who is in each of their kitchens.
3. **Personal**: allergies and dislikes, nutrition goal, units, appearance, saved recipes. Private database, never shared.

Rules:

- A kitchen refers to library recipes by identifier. It owns nothing in the library.
- People who are in the library but not in a kitchen cannot see that kitchen, and are not told it exists.
- Plan entries and shopping items record who added or ticked them.
- Model changes as small records (one per plan entry, one per shopping item, one per pantry item) so that two people editing different things never overwrite each other. Decide a conflict rule per record type (last writer wins is acceptable for a tick; pantry amounts need a merge rule).

**Near-realtime is a requirement, and it is the main technical risk.** CloudKit sync is push-driven with no guaranteed delay. Phase 0 must measure it (see section 7). If two people ticking one shopping list in a store is not fast enough on CloudKit, only the shopping list moves to a small realtime service; everything else stays on CloudKit.

## 5. Data model (starting point)

Library zone:
- `Recipe`: title, description, meal type, tags, base servings, source card (photos, credit), versions.
- `Ingredient` (per recipe): name, amount text, weight (g), volume (ml), cost, calories and macros, colour, graphic key, aisle, group, safe-temperature class.
- `Step`: title, lines with ingredient references, timer seconds, hands-on minutes, timer label, card note, safe-temperature protein.
- `SwapSet` and `SwapOption` (per ingredient): branch, ratio, note, traits, nutrition, allergen or dislike tags.
- `CardQuestion`: text, answered flag.
- `CookLog`: who, date, minutes, rating, swaps made, note, photo.

Kitchen zone:
- `Kitchen`: name.
- `PlanEntry`: date, recipe identifier, servings, added by.
- `ShoppingItem`: ingredient key, amounts and source recipes, ticked, ticked by.
- `PantryItem`: ingredient key, amount held in a canonical unit (grams, with density for volume and piece weight for count), preferred display unit, bought date, use-by.
- `SpiceJar`: name, level, bought date.

Personal (private database):
- `Profile`: never-suggested list, nutrition goal, units, appearance, cooking preferences, saved recipes, current kitchen.

Open questions for the data model:
- Sensible pantry units per ingredient (the prototype derives them from recipe amounts, which reads oddly for some items).
- Pack sizes for items with no natural count.
- Where nutrition and cost data come from. They are estimates in the prototype.

## 6. Architecture

- Swift packages:
  - `RecipesCore`: models, sync layer, unit conversion, scaling, pantry matching, substitutions, plan merging. No UI. Builds and tests on macOS without a simulator.
  - `DesignSystem`: colours (ingredient, signal, neutral, dark variants), type, components, ingredient graphics.
  - `Features`: one module per screen group.
- App target: navigation shell per idiom. iPhone: tab bar. iPad: sidebar. Mac: sidebar, toolbar, menus, keyboard shortcuts, cooking mode in its own window.
- Custom drawing in SwiftUI `Canvas`, shared across platforms: Sankey, swap map, circular timers, pencil strike-outs.
- Platform-only features behind small protocols: camera, barcode, Live Activities (iPhone and iPad); menu bar timer and drag-in photos (Mac).

Carry over from the legacy app, adapting to the new model as each screen needs it:
- Recipe import (URL, text, photo), pantry matching, substitution engine, unit conversion and servings scaling, AI routing, safe cooking temperatures.

Leave behind for now (keep in the old repository): restaurant journal, receipt scanning, AI recipe generator, voice-guided shopping.

## 7. Build order

**Phase 0: foundations and the sync test**
- New repository, multiplatform target, packages, CI running `RecipesCore` tests.
- Sync spike: two iCloud accounts, one shared kitchen zone with a shopping list. Measure tick-to-appear delay on real devices, foreground and background. Write the result down and decide CloudKit-only or CloudKit plus a realtime service for shopping.
- Choose the local store.
- Exit: the measured delay, the store decision, and a library share and a kitchen share accepted between two accounts.

**Phase 1: recipe view**
- Design system, ingredient graphics, seed data (the nine recipes in the prototype).
- Recipe screen with the Sankey on iPhone, iPad and Mac. Light and dark.

**Phase 2: cooking mode**
- Step text, unit converter, timers, strike-outs, safe temperatures, hands-free, Live Activity, plated and cooking log.

**Phase 3: swaps, pantry, shopping, plan**
- Swap map, pantry inventory and spice rack, weekly shopping list, plan with prep days. All on the shared kitchen model.

**Phase 4: library and history**
- Library screen, card import, questions queue, your cooks, personal cook times, cook together.

**Phase 5: ship**
- Accessibility pass (contrast, colour-blind, Dynamic Type, VoiceOver), widgets, Mac polish, TestFlight with the family.

Each phase ends with something usable on all three platforms.

## 8. Things to verify, not assume

- CloudKit sync delay for the shopping list (phase 0).
- CloudKit sharing behaviour on current OS releases. Sharing had regressions in early iOS 26 betas; test invitation, acceptance and removal on shipping builds.
- Whether anyone has real data in the legacy app. If so, write a one-time importer.
- Ingredient graphics: the set in the prototype is a style brief. Decide whether to commission a final set.
- Nutrition and cost: choose a data source or keep them labelled as estimates.

## 9. Working agreement

- Design changes happen in the prototype first, then in this brief, then in code.
- Do not port prototype JavaScript. Re-implement behaviour natively.
- Keep this brief current. When a decision in section 2 or 4 changes, change it here in the same commit.

## Recipe ingestion pipeline

One canonical recipe format, many source adapters. A language model reads and links; lookup tables supply every number. Nothing the Sankey draws comes straight from a model.

| Stage | What it does | How |
|---|---|---|
| 1. Capture | Turn any source into plain text plus the original | Photo: Vision text recognition. Website: schema.org Recipe data if the page has it, else the readable page text. Video link: caption or description. Paste, file, typed: the text itself |
| 2. Extract | Text to a `RecipeDraft`: title, servings, ingredient lines (quantity, unit, name, prep note), steps (text, duration, temperature) | Language model with a fixed output schema. Anything unclear becomes a question, never a guess |
| 3. Resolve | Match each ingredient line to the ingredient catalogue and convert its amount to grams and millilitres | Deterministic code: alias table, unit conversion, density and per-item weights from the catalogue |
| 4. Link | Tie steps to ingredients (which step uses how much of what), group ingredients into components (the Sankey's middle column), set timers | Model proposes, a validator checks: every ingredient used, split amounts add up to the total |
| 5. Review | User confirms, answers questions, fixes matches | Corrections are saved as new aliases so the same fix is never needed twice |

### The ingredient catalogue

The part that makes the Sankey, nutrition, cost, pantry, shopping aisles and swaps work. One record per ingredient: names and aliases, density, weight per countable unit (1 egg, 1 clove), nutrition per 100 g, aisle, colour and graphic, allergen tags, swap set. Ship a few hundred common ingredients; an unknown ingredient still imports, drawn in neutral grey with a generic graphic and flagged as an estimate.

### What is stored

- The original source (photo, link, text), always kept.
- The structured recipe: ingredients with catalogue id, original text, quantity, unit, grams, millilitres, component; steps with text, timers and ingredient references with amounts.
- Derived at display time, not stored: the four Sankey views (weight, volume, cost, calories), scaling, unit conversion, nutrition totals.

### To verify first

- Run the 41 real cards through stages 1 to 4 as a fixed test set. Measure how many ingredient lines resolve without a question.
- Whether the on-device model is good enough for stages 2 and 4 on handwriting, or needs the cloud fallback (the "Recipe help" setting).
