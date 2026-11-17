# Ingredient database

A cleaned, structured food and ingredient dataset built from open government data, for the Recipes app:
the Sankey, nutrition, unit conversion, shopping aisles, allergen flags and pantry shelf life all read from it.

## What is in it

| File | Records | What |
|---|---|---|
| `out/foods.jsonl` | 10,480 | Every food from both sources, cleaned. Nutrition per 100 g (27 values), household measures with gram weights (US and metric), density, weight per item, state (raw, cooked, canned, frozen, dried), aisle, allergen and diet tags, French description |
| `out/ingredients.json` | 1,454 | Cooking ingredients. One record per ingredient, with a default food, its other forms, aliases and shelf life |
| `out/ingredients.csv` | 1,454 | The same, flat, to open in a spreadsheet |
| `out/stats.json` | | Counts and coverage from the last build |

Coverage in this build:

- 8,789 foods from USDA SR28, 378 from USDA Foundation Foods, and 1,313 that exist only in the Canadian file (ids `usda:…`, `fdc:…`, `cnf:…`).
- 182 SR28 foods point to newer lab data for the same food in Foundation Foods (`newer_lab_data`).
- Foods by kind: 6,374 ingredients, 1,525 branded, 1,521 prepared dishes, 434 baby foods, 165 regional, 83 institutional. Only "ingredient" foods feed the ingredient list.
- 31,333 household measures, 15,895 of them metric measures from the Canadian file (125 ml, 15 ml). 5,108 foods have a density; 5,720 have a weight per item (1 egg, 1 clove, 1 medium onion).
- French descriptions for 5,825 foods (58%), joined by the USDA code the Canadian file carries, not by guessing from names.
- 1,026 foods carry Canadian cooking-yield figures (`yields`), kept as published and not yet interpreted.
- Ingredients: 88 curated by hand (87 with data, 1 known gap), 1,329 built automatically. 986 have a density, 781 a weight per item, 322 a shelf life.

## Two tiers of trust

1. **Curated** (`curated: true`, from `overlay/curated.csv`). Named the way people write, with aliases, and mapped by hand to one USDA food. These cover every ingredient in the ten prototype recipes. Treat these as the app's catalogue.
2. **Automatic** (`curated: false`). Built by rule from USDA descriptions. Broad, but names can be odd ("Pasteurized process cheese") and the default form is a best guess. Use as a fallback and as the pool to promote from.

Promoting an ingredient to curated is one line in `overlay/curated.csv`.

## Ingredient record

```json
{
  "id": "butter", "name": "Butter", "aliases": ["salted butter"], "curated": true,
  "aisle": "Dairy and eggs", "group": "Dairy and Egg Products",
  "default_food": "usda:01001", "default_description": "Butter, salted",
  "per_100g": {"energy_kcal": 717, "protein_g": 0.85, "fat_g": 81.11, "carbs_g": 0.06, "sodium_mg": 643},
  "density_g_per_ml": 0.96, "density_basis": "plain measure",
  "unit_weights_g": {"pat": 5.0, "stick": 113.0},
  "allergens": ["milk"], "diet": "vegetarian",
  "shelf_life": {"fridge_days": [30, 60], "freezer_days": [180, 270]},
  "variants": [{"food": "usda:01145", "description": "Butter, without salt", "state": null}]
}
```

How the app uses it: `4 cloves garlic` resolves to Garlic by alias, `unit_weights_g.clove` gives 3 g each, so 12 g;
`1 cup flour` uses `density_g_per_ml` (0.528) to get 125 g; grams times `per_100g` gives nutrition.

`density_basis` says what the density was measured on. "plain measure" is the ingredient as is. "cup, chopped" means it only
holds for that cut, which matters for vegetables.

## Sources and licences

| Source | Used for | Licence | Attribution |
|---|---|---|---|
| USDA National Nutrient Database for Standard Reference, Release 28 (2015), official `sr28asc.zip` | Foods, nutrition, US measures | Public domain (US government work; FoodData Central is published CC0) | U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov |
| USDA Foundation Foods, April 2026, official FoodData Central CSV download | 378 foods with recent lab analysis | Public domain (CC0) | as above |
| Canadian Nutrient File 2026, Health Canada, official download | Canada-only foods, French descriptions, metric measures, cooking yields | Open Government Licence, Canada | Contains information licensed under the Open Government Licence, Canada. Canadian Nutrient File, Health Canada, 2026 |
| USDA FSIS FoodKeeper (GitHub mirror, unverified copy) | Shelf life | US government work | USDA Food Safety and Inspection Service, FoodKeeper |

The app must show the USDA and Health Canada attribution lines (an About screen is enough).

## Known limits. Read before relying on it

- **USDA data is the official SR28 release (2015).** Built from USDA's own `sr28asc.zip`, unzipped into `raw/official_sr28/`.
- **Foundation Foods (April 2026) is in, as extra foods, not as the default.** 378 of its 469 foods have an energy value and are
  included. It is recent lab data but sparse: fewer nutrients and few household measures per food. So curated ingredients still
  use SR28 values, and `newer_lab_data` marks where a newer analysis exists. Where both cover a food, energy differs by more
  than 10% in 31 of 181 cases (hummus 166 vs 229 kcal, kale 49 vs 35), so choosing which wins is a real decision, not a formality.
  Put the unzipped download in `raw/official_ff/`. The October 2026 CSV zip was missing its main tables; April was complete.
- **SR Legacy (2018) is not in.** It is the final Standard Reference release, one step newer than SR28.
- **Canadian data is the official 2026 edition**, unzipped into `raw/official_cnf2026/`. Where a Canadian food links to a USDA food,
  the USDA nutrition is used and the Canadian file adds the French description and metric measures. Canadian nutrition values are
  used only for the 1,313 foods USDA does not have.
- **Shelf-life data is still an unverified mirror copy.**
- **Allergen and diet tags are rules, not facts.** They come from keywords and food groups. They will miss hidden ingredients
  and can over-flag. Good for a warning that prompts a label check. Not good enough to tell someone a food is safe.
- **French is the full database description** ("Oignon, cru"), not a short display name. 42% of foods have none.
- **Shelf life is matched by name** and covers 322 ingredients. Unmatched ones have none.
- **Gaps.** Some real ingredients are not in these sources (`overlay/gaps.csv`, currently red curry paste). They are listed
  without nutrition and must not be filled with guesses.
- **No prices and no swaps.** Prices come from receipts; swaps are ours to write. Cooking yields are present for 1,026 foods but raw, not yet turned into "what this becomes when cooked".
- **Nutrition is per 100 g of the listed form.** Raw and cooked differ. Chicken breast is 120 kcal raw and 165 roasted, so the recipe must say which.

## Rebuild

```
# unzip USDA's sr28asc.zip into raw/official_sr28/ and Health Canada's 2026 zip into raw/official_cnf2026/
./fetch.sh                 # shelf-life table, plus mirror copies used as fallbacks (raw/ is not committed)
python3 -I build.py        # writes out/
python3 -I validate.py     # checks; exits non-zero on failure
```

`validate.py` checks that every ingredient in the prototype recipes resolves, compares the prototype's hand-entered calories with
the database, tests the nutrition data for internal consistency, and spot-checks known values.

### What validation found in the prototype

Comparing the ten recipes' hand-entered numbers with the database: 66 of 69 lines agree within 35%. Three do not:

- Chicken (Cajun pasta, piccata): the prototype uses 165 kcal per 100 g, which is the roasted value. Raw breast is 120.
- Lemongrass (Thai soup): the prototype uses 25 kcal per 100 g. The database says 99.
