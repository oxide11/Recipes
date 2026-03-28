import XCTest
@testable import Recipes

// MARK: - ShoppingListGenerator Tests

final class ShoppingListGeneratorTests: XCTestCase {

    // MARK: - Helpers

    private func makeIngredient(
        name: String,
        category: IngredientCategory = .vegetable,
        quantity: Double,
        unit: MeasurementUnit,
        isOptional: Bool = false
    ) -> Ingredient {
        Ingredient(
            name: name,
            category: category,
            amount: IngredientAmount(quantity: quantity, unit: unit),
            isOptional: isOptional
        )
    }

    private func makeRecipe(
        title: String = "Test Recipe",
        servings: Int = 4,
        ingredients: [Ingredient] = []
    ) -> Recipe {
        Recipe(
            title: title,
            servings: servings,
            ingredients: ingredients
        )
    }

    private func makePlan(
        name: String = "Test Plan",
        meals: [PlannedMeal] = []
    ) -> MealPlan {
        let plan = MealPlan(name: name, startDate: .now, endDate: .now)
        plan.meals = meals
        return plan
    }

    private func makeMeal(recipe: Recipe, servings: Int) -> PlannedMeal {
        PlannedMeal(mealType: .dinner, date: .now, recipe: recipe, servings: servings)
    }

    // MARK: - Basic Generation

    func testGenerateListFromSingleMealPlan() {
        let recipe = makeRecipe(
            servings: 4,
            ingredients: [
                makeIngredient(name: "Chicken", category: .protein, quantity: 2.0, unit: .pound),
                makeIngredient(name: "Garlic", category: .vegetable, quantity: 4.0, unit: .clove),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 4)
        let plan = makePlan(meals: [meal])

        let list = ShoppingListGenerator.generateList(from: plan)

        XCTAssertEqual(list.name, "Shopping — Test Plan")
        XCTAssertEqual(list.items.count, 2)

        let chickenItem = list.items.first { $0.name == "Chicken" }
        XCTAssertNotNil(chickenItem)
        XCTAssertEqual(chickenItem?.quantity, 2.0, accuracy: 0.001)
        XCTAssertEqual(chickenItem?.unit, .pound)

        let garlicItem = list.items.first { $0.name == "Garlic" }
        XCTAssertNotNil(garlicItem)
        XCTAssertEqual(garlicItem?.quantity, 4.0, accuracy: 0.001)
    }

    func testGenerateListUsesCustomName() {
        let plan = makePlan(meals: [])
        let list = ShoppingListGenerator.generateList(from: plan, name: "My Custom List")
        XCTAssertEqual(list.name, "My Custom List")
    }

    func testGenerateListDefaultNameIncludesPlanName() {
        let plan = makePlan(name: "Week 1", meals: [])
        let list = ShoppingListGenerator.generateList(from: plan)
        XCTAssertEqual(list.name, "Shopping — Week 1")
    }

    // MARK: - Serving Scaling

    func testGenerateListScalesIngredientsByServings() {
        let recipe = makeRecipe(
            servings: 2,
            ingredients: [
                makeIngredient(name: "Rice", category: .grain, quantity: 1.0, unit: .cup),
            ]
        )
        // Meal requests 4 servings from a recipe that serves 2, so scale = 2x
        let meal = makeMeal(recipe: recipe, servings: 4)
        let plan = makePlan(meals: [meal])

        let list = ShoppingListGenerator.generateList(from: plan)

        let riceItem = list.items.first { $0.name == "Rice" }
        XCTAssertNotNil(riceItem)
        XCTAssertEqual(riceItem?.quantity, 2.0, accuracy: 0.001)
    }

    // MARK: - Merging Duplicates

    func testGenerateListMergesDuplicateIngredientsSameUnit() {
        let recipe1 = makeRecipe(
            title: "Recipe A",
            servings: 1,
            ingredients: [
                makeIngredient(name: "Onion", category: .vegetable, quantity: 2.0, unit: .piece),
            ]
        )
        let recipe2 = makeRecipe(
            title: "Recipe B",
            servings: 1,
            ingredients: [
                makeIngredient(name: "Onion", category: .vegetable, quantity: 3.0, unit: .piece),
            ]
        )

        let meal1 = makeMeal(recipe: recipe1, servings: 1)
        let meal2 = makeMeal(recipe: recipe2, servings: 1)
        let plan = makePlan(meals: [meal1, meal2])

        let list = ShoppingListGenerator.generateList(from: plan)

        let onionItems = list.items.filter { $0.name.lowercased().contains("onion") }
        XCTAssertEqual(onionItems.count, 1, "Duplicate ingredients should merge into one item")
        XCTAssertEqual(onionItems.first?.quantity, 5.0, accuracy: 0.001)
    }

    func testGenerateListMergesCaseInsensitive() {
        let recipe1 = makeRecipe(
            title: "Recipe A",
            servings: 1,
            ingredients: [
                makeIngredient(name: "Salt", category: .spice, quantity: 1.0, unit: .teaspoon),
            ]
        )
        let recipe2 = makeRecipe(
            title: "Recipe B",
            servings: 1,
            ingredients: [
                makeIngredient(name: "salt", category: .spice, quantity: 0.5, unit: .teaspoon),
            ]
        )

        let meal1 = makeMeal(recipe: recipe1, servings: 1)
        let meal2 = makeMeal(recipe: recipe2, servings: 1)
        let plan = makePlan(meals: [meal1, meal2])

        let list = ShoppingListGenerator.generateList(from: plan)

        let saltItems = list.items.filter {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces) == "salt"
        }
        XCTAssertEqual(saltItems.count, 1, "Case-different ingredients should merge")
        XCTAssertEqual(saltItems.first?.quantity, 1.5, accuracy: 0.001)
    }

