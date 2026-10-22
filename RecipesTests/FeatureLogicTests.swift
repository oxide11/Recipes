import Testing
import Foundation
@testable import Recipes

// MARK: - Lenient AI JSON decoding

@Suite("Recipe ingestion decoding")
struct IngestionDecodingTests {

    private func decode(_ json: String) throws -> RecipeIngestionResult {
        try JSONDecoder().decode(RecipeIngestionResult.self, from: Data(json.utf8))
    }

    @Test("Servings range and minute-suffixed times decode")
    func rangesAndSuffixes() throws {
        let result = try decode("""
        {"title":"Soup","servings":"4-6","prepTimeMinutes":"15 min","cookTimeMinutes":30.0,
         "ingredients":[],"directions":["Boil"]}
        """)
        #expect(result.servings == 4)
        #expect(result.prepTimeMinutes == 15)
        #expect(result.cookTimeMinutes == 30)
    }

    @Test("Bare-string ingredients and a single directions string decode")
    func looseShapes() throws {
        let result = try decode("""
        {"title":"Toast","ingredients":["2 slices bread", {"name":"Butter","amount":1}],
         "directions":"Toast the bread.\\nSpread the butter."}
        """)
        #expect(result.ingredients.count == 2)
        #expect(result.ingredients[0].name == "2 slices bread")
        #expect(result.ingredients[1].amount == "1")
        #expect(result.directions.count == 2)
    }

    @Test("Float nutrition values round to Int")
    func nutritionFloats() throws {
        let result = try decode("""
        {"title":"X","ingredients":[],"directions":[],
         "nutritionPerServing":{"calories":412.6,"proteinGrams":"12 g","carbsGrams":40,"fatGrams":null}}
        """)
        #expect(result.nutritionPerServing?.calories == 413)
        #expect(result.nutritionPerServing?.proteinGrams == 12)
        #expect(result.nutritionPerServing?.fatGrams == nil)
    }

    @Test("Missing title falls back instead of failing")
    func missingTitle() throws {
        let result = try decode("{\"ingredients\":[],\"directions\":[]}")
        #expect(result.title == "Untitled Recipe")
    }
}

// MARK: - JSON detection for hybrid routing

@Suite("AI router JSON detection")
struct RouterJSONDetectionTests {

    @Test("Fenced and prose-wrapped JSON is recognised") @MainActor
    func recognisesJSON() {
        #expect(AIServiceRouter.looksLikeJSON("```json\n{\"a\":1}\n```"))
        #expect(AIServiceRouter.looksLikeJSON("Sure! Here you go: [{\"x\":2}] hope that helps"))
    }

    @Test("Prose and broken JSON are rejected") @MainActor
    func rejectsProse() {
        #expect(!AIServiceRouter.looksLikeJSON("A lovely recipe for soup starts with onions."))
        #expect(!AIServiceRouter.looksLikeJSON("{\"unterminated\": "))
    }
}

// MARK: - Pantry deduction

@Suite("Pantry deduction")
struct PantryDeductionTests {

