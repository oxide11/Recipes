# Ingredient database

A cleaned, structured food and ingredient dataset built from open government data, for the Recipes app:
the Sankey, nutrition, unit conversion, shopping aisles, allergen flags and pantry shelf life all read from it.

## What is in it

| File | Records | What |
|---|---|---|
| `out/foods.jsonl` | 15,941 | Every food from all sources, cleaned. Nutrition per 100 g (27 values), household measures with gram weights (US and metric), density, weight per item, state (raw, cooked, canned, frozen, dried), aisle, allergen and diet tags, French description |
| `out/ingredients.json` | 1,440 | Cooking ingredients. One record per ingredient, with a default food, its other forms, aliases and shelf life |
| `out/ingredients.csv` | 1,440 | The same, flat, to open in a spreadsheet |
| `out/stats.json` | | Counts and coverage from the last build |

Where the 15,941 foods come from (the `source` field, and the id prefix):

| Source | Foods | id | Role |
|---|---|---|---|
| USDA Standard Reference | 8,829 | `usda:` | The base. SR Legacy (2018) values wherever it has the food (7,793); the 1,036 foods it dropped keep their SR28 values and are flagged `dropped_in_sr_legacy` |
| USDA survey foods (FNDDS 2021-2023) | 5,431 | `fndds:` | Foods as eaten, in everyday wording, with consumer portions and what each is made from (`made_from`). Kind `survey`; they do not feed the ingredient list |
| Canadian Nutrient File 2026 | 1,303 | `cnf:` | Foods USDA does not have. Also supplies French and metric measures to linked USDA foods |
| USDA Foundation Foods (April 2026) | 378 | `fdc:` | Recent lab analysis. 183 base foods point to one via `newer_lab_data` |

Coverage in this build:

- 48,181 household measures, 15,895 of them metric measures from the Canadian file. 9,442 foods have a density; 8,900 have a weight per item (1 egg, 1 clove, 1 medium onion).
- French descriptions for 5,979 foods, joined by the USDA code the Canadian file carries.
- 1,026 foods carry Canadian cooking-yield figures (`yields`), kept as published and not yet interpreted.
- 1,402 base foods carry `survey_names`: everyday names USDA's survey uses for them ("Milk, whole"). Useful as alias candidates; approximate, so not applied automatically.
- Ingredients: 88 curated by hand (87 with data, 1 known gap), 1,352 built automatically. 971 have a density, 761 a weight per item, 330 a shelf life.

## How the sources combine

Decided 17 November 2026. For every base (USDA) food, value by value:

1. **Start from USDA Standard Reference** (SR Legacy 2018), the most complete record.
2. **The latest lab analysis always wins.** Where Foundation Foods has the same food, each value it publishes replaces the older one.
   183 foods, 2,329 values replaced. The replaced figures are kept in `latest_lab.superseded` so the change can be audited.
3. **Canada fills the gaps.** A value USDA lacks is taken from the linked Canadian food. 2,512 foods, 6,446 values
   (mostly trans fat and vitamin D). Listed in `filled_from_cnf`.
4. **Canada corroborates the rest.** Every remaining value is compared with the Canadian one. Of 4,521 foods compared,
   3,844 agree on every value and 677 differ on at least one by more than 10%. The differences are in `cnf_check.differs`
   as `[value used, Canadian value]`. Nothing is changed on the strength of a disagreement; it is a flag to review.

Some disagreements are real Canadian differences, not errors: margarine has 26 mcg of vitamin D per 100 g in Canada and none
in the US figure, because of fortification rules. Others mean the two files describe slightly different products
(mozzarella, sirloin). If the app should show Canadian label values for fortified foods, those flagged foods are the list to go through.

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
| USDA SR Legacy, April 2018 (FoodData Central JSON) | Base foods, nutrition, US measures | Public domain (CC0) | U.S. Department of Agriculture, Agricultural Research Service. FoodData Central. fdc.nal.usda.gov |
| USDA SR28 (2015, `sr28asc.zip`) with the May 2016 revision (`sr28upd0516.zip`) | The 1,036 foods SR Legacy dropped; inedible-portion and scientific-name fields | Public domain | as above |
| USDA FNDDS 2021-2023 survey foods (FoodData Central JSON) | Foods as eaten, consumer portions, everyday names | Public domain (CC0) | as above |
| USDA Foundation Foods, April 2026 (FoodData Central CSV) | 378 foods with recent lab analysis | Public domain (CC0) | as above |
| Canadian Nutrient File 2026, Health Canada | Canada-only foods, French descriptions, metric measures, cooking yields | Open Government Licence, Canada | Contains information licensed under the Open Government Licence, Canada. Canadian Nutrient File, Health Canada, 2026 |
| USDA FSIS FoodKeeper (GitHub mirror, unverified copy) | Shelf life | US government work | USDA Food Safety and Inspection Service, FoodKeeper |

All USDA and Health Canada files are the official downloads. Only the shelf-life table is a mirror copy.

The app must show the USDA and Health Canada attribution lines (an About screen is enough).

## Known limits. Read before relying on it

- **The USDA base is SR Legacy (2018), the final Standard Reference release.** It replaced SR28 values food by food. Against SR28,
  energy changed for 210 foods. SR Legacy's JSON rounds some values a little more coarsely than the old text files (egg protein 12.6, not 12.56).
- **Latest lab values are sparser than the records they update.** Foundation Foods publishes fewer nutrients per food, so a
  food can carry 2026 values for some nutrients and 2018 values for others. Energy and the macronutrients always move together.
- **Survey foods are not ingredients.** They are mixed dishes and foods as eaten. They are in the food table for their portions,
  names and recipes, and are kept out of the ingredient list. They carry no aisle, allergen or diet tags.
- **Canadian data is the official 2026 edition**, unzipped into `raw/official_cnf2026/`. Where a Canadian food links to a USDA food,
  the USDA nutrition is used and the Canadian file adds the French description and metric measures. Canadian nutrition values are
  used only for the 1,313 foods USDA does not have.
- **Shelf-life data is still an unverified mirror copy.**
- **Allergen and diet tags are rules, not facts.** They come from keywords and food groups. They will miss hidden ingredients
  and can over-flag. Good for a warning that prompts a label check. Not good enough to tell someone a food is safe.
- **French is the full database description** ("Oignon, cru"), not a short display name. Survey foods and most Foundation foods have none.
- **Shelf life is matched by name** and covers 330 ingredients. Unmatched ones have none.
- **Gaps.** Some real ingredients are not in these sources (`overlay/gaps.csv`, currently red curry paste). They are listed
  without nutrition and must not be filled with guesses.
- **No prices and no swaps.** Prices come from receipts; swaps are ours to write. Cooking yields are present for 1,026 foods but raw, not yet turned into "what this becomes when cooked".
- **Nutrition is per 100 g of the listed form.** Raw and cooked differ. Chicken breast is 120 kcal raw and 165 roasted, so the recipe must say which.

## Rebuild

```
# unzip the official downloads into raw/: official_sr28/, official_sr28upd/, official_srlegacy/, official_fndds/, official_ff/, official_cnf2026/
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