    // MARK: - Optional Ingredients

    func testGenerateListExcludesOptionalIngredients() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Pasta", category: .grain, quantity: 200.0, unit: .gram),
                makeIngredient(name: "Parsley", category: .herb, quantity: 1.0, unit: .tablespoon, isOptional: true),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 1)
        let plan = makePlan(meals: [meal])

        let list = ShoppingListGenerator.generateList(from: plan)

        XCTAssertEqual(list.items.count, 1)
        XCTAssertEqual(list.items.first?.name, "Pasta")
    }

    // MARK: - Pantry Subtraction

    func testGenerateListSubtractsPantryStock() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Flour", category: .grain, quantity: 3.0, unit: .cup),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 1)
        let plan = makePlan(meals: [meal])

        let pantry = [
            PantryItem(name: "Flour", category: .grain, quantity: 1.0, unit: .cup)
        ]

        let list = ShoppingListGenerator.generateList(from: plan, pantryItems: pantry)

        let flourItem = list.items.first { $0.name == "Flour" }
        XCTAssertNotNil(flourItem)
        XCTAssertEqual(flourItem?.quantity, 2.0, accuracy: 0.001)
    }

    func testGenerateListRemovesItemFullyCoveredByPantry() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Butter", category: .dairy, quantity: 2.0, unit: .tablespoon),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 1)
        let plan = makePlan(meals: [meal])

        let pantry = [
            PantryItem(name: "Butter", category: .dairy, quantity: 5.0, unit: .tablespoon)
        ]

        let list = ShoppingListGenerator.generateList(from: plan, pantryItems: pantry)

        let butterItem = list.items.first { $0.name == "Butter" }
        XCTAssertNil(butterItem, "Items fully covered by pantry should be excluded")
    }

    func testGenerateListDoesNotSubtractDifferentUnits() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Milk", category: .dairy, quantity: 2.0, unit: .cup),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 1)
        let plan = makePlan(meals: [meal])

        let pantry = [
            PantryItem(name: "Milk", category: .dairy, quantity: 500.0, unit: .milliliter)
        ]

        let list = ShoppingListGenerator.generateList(from: plan, pantryItems: pantry)

        let milkItem = list.items.first { $0.name == "Milk" }
        XCTAssertNotNil(milkItem)
        XCTAssertEqual(milkItem?.quantity, 2.0, accuracy: 0.001,
                       "Should keep full amount when units differ")
    }

    // MARK: - Store Section Mapping

    func testGenerateListAssignsCorrectStoreSection() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Chicken Breast", category: .protein, quantity: 1.0, unit: .pound),
                makeIngredient(name: "Broccoli", category: .vegetable, quantity: 2.0, unit: .cup),
                makeIngredient(name: "Cheddar", category: .dairy, quantity: 1.0, unit: .cup),
                makeIngredient(name: "Cumin", category: .spice, quantity: 1.0, unit: .teaspoon),
            ]
        )
        let meal = makeMeal(recipe: recipe, servings: 1)
        let plan = makePlan(meals: [meal])

        let list = ShoppingListGenerator.generateList(from: plan)

        let chicken = list.items.first { $0.name == "Chicken Breast" }
        XCTAssertEqual(chicken?.storeSection, .meat)

        let broccoli = list.items.first { $0.name == "Broccoli" }
        XCTAssertEqual(broccoli?.storeSection, .produce)

        let cheddar = list.items.first { $0.name == "Cheddar" }
        XCTAssertEqual(cheddar?.storeSection, .dairy)

        let cumin = list.items.first { $0.name == "Cumin" }
        XCTAssertEqual(cumin?.storeSection, .spices)
    }

    // MARK: - Empty Plan

    func testGenerateListFromEmptyPlanProducesEmptyList() {
        let plan = makePlan(meals: [])
        let list = ShoppingListGenerator.generateList(from: plan)
        XCTAssertTrue(list.items.isEmpty)
    }

    // MARK: - Meal with nil recipe

    func testGenerateListSkipsMealWithNilRecipe() {
        let mealWithoutRecipe = PlannedMeal(mealType: .lunch, date: .now, recipe: nil, servings: 2)
        let plan = makePlan(meals: [mealWithoutRecipe])
        let list = ShoppingListGenerator.generateList(from: plan)
        XCTAssertTrue(list.items.isEmpty)
    }
}