    @Test("Matches canonical names and converts units")
    func canonicalAndConverted() {
        let recipe = Recipe(
            title: "Rice",
            servings: 4,
            ingredients: [
                Ingredient(name: "Onions", category: .vegetable, amount: IngredientAmount(quantity: 2, unit: .piece)),
                Ingredient(name: "Olive oil", category: .oil, amount: IngredientAmount(quantity: 2, unit: .tablespoon)),
            ]
        )
        let onions = PantryItem(name: "onion", category: .vegetable, quantity: 3, unit: .piece)
        let oil = PantryItem(name: "olive oil", category: .oil, quantity: 500, unit: .milliliter)

        let consumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe, servingsCooked: 2, pantryItems: [onions, oil]
        )
        #expect(consumed.isEmpty)
        #expect(onions.quantity == 2)                 // 2 × (2/4) = 1 used
        #expect(abs(oil.quantity - 485.2) < 0.5)      // 1 tbsp ≈ 14.8 ml
    }

    @Test("Volume vs weight mismatch leaves the pantry alone")
    func incompatibleUnitsSkipped() {
        let recipe = Recipe(
            title: "Bread", servings: 1,
            ingredients: [Ingredient(name: "Flour", category: .grain, amount: IngredientAmount(quantity: 2, unit: .cup))]
        )
        let flour = PantryItem(name: "flour", category: .grain, quantity: 1000, unit: .gram)
        _ = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [flour])
        #expect(flour.quantity == 1000)
    }

    @Test("Items that run out are reported")
    func reportsConsumed() {
        let recipe = Recipe(
            title: "Eggs", servings: 1,
            ingredients: [Ingredient(name: "Eggs", category: .dairy, amount: IngredientAmount(quantity: 3, unit: .piece))]
        )
        let eggs = PantryItem(name: "egg", category: .dairy, quantity: 2, unit: .piece)
        let consumed = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(consumed.count == 1)
        #expect(eggs.quantity == 0)
    }
}

// MARK: - Shopping list generation from a meal plan window

@Suite("Shopping list from meal plan")
struct MealPlanShoppingTests {

    private func recipe(_ title: String, _ name: String, qty: Double, unit: MeasurementUnit) -> Recipe {
        Recipe(title: title, servings: 2,
               ingredients: [Ingredient(name: name, category: .vegetable, amount: IngredientAmount(quantity: qty, unit: unit))])
    }

    @Test("Only meals inside the date window are included")
    func dateWindow() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let nextMonth = cal.date(byAdding: .day, value: 30, to: today)!
        let plan = MealPlan(name: "Plan", startDate: today, endDate: nextMonth)
        plan.meals = [
            PlannedMeal(mealType: .dinner, date: today, recipe: recipe("A", "Carrots", qty: 2, unit: .piece), servings: 2),
            PlannedMeal(mealType: .dinner, date: nextMonth, recipe: recipe("B", "Leeks", qty: 1, unit: .piece), servings: 2),
        ]
        let items = ShoppingListGenerator.generateItems(from: plan, dateRange: today...cal.date(byAdding: .day, value: 6, to: today)!)
        #expect(items.map(\.name) == ["Carrots"])
    }

    @Test("Ingredients already on the list are not added twice")
    func skipsListed() {
        let today = Calendar.current.startOfDay(for: .now)
        let plan = MealPlan(name: "Plan", startDate: today, endDate: today)
        plan.meals = [PlannedMeal(mealType: .lunch, date: today, recipe: recipe("A", "Tomatoes", qty: 4, unit: .piece), servings: 2)]
        let listed = GroceryItem(name: "tomato", quantity: 1, unit: .piece)
        let items = ShoppingListGenerator.generateItems(from: plan, pantryItems: [], existingItems: [listed])
        #expect(items.isEmpty)
    }
}

// MARK: - Safe temperatures from ingredient names

@Suite("Safe temperature mapping")
struct SafeTemperatureMappingTests {

    @Test("Chicken thighs map to the thigh entry")
    func chickenThighs() {
        let temp = SafeCookingTemperatureService.safeTemperature(forIngredientNamed: "Boneless chicken thighs")
        #expect(temp?.protein == "Chicken (thigh)")
        #expect(temp?.minimumFahrenheit == 165)
    }

    @Test("Ground beef uses the ground entry; produce has none")
    func groundAndNone() {
        #expect(SafeCookingTemperatureService.safeTemperature(forIngredientNamed: "1 lb ground beef")?.protein == "Ground beef")
        #expect(SafeCookingTemperatureService.safeTemperature(forIngredientNamed: "Spinach") == nil)
    }
}

// MARK: - Substitution lookup

@Suite("Substitution lookup")
struct SubstitutionLookupTests {

