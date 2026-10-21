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