// MARK: - PantryDeductionService Tests

final class PantryDeductionServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeIngredient(
        name: String,
        category: IngredientCategory = .vegetable,
        quantity: Double,
        unit: MeasurementUnit,
        isOptional: Bool = false
    ) -> Ingredient {
        Ingredient(
            name: name,
            category: category,
            amount: IngredientAmount(quantity: quantity, unit: unit),
            isOptional: isOptional
        )
    }

    private func makeRecipe(
        servings: Int = 4,
        ingredients: [Ingredient] = []
    ) -> Recipe {
        Recipe(title: "Test Recipe", servings: servings, ingredients: ingredients)
    }

    // MARK: - Basic Deduction

    func testDeductAfterCookingReducesPantryQuantity() {
        let recipe = makeRecipe(
            servings: 4,
            ingredients: [
                makeIngredient(name: "Chicken", category: .protein, quantity: 2.0, unit: .pound),
            ]
        )
        let pantry = [
            PantryItem(name: "Chicken", category: .protein, quantity: 5.0, unit: .pound)
        ]

        let fullyConsumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 4,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 3.0, accuracy: 0.001)
        XCTAssertTrue(fullyConsumed.isEmpty)
    }

    func testDeductAfterCookingScalesByServings() {
        // Recipe serves 4 and needs 2 cups of rice. Cooking 2 servings -> scale 0.5 -> needs 1 cup.
        let recipe = makeRecipe(
            servings: 4,
            ingredients: [
                makeIngredient(name: "Rice", category: .grain, quantity: 2.0, unit: .cup),
            ]
        )
        let pantry = [
            PantryItem(name: "Rice", category: .grain, quantity: 3.0, unit: .cup)
        ]

        PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 2,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 2.0, accuracy: 0.001)
    }

    // MARK: - Fully Consumed

    func testDeductAfterCookingReturnsFullyConsumedItems() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Egg", category: .protein, quantity: 3.0, unit: .piece),
            ]
        )
        let pantry = [
            PantryItem(name: "Egg", category: .protein, quantity: 3.0, unit: .piece)
        ]

        let fullyConsumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 0.0, accuracy: 0.001)
        XCTAssertEqual(fullyConsumed.count, 1)
        XCTAssertEqual(fullyConsumed.first?.name, "Egg")
    }

    func testDeductAfterCookingClampsToZero() {
        // Pantry has less than needed -- should clamp to 0, not go negative.
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Butter", category: .dairy, quantity: 4.0, unit: .tablespoon),
            ]
        )
        let pantry = [
            PantryItem(name: "Butter", category: .dairy, quantity: 1.0, unit: .tablespoon)
        ]

        let fullyConsumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 0.0, accuracy: 0.001)
        XCTAssertEqual(fullyConsumed.count, 1)
    }

    // MARK: - Optional Ingredients

    func testDeductAfterCookingSkipsOptionalIngredients() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Cilantro", category: .herb, quantity: 1.0, unit: .tablespoon, isOptional: true),
            ]
        )
        let pantry = [
            PantryItem(name: "Cilantro", category: .herb, quantity: 5.0, unit: .tablespoon)
        ]

        PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 5.0, accuracy: 0.001,
                       "Optional ingredients should not be deducted")
    }

    // MARK: - Case-Insensitive Matching

    func testDeductAfterCookingMatchesCaseInsensitive() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Olive Oil", category: .oil, quantity: 2.0, unit: .tablespoon),
            ]
        )
        let pantry = [
            PantryItem(name: "olive oil", category: .oil, quantity: 10.0, unit: .tablespoon)
        ]

        PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 8.0, accuracy: 0.001)
    }

    // MARK: - No Matching Pantry Item

    func testDeductAfterCookingIgnoresMissingPantryItems() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Saffron", category: .spice, quantity: 1.0, unit: .pinch),
            ]
        )
        let pantry: [PantryItem] = []

        let fullyConsumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertTrue(fullyConsumed.isEmpty)
    }

    // MARK: - Multiple Ingredients

    func testDeductAfterCookingHandlesMultipleIngredients() {
        let recipe = makeRecipe(
            servings: 2,
            ingredients: [
                makeIngredient(name: "Flour", category: .grain, quantity: 2.0, unit: .cup),
                makeIngredient(name: "Sugar", category: .sweetener, quantity: 1.0, unit: .cup),
                makeIngredient(name: "Egg", category: .protein, quantity: 2.0, unit: .piece),
            ]
        )
        let pantry = [
            PantryItem(name: "Flour", category: .grain, quantity: 5.0, unit: .cup),
            PantryItem(name: "Sugar", category: .sweetener, quantity: 0.5, unit: .cup),
            PantryItem(name: "Egg", category: .protein, quantity: 6.0, unit: .piece),
        ]

        // Cooking 2 servings (same as recipe), so scale = 1.0
        let fullyConsumed = PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 2,
            pantryItems: pantry
        )

        XCTAssertEqual(pantry[0].quantity, 3.0, accuracy: 0.001, "Flour: 5 - 2 = 3")
        XCTAssertEqual(pantry[1].quantity, 0.0, accuracy: 0.001, "Sugar: 0.5 - 1.0 clamped to 0")
        XCTAssertEqual(pantry[2].quantity, 4.0, accuracy: 0.001, "Egg: 6 - 2 = 4")

        XCTAssertEqual(fullyConsumed.count, 1)
        XCTAssertEqual(fullyConsumed.first?.name, "Sugar")
    }

    // MARK: - lastUsed Updated

    func testDeductAfterCookingUpdatesLastUsed() {
        let recipe = makeRecipe(
            servings: 1,
            ingredients: [
                makeIngredient(name: "Salt", category: .spice, quantity: 1.0, unit: .teaspoon),
            ]
        )
        let pantry = [
            PantryItem(name: "Salt", category: .spice, quantity: 10.0, unit: .teaspoon)
        ]

        XCTAssertNil(pantry[0].lastUsed)

        PantryDeductionService.deductAfterCooking(
            recipe: recipe,
            servingsCooked: 1,
            pantryItems: pantry
        )

        XCTAssertNotNil(pantry[0].lastUsed)
    }
}

