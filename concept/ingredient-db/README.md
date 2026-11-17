# Ingredient database

A cleaned, structured food and ingredient dataset built from open government data, for the Recipes app:
the Sankey, nutrition, unit conversion, shopping aisles, allergen flags and pantry shelf life all read from it.

## What is in it

| File | Records | What |
|---|---|---|
| `out/foods.jsonl` | 8,789 | Every food in the USDA reference set, cleaned. Nutrition per 100 g (27 values), every household measure with its gram weight, density, weight per item, state (raw, cooked, canned, frozen, dried), aisle, allergen and diet tags |
| `out/ingredients.json` | 1,289 | Cooking ingredients. One record per ingredient, with a default food, its other forms, aliases and shelf life |
| `out/ingredients.csv` | 1,289 | The same, flat, to open in a spreadsheet |
| `out/stats.json` | | Counts and coverage from the last build |

Coverage in this build:

- Foods by kind: 5,649 ingredients, 1,427 branded, 1,098 prepared dishes, 367 baby foods, 165 regional, 83 institutional. Only "ingredient" foods feed the ingredient list.
- 15,438 household measures. 3,529 foods have a density (grams per millilitre); 4,725 have a weight per item (1 egg, 1 clove, 1 medium onion).
- Ingredients: 88 curated by hand (87 with data, 1 known gap), 1,201 built automatically. 838 have a density, 600 a weight per item, 304 a shelf life.
- French names matched for 1,249 foods.

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
| USDA National Nutrient Database for Standard Reference, Release 28 (2015) | Foods, nutrition, measures | Public domain (US government work; FoodData Central is published CC0) | U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov |
| Canadian Nutrient File 2015, Health Canada | French names | Open Government Licence, Canada | Contains information licensed under the Open Government Licence, Canada. Canadian Nutrient File, Health Canada, 2015 |
| USDA FSIS FoodKeeper | Shelf life | US government work | USDA Food Safety and Inspection Service, FoodKeeper |

The app must show the USDA and Health Canada attribution lines (an About screen is enough).

## Known limits. Read before relying on it

- **USDA data is the official SR28 release (2015).** Built from USDA's own `sr28asc.zip`. The GitHub mirror used for the very
  first build was compared with it and is identical apart from line endings. Put the unzipped official files in `raw/official_sr28/`.
- **Not yet the newest USDA data.** SR Legacy (2018, the final Standard Reference release) and Foundation Foods (2026) are not in.
  The current download site (https://fdc.nal.usda.gov/download-datasets) publishes them in a different table layout
  (`food.csv`, `food_nutrient.csv`, `food_portion.csv`), which needs a second reader in `build.py`.
- **Canadian data is still a mirror copy of the 2015 edition**, used only for French names. Health Canada has a 2026 edition:
  https://www.canada.ca/en/health-canada/services/food-nutrition/healthy-eating/nutrient-data.html
- **Allergen and diet tags are rules, not facts.** They come from keywords and food groups. They will miss hidden ingredients
  and can over-flag. Good for a warning that prompts a label check. Not good enough to tell someone a food is safe.
- **French coverage is thin** (14% of foods). The Canadian file words its descriptions differently, so only close matches are kept.
- **Shelf life is matched by name** and covers 304 ingredients. Unmatched ones have none.
- **Gaps.** Some real ingredients are not in these sources (`overlay/gaps.csv`, currently red curry paste). They are listed
  without nutrition and must not be filled with guesses.
- **No prices, no swaps, no cooked-yield data.** Prices come from receipts. Swaps and "what this becomes when cooked" are ours to write.
- **Nutrition is per 100 g of the listed form.** Raw and cooked differ. Chicken breast is 120 kcal raw and 165 roasted, so the recipe must say which.

## Rebuild

```
./fetch.sh                 # mirrors into raw/ (not committed); or unzip USDA's sr28asc.zip into raw/official_sr28/
python3 -I build.py        # writes out/
python3 -I validate.py     # checks; exits non-zero on failure
```

`validate.py` checks that every ingredient in the prototype recipes resolves, compares the prototype's hand-entered calories with
the database, tests the nutrition data for internal consistency, and spot-checks known values.

### What validation found in the prototype

Comparing the ten recipes' hand-entered numbers with the database: 66 of 69 lines agree within 35%. Three do not:

- Chicken (Cajun pasta, piccata): the prototype uses 165 kcal per 100 g, which is the roasted value. Raw breast is 120.
- Lemongrass (Thai soup): the prototype uses 25 kcal per 100 g. The database says 99.
