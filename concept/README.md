# Bright Kitchen concept

UI concept work for the Recipes app: a bright, white interface where colour only ever means food.

## Contents

- `prototype/` — clickable HTML prototype. Open `prototype/index.html` in a browser.
  - Switch between iPhone and iPad (landscape or portrait) with the bar at the top.
  - Flow: pick a recipe, read it (icon Sankey by weight, volume, calories or cost), optionally plan the cook (constellation of ingredients, swap mind map, shopping list), cook with large crossed-off steps and docked timers, then plate and log.
  - Seeded with three of Ashley's recipe cards: Creamy Cajun Chicken Pasta, Thai Coconut Soup and Chicken Piccata. Amounts the card left unclear are marked with a "?" and explained.
  - Source is in `prototype/src/`. Rebuild `index.html` with `python3 build.py` from `prototype/`.
- `design/` — artboard sources from the design canvas (`*.dc.html` plus `canvas.json`): phone screens, the palette, the iPad recipe overview and the share sheet. These render inside the Claude design canvas; they are kept here for reference.

## Notes

- Nutrition, cost and timing figures are estimates for the prototype.
- Sharing, photos of the original cards and the non-cooking tabs are mocked.
- Fonts (Inter, Space Grotesk) load from Google Fonts.