// MARK: - NutritionTracker Tests

final class NutritionTrackerTests: XCTestCase {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeRecipe(
        title: String = "Test Recipe",
        nutritionalInfo: NutritionalInfo? = nil,
        cookingLogDates: [Date] = []
    ) -> Recipe {
        let recipe = Recipe(
            title: title,
            nutritionalInfo: nutritionalInfo
        )
        for date in cookingLogDates {
            recipe.cookingLog.append(CookingLogEntry(date: date))
        }
        return recipe
    }

    private func date(daysAgo: Int, from reference: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
    }

    // MARK: - calculateDays

    func testCalculateDaysReturnsCorrectNumberOfDays() {
        let ref = Date()
        let days = NutritionTracker.calculateDays(recipes: [], period: .week, referenceDate: ref)
        XCTAssertEqual(days.count, 7)
    }

    func testCalculateDaysForDayPeriodReturnsSingleDay() {
        let ref = Date()
        let days = NutritionTracker.calculateDays(recipes: [], period: .day, referenceDate: ref)
        XCTAssertEqual(days.count, 1)
    }

    func testCalculateDaysForMonthPeriodReturns30Days() {
        let ref = Date()
        let days = NutritionTracker.calculateDays(recipes: [], period: .month, referenceDate: ref)
        XCTAssertEqual(days.count, 30)
    }

