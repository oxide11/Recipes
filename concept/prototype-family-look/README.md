# Mark 2, family cookbook look (Nicole, 2026-11-20)

A copy of `../prototype-mk2` with look changes only; screens, flows and features are Moussa's Mark 2. Open `index.html` (best served: `python3 -m http.server 8765 --directory concept`, then http://localhost:8765/prototype-family-look/). Compare with `../prototype-mk2/` side by side. Rebuild with `python3 build.py`. Changes are in `src/app.js`, `src/pad.js` and the blocks at the end of `src/pad.css`.

Checked mainly on iPad landscape (the main device); iPhone is only partly updated. Light mode only for now: the dark mode switch is hidden until a proper dark version of this look exists.

## What changed in the look

**Colour and type**
- Background: warm off-white (#FCF9F4) with a soft gold light at the top, instead of cool white.
- Cards: near-white (#FFFEFB) with a soft shadow and fine warm edge, instead of grey outlines.
- Black UI became blueberry navy (#1E2747) for text, buttons and selected states.
- Titles stay Space Grotesk, body Inter (as in Mark 2).
- Status colours darkened so all text passes WCAG AA (4.5:1).

**Recipe cards (Home and library)**
- Ingredient colour stripes removed everywhere (the "fingerprint" bars).
- Text-first cards: name, time, one short taste line ("Creamy, smoky, a little heat") instead of the paragraph description.
- One status chip: green "Ready to cook", amber "Need 1–3", grey "Need 4+".
- "In season" tag in the produce's own colour, only where true.
- Who it's from: a coloured initial and name per family member (Ashley plum, Nicole teal, Moussa indigo), coral "✦ New from Mise" for generated recipes.

**Library**
- One grouped list instead of separate cards.
- Filter by person: Everyone · Ashley · Nicole · Moussa · New from Mise.
- More visible search field.

**Seasoning (replaces the stripes as the signature visual)**
- Cards age with how often a recipe is cooked, like an old recipe card: the paper warms, edges brown slightly, and small spatter, specks and faint water marks appear. Slow on purpose: 1–4 cooks barely shows; 40+ is a house favourite with a softly worn corner.
- The recipe page gets a lighter version of the same: faint warmth, marks kept in the margins.
- Ingredients, method and the chart always sit on clean white panels so they stay easy to read.
- Recipe page header line: "House favorite · cooked 50× by the family".

**Family on the recipe page**
- Versions: the original plus your own version only.
- Notes: the author's, yours, and ones someone chose to share. Everyone's personal tweaks stay private.

## Mock content (not real data)
Who each recipe is from (apart from Ashley's cards and Moussa's roast), cook counts, notes, versions and the taste lines are made up for the demo. Version chips don't switch the recipe yet.

## Tried and dropped
Ingredient drawings on cards (cartoony), dish illustrations, full-colour produce chips, a rainbow fruit gradient, a wood/oat palette, an all-dark version (`../prototype-dark/`), and big splash/smear stains.

## Keep from the current app
Nicole wants these from the current SwiftUI Recipes tab carried into Mark 2:
- **Recommended for you:** personalized suggestions from your cooking history.
- **In season:** this season's produce, with "Generate a seasonal recipe" so the chips lead somewhere.
- **Ready to cook:** recipes you can make now from your pantry (Mark 2 only shows "5 of 9 in pantry").

## Open for Nicole and Moussa
- Accessibility: turn wear off with Increase Contrast / Reduce Transparency, add a "Show recipe wear" setting, design a dark-mode version, keep cooking mode clean.
- Whether "New from Mise" should be quieter once there are many generated recipes.
- Recipe page order: lead with ingredients and method, move "Where it all goes" below them as a "What's in it" section, and lift its one-line insight ("Milk and flour are about 70% of the batter…") up near the description. Not changed in this prototype; a question for Moussa.