    @Test("Qualified and plural names resolve to table entries")
    func canonicalLookup() {
        #expect(!SubstitutionEngine.findSubstitutions(for: "unsalted butter").isEmpty)
        #expect(!SubstitutionEngine.findSubstitutions(for: "eggs").isEmpty)
        #expect(SubstitutionEngine.findSubstitutions(for: "unobtainium").isEmpty)
    }
}

// MARK: - Hemisphere-aware seasons

@Suite("Hemisphere seasons", .serialized)
struct HemisphereSeasonTests {

    @Test("Season.current follows the active hemisphere")
    func followsActiveHemisphere() {
        let saved = Season.activeHemisphere
        defer { Season.activeHemisphere = saved }

        Season.activeHemisphere = .northern
        let north = Season.current
        Season.activeHemisphere = .southern
        let south = Season.current

        #expect(north == Season.current(for: .northern))
        #expect(south == Season.current(for: .southern))
        #expect(north != south)
    }

    @Test("Plural ingredient names match the seasonal table")
    func pluralLookup() {
        let saved = Season.activeHemisphere
        defer { Season.activeHemisphere = saved }
        // Asparagus is spring-only in the table; pick the hemisphere where it is spring now.
        let hemisphere: Hemisphere = Season.current(for: .northern) == .spring ? .northern : .southern
        Season.activeHemisphere = hemisphere
        let inSpring = Season.current == .spring
        #expect(SeasonalAwarenessService.isInSeason("Asparagus spears") == inSpring)
    }
}

// MARK: - Profile prompt constraints

@Suite("Profile prompt constraints")
struct ProfileConstraintTests {

    @Test("Allergens, dislikes and max time appear; empty profile yields nothing")
    func clauseContents() {
        let profile = UserProfile(displayName: "Test")
        #expect(profile.aiConstraintClause.isEmpty)

        profile.allergens = ["peanuts", " shellfish "]
        profile.dislikedIngredients = ["cilantro"]
        profile.maxCookTimeMinutes = 30
        let clause = profile.aiConstraintClause
        #expect(clause.contains("peanuts, shellfish"))
        #expect(clause.contains("cilantro"))
        #expect(clause.contains("30 minutes or less"))
        #expect(profile.aiHardLimitsClause.contains("ALLERGENS"))
    }
}

// MARK: - Review fixes

@Suite("Safe temperatures never below USDA, no look-alikes")
struct SafeTemperatureSafetyTests {

    private func temp(_ name: String) -> SafeTemperature? {
        SafeCookingTemperatureService.safeTemperature(forIngredientNamed: name)
    }

    @Test("Generic and cut names map to USDA minimums")
    func usdaMinimums() {
        #expect(temp("ribeye steak")?.protein == "Beef steak (medium)")
        #expect(temp("ribeye steak")?.minimumFahrenheit == 145)
        #expect(temp("beef chuck")?.protein == "Beef roast")
        #expect(temp("ground turkey")?.protein == "Ground poultry")
        #expect(temp("turkey breast")?.protein == "Turkey (breast)")
        #expect(temp("pork shoulder")?.protein == "Pulled pork (shoulder)")
        #expect(temp("Italian sausage")?.protein == "Ground pork")
    }

    @Test("Species beat cut words: pork, ham and tuna steaks are not beef")
    func speciesBeforeCut() {
        #expect(temp("pork steak")?.protein == "Pork")
        #expect(temp("ham steak")?.protein == "Ham (pre-cooked, reheating)")
        #expect(temp("tuna steak")?.protein == "Fish (fin fish)")
        #expect(temp("salmon fillets")?.minimumFahrenheit == 145)
    }

    @Test("Look-alikes, stocks, cured and plant-based forms get no badge")
    func noFalsePositives() {
        for name in ["eggplant", "hamburger buns", "graham crackers", "beef broth", "chicken stock",
                     "fish sauce", "egg noodles", "eggs", "bacon strips", "smoked salmon", "canned tuna",
                     "veggie burger", "ground cumin", "beefsteak tomato", "Guanciale", "clams"] {
            #expect(temp(name) == nil, "\(name) should have no safe-temperature badge")
        }
    }