    func testCalculateDaysTalliesCaloriesForCookedRecipes() {
        let ref = Date()
        let today = calendar.startOfDay(for: ref)

        let recipe = makeRecipe(
            nutritionalInfo: NutritionalInfo(
                calories: 500,
                proteinGrams: 30,
                carbsGrams: 50,
                fatGrams: 20,
                fiberGrams: 5,
                sugarGrams: 10
            ),
            cookingLogDates: [
                // Two cooking events today
                today.addingTimeInterval(3600),
                today.addingTimeInterval(7200),
            ]
        )

        let days = NutritionTracker.calculateDays(
            recipes: [recipe],
            period: .day,
            referenceDate: ref
        )

        XCTAssertEqual(days.count, 1)
        let todayNutrition = days[0]
        XCTAssertEqual(todayNutrition.calories, 1000, accuracy: 0.001, "500 cal x 2 logs")
        XCTAssertEqual(todayNutrition.protein, 60, accuracy: 0.001, "30g x 2 logs")
        XCTAssertEqual(todayNutrition.carbs, 100, accuracy: 0.001, "50g x 2 logs")
        XCTAssertEqual(todayNutrition.fat, 40, accuracy: 0.001, "20g x 2 logs")
        XCTAssertEqual(todayNutrition.recipesCooked, 2)
    }

    func testCalculateDaysDoesNotCountRecipesWithoutNutrition() {
        let ref = Date()
        let today = calendar.startOfDay(for: ref)

        let recipe = makeRecipe(
            nutritionalInfo: nil,
            cookingLogDates: [today.addingTimeInterval(3600)]
        )

        let days = NutritionTracker.calculateDays(
            recipes: [recipe],
            period: .day,
            referenceDate: ref
        )

        XCTAssertEqual(days[0].recipesCooked, 1)
        XCTAssertEqual(days[0].calories, 0, accuracy: 0.001,
                       "No nutritional info means zero calories")
    }

    func testCalculateDaysAssignsLogsToCorrectDay() {
        let ref = Date()
        let today = calendar.startOfDay(for: ref)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let recipe = makeRecipe(
            nutritionalInfo: NutritionalInfo(
                calories: 300,
                proteinGrams: 20,
                carbsGrams: 30,
                fatGrams: 10,
                fiberGrams: 3,
                sugarGrams: 5
            ),
            cookingLogDates: [
                yesterday.addingTimeInterval(3600),   // yesterday
                today.addingTimeInterval(3600),        // today
                today.addingTimeInterval(7200),        // today
            ]
        )

        let days = NutritionTracker.calculateDays(
            recipes: [recipe],
            period: .week,
            referenceDate: ref
        )

        // Last element is today (offset=0), second-to-last is yesterday (offset=1)
        let todayEntry = days.last!
        let yesterdayEntry = days[days.count - 2]

        XCTAssertEqual(todayEntry.recipesCooked, 2)
        XCTAssertEqual(todayEntry.calories, 600, accuracy: 0.001)

        XCTAssertEqual(yesterdayEntry.recipesCooked, 1)
        XCTAssertEqual(yesterdayEntry.calories, 300, accuracy: 0.001)
    }

