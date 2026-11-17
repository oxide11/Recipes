# Recipes prototype, Mark 2

A clone of `../prototype` with the design changes and new features from the 2026-11-16 review applied. The original prototype is unchanged.

Build: `python3 build.py` (assembles `index.html` from `src/`). Mark 2 code lives mostly in `src/mark2.js` and the "MARK 2" block at the end of `src/pad.css`.

## Design changes
1. Signal colours have their own palette (blue = better, magenta = worse/urgent/saved, teal = calm). No ingredient uses them. Applies to the saved heart, swap nutrition changes, expiry and the timers.
2. iPhone Sankey: flows have a minimum width and ingredients under 2.5% are bundled into one "small amounts" strand that opens a list.
3. Pills you tap are outlined and round; labels you only read are flat and square.
4. Rule: full screen for anything with its own navigation, sheet for a single answer. The existing screens already follow it.
5. Estimates are rounded and marked with "~".
6. iPad: servings moved from the action line to the Ingredients heading.
7. Optional stronger ingredient highlights (Settings).

## New features
1. Swaps know the pantry: "On hand" tags in the swap map; using one takes the item off the shopping list.
2. Hands-free cooking: reads steps aloud (browser speech), moves on when a step's timer ends, lock screen preview.
3. Cook together: a merged timeline for two recipes (plan only).
4. "For you" time: your average from the cooking log, or a prediction from your pace.
5. Use it up: expiring pantry items on the home screen and in the pantry, with a recipe that uses them.
6. Promote a swap you keep making to the recipe default.
7. Questions for Ashley queue and a card import explainer.
8. Receipt prices in the Sankey's cost view.
9. Nutrition goal (lighter, protein, gain) decides what counts as a better swap.

## Sample or mocked data
On-hand swaps, expiry dates, receipt prices, sending questions, the camera, promoting a swap (state only) and voice commands are sample data or stand-ins.

## Added after the first review
- Dark mode switch, calmer library controls, pantry inventory (amounts by weight, volume or count; bought date; use-by), spice rack, plan with prep days and prep sessions, redrawn ingredient graphics, larger swap map.
- Sharing model: one family library for recipes, and separate kitchens (plan, shopping list, pantry) with their own members. See `../BUILD_BRIEF.md`, section 4. In the prototype the people, kitchens and the "Ashley just ticked" update are simulated.