    @Test("No automatic badge is ever below the USDA minimum for its species")
    func neverBelowUSDA() {
        for name in ["steak", "beef", "salmon", "tuna", "scallops", "lamb chops", "duck breast", "shrimp"] {
            if let t = temp(name) { #expect(t.minimumFahrenheit >= 145, "\(name) → \(t.protein)") }
        }
    }
}

@Suite("Category inference")
struct CategoryInferenceTests {

    @Test("Protein words match whole words only")
    func wholeWordProtein() {
        #expect(IngredientNormalizer.inferCategory(fromName: "Eggplant") == .vegetable)
        #expect(IngredientNormalizer.inferCategory(fromName: "Eggs") == .protein)
        #expect(IngredientNormalizer.inferCategory(fromName: "Graham crackers") != .protein)
        #expect(IngredientNormalizer.inferCategory(fromName: "Chicken thighs") == .protein)
    }
}

@Suite("Substitution head-noun matching")
struct SubstitutionHeadNounTests {

    @Test("Varieties match; different products don't")
    func headNouns() {
        #expect(!SubstitutionEngine.findSubstitutions(for: "whole milk").isEmpty)
        #expect(!SubstitutionEngine.findSubstitutions(for: "low-sodium soy sauce").isEmpty)
        #expect(SubstitutionEngine.findSubstitutions(for: "butternut squash").isEmpty)
        #expect(SubstitutionEngine.findSubstitutions(for: "almond milk").isEmpty)
        #expect(SubstitutionEngine.findSubstitutions(for: "peanut butter").isEmpty)
        #expect(SubstitutionEngine.findSubstitutions(for: "sugar snap peas").isEmpty)
    }
}

@Suite("Seasonal processed forms")
struct SeasonalProcessedTests {

    @Test("Shelf-stable products are never in season")
    func processed() {
        for name in ["apple cider vinegar", "corn syrup", "lime juice", "pumpkin pie spice"] {
            #expect(!SeasonalAwarenessService.isInSeason(name), "\(name)")
        }
    }
}

@Suite("Duration parsing")
struct DurationParsingTests {

    @Test("Hours, ranges and ISO 8601 become minutes")
    func minutes() {
        #expect(LenientJSON.parseMinutes("30 min") == 30)
        #expect(LenientJSON.parseMinutes("1 hour") == 60)
        #expect(LenientJSON.parseMinutes("1.5 hours") == 90)
        #expect(LenientJSON.parseMinutes("1h 30m") == 90)
        #expect(LenientJSON.parseMinutes("1 hr 30 min") == 90)
        #expect(LenientJSON.parseMinutes("10-15 minutes") == 10)
        #expect(LenientJSON.parseMinutes("PT1H30M") == 90)
        #expect(LenientJSON.parseMinutes("overnight") == nil)
    }

    @Test("Hour-denominated times decode as minutes")
    func decodesHours() throws {
        let json = "{\"title\":\"Stew\",\"prepTimeMinutes\":\"20 minutes\",\"cookTimeMinutes\":\"2 hours\",\"ingredients\":[],\"directions\":[]}"
        let result = try JSONDecoder().decode(RecipeIngestionResult.self, from: Data(json.utf8))
        #expect(result.prepTimeMinutes == 20)
        #expect(result.cookTimeMinutes == 120)
    }
}

@Suite("JSON detection with bracketed prose")
struct BracketedProseJSONTests {

    @Test("Brackets in prose before the object don't hide valid JSON") @MainActor
    func bracketPrefix() {
        #expect(AIServiceRouter.looksLikeJSON("Here is the recipe [serves 4]: {\"title\":\"x\",\"ingredients\":[]}"))
    }
}

@Suite("Pantry deduction leaves unknown amounts alone")
struct PantryPlaceholderTests {