    func testCalculateDaysEmptyRecipesProducesZeroDays() {
        let ref = Date()
        let days = NutritionTracker.calculateDays(recipes: [], period: .week, referenceDate: ref)

        XCTAssertEqual(days.count, 7)
        for day in days {
            XCTAssertEqual(day.calories, 0, accuracy: 0.001)
            XCTAssertEqual(day.recipesCooked, 0)
        }
    }

    // MARK: - totals

    func testTotalsAggregatesAllDays() {
        let days = [
            NutritionTracker.DayNutrition(
                date: Date(), calories: 500, protein: 30, carbs: 60, fat: 20, recipesCooked: 2
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 700, protein: 40, carbs: 80, fat: 25, recipesCooked: 3
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 0, protein: 0, carbs: 0, fat: 0, recipesCooked: 0
            ),
        ]

        let totals = NutritionTracker.totals(from: days)

        XCTAssertEqual(totals.totalCalories, 1200, accuracy: 0.001)
        XCTAssertEqual(totals.totalProtein, 70, accuracy: 0.001)
        XCTAssertEqual(totals.totalCarbs, 140, accuracy: 0.001)
        XCTAssertEqual(totals.totalFat, 45, accuracy: 0.001)
    }

    func testTotalsAveragesOnlyActiveDays() {
        // 2 active days + 1 inactive day -> averages should divide by 2
        let days = [
            NutritionTracker.DayNutrition(
                date: Date(), calories: 600, protein: 40, carbs: 70, fat: 20, recipesCooked: 2
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 400, protein: 20, carbs: 50, fat: 15, recipesCooked: 1
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 0, protein: 0, carbs: 0, fat: 0, recipesCooked: 0
            ),
        ]

        let totals = NutritionTracker.totals(from: days)

        XCTAssertEqual(totals.days, 2, "Only active days should be counted")
        XCTAssertEqual(totals.avgCaloriesPerDay, 500, accuracy: 0.001, "(600+400)/2")
        XCTAssertEqual(totals.avgProteinPerDay, 30, accuracy: 0.001, "(40+20)/2")
        XCTAssertEqual(totals.avgCarbsPerDay, 60, accuracy: 0.001, "(70+50)/2")
        XCTAssertEqual(totals.avgFatPerDay, 17.5, accuracy: 0.001, "(20+15)/2")
    }

    func testTotalsWithNoActiveDaysUsesMinimumDenominatorOfOne() {
        let days = [
            NutritionTracker.DayNutrition(
                date: Date(), calories: 0, protein: 0, carbs: 0, fat: 0, recipesCooked: 0
            ),
        ]

        let totals = NutritionTracker.totals(from: days)

        XCTAssertEqual(totals.days, 1, "Should use max(0, 1) = 1 to avoid division by zero")
        XCTAssertEqual(totals.avgCaloriesPerDay, 0, accuracy: 0.001)
    }

    func testTotalsWithEmptyDaysArray() {
        let totals = NutritionTracker.totals(from: [])

        XCTAssertEqual(totals.totalCalories, 0, accuracy: 0.001)
        XCTAssertEqual(totals.totalProtein, 0, accuracy: 0.001)
        XCTAssertEqual(totals.days, 1)
        XCTAssertEqual(totals.avgCaloriesPerDay, 0, accuracy: 0.001)
    }

    func testTotalsWithAllActiveDays() {
        let days = [
            NutritionTracker.DayNutrition(
                date: Date(), calories: 300, protein: 15, carbs: 40, fat: 10, recipesCooked: 1
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 600, protein: 35, carbs: 80, fat: 20, recipesCooked: 2
            ),
            NutritionTracker.DayNutrition(
                date: Date(), calories: 900, protein: 55, carbs: 100, fat: 30, recipesCooked: 3
            ),
        ]

        let totals = NutritionTracker.totals(from: days)

        XCTAssertEqual(totals.days, 3)
        XCTAssertEqual(totals.totalCalories, 1800, accuracy: 0.001)
        XCTAssertEqual(totals.avgCaloriesPerDay, 600, accuracy: 0.001, "1800/3")
        XCTAssertEqual(totals.avgProteinPerDay, 35, accuracy: 0.001, "105/3")
    }
}