    private let recipe = Recipe(
        title: "Omelette", servings: 1,
        ingredients: [Ingredient(name: "Eggs", category: .dairy, amount: IngredientAmount(quantity: 2, unit: .piece))]
    )

    @Test("A '1 piece' placeholder is not deducted or reported as used up")
    func placeholderUntouched() {
        let eggs = PantryItem(name: "eggs", category: .dairy, quantity: 1, unit: .piece)
        let consumed = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(consumed.isEmpty)
        #expect(eggs.quantity == 1)
    }

    @Test("Staples are not deducted")
    func staplesUntouched() {
        let eggs = PantryItem(name: "eggs", category: .dairy, quantity: 12, unit: .piece)
        eggs.isStaple = true
        _ = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(eggs.quantity == 12)
    }
}

@Suite("Meal reminder times")
struct MealReminderTimeTests {

    @Test("Usual meal times") @MainActor
    func usualTimes() {
        let breakfast = SmartNotificationService.usualMealTime(for: .breakfast)
        let dinner = SmartNotificationService.usualMealTime(for: .dinner)
        #expect(breakfast.hour == 8 && breakfast.minute == 0)
        #expect(dinner.hour == 18 && dinner.minute == 30)
    }
}

// MARK: - Verification-pass fixes

@Suite("Safe temperatures: ground cuts, styles, eggs, game, prep text")
struct SafeTemperatureEdgeTests {

    private func temp(_ name: String) -> SafeTemperature? {
        SafeCookingTemperatureService.safeTemperature(forIngredientNamed: name)
    }

    @Test("Ground steak cuts use the ground-beef minimum")
    func groundCuts() {
        for name in ["steak mince", "minced steak", "ground sirloin", "ground chuck", "ground round"] {
            #expect(temp(name)?.protein == "Ground beef", "\(name)")
            #expect(temp(name)?.minimumFahrenheit == 160, "\(name)")
        }
    }

    @Test("Cooking styles and look-alikes don't change species or add badges")
    func stylesAndLookAlikes() {
        #expect(temp("chicken-fried steak")?.protein == "Beef steak (medium)")
        for name in ["duck eggs", "quail eggs", "venison steak", "cabbage steaks", "portobello steaks",
                     "steak fries", "pork rinds", "salmon roe", "tortilla strips", "anchovy filets",
                     "chicken bouillon cubes"] {
            #expect(temp(name) == nil, "\(name)")
        }
    }

    @Test("Prep text after the name keeps the badge")
    func prepText() {
        #expect(temp("stew beef, cut into cubes")?.protein == "Beef")
        #expect(temp("chicken thighs with skin")?.protein == "Chicken (thigh)")
        #expect(temp("chicken bites")?.protein == "Chicken")
        #expect(temp("chicken skin") == nil)
    }
}

@Suite("Category inference for closed compounds")
struct CompoundCategoryTests {

    @Test("Compounds of a protein and a cut are protein; non-protein heads win")
    func compounds() {
        for name in ["porkchops", "fishcakes", "swordfish", "sausagemeat"] {
            #expect(IngredientNormalizer.inferCategory(fromName: name) == .protein, "\(name)")
        }
        for name in ["hamburger buns", "fish sauce", "egg noodles", "beefsteak tomato"] {
            #expect(IngredientNormalizer.inferCategory(fromName: name) != .protein, "\(name)")
        }
    }
}

@Suite("Duration parsing: fractions and ranges with units")
struct DurationFractionTests {

    @Test("Fractions become one quantity; ranges take the lower bound")
    func fractionsAndRanges() {
        #expect(LenientJSON.parseMinutes("1 1/2 hours") == 90)
        #expect(LenientJSON.parseMinutes("1/2 hour") == 30)
        #expect(LenientJSON.parseMinutes("1½ hours") == 90)
        #expect(LenientJSON.parseMinutes("½ hour") == 30)
        #expect(LenientJSON.parseMinutes("45 minutes to 1 hour") == 45)
        #expect(LenientJSON.parseMinutes("2-3 hrs") == 120)
    }
}

@Suite("JSON detection follows the opening bracket")
struct OpeningBracketJSONTests {

    @Test("A reply cut off mid-array is rejected") @MainActor
    func truncatedArray() {
        #expect(!AIServiceRouter.looksLikeJSON("[{\"name\":\"milk\",\"category\":\"dairy\"},{\"name\":\"eg"))
        #expect(AIServiceRouter.looksLikeJSON("[{\"name\":\"milk\",\"category\":\"dairy\"}]"))
    }
}

@Suite("Deduction continues once a real count reaches one")
struct DeductionToZeroTests {

    @Test("3 eggs, a 1-egg recipe cooked three times, ends at zero and is reported")
    func countsDownThroughOne() {
        let recipe = Recipe(
            title: "Fried egg", servings: 1,
            ingredients: [Ingredient(name: "Egg", category: .protein, amount: IngredientAmount(quantity: 1, unit: .piece))]
        )
        let eggs = PantryItem(name: "eggs", category: .protein, quantity: 3, unit: .piece)
        _ = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        _ = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(eggs.quantity == 1)
        let consumed = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(eggs.quantity == 0)
        #expect(consumed.count == 1)
    }
}

@Suite("Seasonal processed tomato forms")
struct SeasonalCannedTomatoTests {

    @Test("Canned tomato products are never in season")
    func cannedTomatoes() {
        for name in ["diced tomatoes", "crushed tomatoes", "stewed tomatoes", "creamed corn"] {
            #expect(!SeasonalAwarenessService.isInSeason(name), "\(name)")
        }
    }
}

extension HemisphereSeasonTests {

    @Test("Multi-word entries match plurals: 'sweet potatoes' is the autumn/winter sweet potato")
    func multiWordPlural() {
        let saved = Season.activeHemisphere
        defer { Season.activeHemisphere = saved }
        // Exactly one hemisphere is in autumn or winter in any month.
        let coldNorth = [.autumn, .winter].contains(Season.current(for: .northern))
        Season.activeHemisphere = coldNorth ? .northern : .southern
        #expect(SeasonalAwarenessService.isInSeason("sweet potatoes"))
        #expect(SeasonalAwarenessService.isInSeason("sweet potato"))
    }
}

// MARK: - Final verification pass

@Suite("Final pass fixes")
struct FinalPassTests {

    @Test("A range after an hour part still adds the hour")
    func rangeAfterHours() {
        #expect(LenientJSON.parseMinutes("1 hr 10-15 min") == 70)
        #expect(LenientJSON.parseMinutes("1 hour 15-20 minutes") == 75)
    }

    @Test("Strip steak names are beef; generic strips are not")
    func stripSteaks() {
        for name in ["New York strip", "NY strip", "strip loin"] {
            #expect(SafeCookingTemperatureService.safeTemperature(forIngredientNamed: name)?.protein == "Beef steak (medium)", "\(name)")
        }
        #expect(SafeCookingTemperatureService.safeTemperature(forIngredientNamed: "pepper strips") == nil)
    }

    @Test("Tapping Keep on a placeholder doesn't make it a real count")
    func keepDoesNotMakeRealCount() {
        let recipe = Recipe(
            title: "Scramble", servings: 1,
            ingredients: [Ingredient(name: "Eggs", category: .protein, amount: IngredientAmount(quantity: 2, unit: .piece))]
        )
        let eggs = PantryItem(name: "eggs", category: .protein, quantity: 1, unit: .piece)
        eggs.lastUsed = .now   // what the pantry's "Keep" button does
        let consumed = PantryDeductionService.deductAfterCooking(recipe: recipe, servingsCooked: 1, pantryItems: [eggs])
        #expect(consumed.isEmpty)
        #expect(eggs.quantity == 1)
    }
}
