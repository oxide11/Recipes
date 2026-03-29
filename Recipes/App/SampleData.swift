import Foundation
import SwiftData

// MARK: - Sample Data

/// Populates a ModelContext with realistic test data for every major feature.
enum SampleData {

    // MARK: - Public Entry Point

    @MainActor
    static func populate(_ context: ModelContext) {
        let recipes = insertRecipes(into: context)
        let pantryItems = insertPantryItems(into: context)
        insertMealPlan(into: context, recipes: recipes)
        insertGroceryList(into: context)
        insertRestaurantJournal(into: context)
        insertUserProfile(into: context)
        _ = pantryItems // used by NoWaste matching at runtime
    }

    // MARK: - Recipes

    @MainActor
    private static func insertRecipes(into context: ModelContext) -> [Recipe] {
        let recipes = [
            makePastaAllaGricia(),
            makeTacosCarnitas(),
            makeMisoRamen(),
            makeGreekSalad(),
            makeChickenTikkaMasala(),
            makeBananaBread(),
        ]
        for recipe in recipes { context.insert(recipe) }
        return recipes
    }

    // 1 — Pasta alla Gricia
    private static func makePastaAllaGricia() -> Recipe {
        let recipe = Recipe(
            title: "Pasta alla Gricia",
            summary: "Roman classic — the ancestor of carbonara. Just guanciale, pecorino, pepper, and pasta.",
            cuisine: .italian,
            difficulty: .intermediate,
            servings: 4,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Bring a large pot of salted water to a boil."),
                RecipeDirection(stepNumber: 2, instruction: "Cut guanciale into ½-inch strips. Cook in a cold skillet over medium heat until fat renders and edges crisp, about 8 minutes.", timer: TimerStep(durationSeconds: 480, label: "Render guanciale")),
                RecipeDirection(stepNumber: 3, instruction: "Cook rigatoni until 2 minutes short of al dente. Reserve 2 cups pasta water before draining.", timer: TimerStep(durationSeconds: 600, label: "Cook pasta")),
                RecipeDirection(stepNumber: 4, instruction: "Toss pasta into the guanciale skillet. Add ½ cup pasta water and toss vigorously over medium heat until glossy."),
                RecipeDirection(stepNumber: 5, instruction: "Remove from heat. Add pecorino in three additions, tossing and adding splashes of pasta water between each, until a creamy sauce forms."),
                RecipeDirection(stepNumber: 6, instruction: "Finish with generous cracked black pepper. Serve immediately."),
            ],
            nutritionalInfo: NutritionalInfo(calories: 620, proteinGrams: 22, carbsGrams: 65, fatGrams: 30, fiberGrams: 3, sugarGrams: 2, sodiumMg: 780),
            tags: ["pasta", "roman", "quick", "comfort"]
        )
        recipe.isFavorite = true

        // Ingredients (created separately so SwiftData manages them)
        let ingredients = [
            Ingredient(name: "Rigatoni", category: .grain, amount: IngredientAmount(quantity: 400, unit: .gram)),
            Ingredient(name: "Guanciale", category: .protein, amount: IngredientAmount(quantity: 200, unit: .gram)),
            Ingredient(name: "Pecorino Romano", category: .dairy, amount: IngredientAmount(quantity: 150, unit: .gram), isDairyFree: false),
            Ingredient(name: "Black pepper", category: .spice, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
        ]
        recipe.ingredients = ingredients

        // Cooking log entries
        let log1 = CookingLogEntry(
            date: Calendar.current.date(byAdding: .day, value: -14, to: .now)!,
            prepTimeMinutes: 10, cookTimeMinutes: 22, rating: 5,
            notes: "Perfect crisp on the guanciale. Used extra pepper."
        )
        let log2 = CookingLogEntry(
            date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
            prepTimeMinutes: 8, cookTimeMinutes: 20, rating: 4,
            notes: "Slightly over-salted — use less pasta water next time.",
            substitutionsMade: ["Pancetta for guanciale"]
        )
        recipe.cookingLog = [log1, log2]

        // Variation
        let variation = RecipeVariation(
            name: "Cacio e Pepe Style",
            description: "Skip the guanciale for a vegetarian version. Double the pecorino.",
            ingredientOverrides: [
                IngredientOverride(originalIngredient: "Guanciale", replacementIngredient: "Extra virgin olive oil", replacementAmount: IngredientAmount(quantity: 2, unit: .tablespoon)),
            ],
            dietaryRestrictions: [.vegetarian]
        )
        recipe.variations = [variation]

        return recipe
    }

    // 2 — Tacos de Carnitas
    private static func makeTacosCarnitas() -> Recipe {
        let recipe = Recipe(
            title: "Tacos de Carnitas",
            summary: "Slow-braised pork shoulder shredded and crisped, served in warm corn tortillas with fresh salsa.",
            cuisine: .mexican,
            difficulty: .intermediate,
            servings: 8,
            prepTimeMinutes: 20,
            cookTimeMinutes: 180,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Cut pork shoulder into 3-inch chunks. Season generously with salt, cumin, and oregano."),
                RecipeDirection(stepNumber: 2, instruction: "Place pork in a Dutch oven with halved orange, bay leaves, and enough water to just cover. Bring to a boil, then reduce to a gentle simmer.", timer: TimerStep(durationSeconds: 9000, label: "Braise pork")),
                RecipeDirection(stepNumber: 3, instruction: "When pork is fall-apart tender, drain liquid. Shred meat with two forks. Spread on a baking sheet."),
                RecipeDirection(stepNumber: 4, instruction: "Broil shredded pork for 4-5 minutes until edges are crispy and golden.", timer: TimerStep(durationSeconds: 270, label: "Crisp under broiler"),
                    safeTemperature: SafeTemperature(protein: "Pork", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA minimum for whole cuts")),
                RecipeDirection(stepNumber: 5, instruction: "Warm tortillas. Serve carnitas with diced onion, cilantro, and salsa verde."),
            ],
            nutritionalInfo: NutritionalInfo(calories: 380, proteinGrams: 32, carbsGrams: 28, fatGrams: 16, fiberGrams: 4, sugarGrams: 3),
            safeTemperatures: [SafeTemperature(protein: "Pork", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3)],
            tags: ["mexican", "slow-cook", "crowd-pleaser", "pork"]
        )
        recipe.ingredients = [
            Ingredient(name: "Pork shoulder", category: .protein, amount: IngredientAmount(quantity: 3, unit: .pound)),
            Ingredient(name: "Orange", category: .fruit, amount: IngredientAmount(quantity: 1, unit: .whole)),
            Ingredient(name: "Cumin", category: .spice, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Dried oregano", category: .herb, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Bay leaves", category: .herb, amount: IngredientAmount(quantity: 2, unit: .piece), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Corn tortillas", category: .grain, amount: IngredientAmount(quantity: 16, unit: .piece), isGlutenFree: true),
            Ingredient(name: "White onion", category: .vegetable, amount: IngredientAmount(quantity: 1, unit: .whole), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Fresh cilantro", category: .herb, amount: IngredientAmount(quantity: 1, unit: .bunch), isGlutenFree: true, isVegan: true),
        ]
        recipe.cookingLog = [
            CookingLogEntry(
                date: Calendar.current.date(byAdding: .day, value: -30, to: .now)!,
                prepTimeMinutes: 25, cookTimeMinutes: 195, rating: 5,
                notes: "Best carnitas yet. The broil step is essential for texture."
            ),
        ]
        return recipe
    }

    // 3 — Miso Ramen
    private static func makeMisoRamen() -> Recipe {
        let recipe = Recipe(
            title: "Weeknight Miso Ramen",
            summary: "A rich miso-based broth with soft-boiled egg, noodles, and seasonal toppings. Quick enough for a Tuesday.",
            cuisine: .japanese,
            difficulty: .beginner,
            servings: 2,
            prepTimeMinutes: 10,
            cookTimeMinutes: 15,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Bring eggs to a boil. Once boiling, cook for exactly 6½ minutes for a jammy yolk. Transfer to ice water immediately.", timer: TimerStep(durationSeconds: 390, label: "Soft-boil eggs")),
                RecipeDirection(stepNumber: 2, instruction: "Sauté minced garlic and ginger in sesame oil for 1 minute. Add chicken stock and bring to a simmer."),
                RecipeDirection(stepNumber: 3, instruction: "Whisk in white miso paste until dissolved. Do not let the broth boil after adding miso."),
                RecipeDirection(stepNumber: 4, instruction: "Cook ramen noodles according to package directions. Drain and divide between bowls.", timer: TimerStep(durationSeconds: 180, label: "Cook noodles")),
                RecipeDirection(stepNumber: 5, instruction: "Ladle broth over noodles. Top with halved egg, sliced scallions, corn, nori, and a drizzle of chili oil."),
            ],
            nutritionalInfo: NutritionalInfo(calories: 480, proteinGrams: 24, carbsGrams: 52, fatGrams: 20, fiberGrams: 4, sugarGrams: 6),
            tags: ["ramen", "quick", "comfort", "soup"]
        )
        recipe.ingredients = [
            Ingredient(name: "Ramen noodles", category: .grain, amount: IngredientAmount(quantity: 200, unit: .gram)),
            Ingredient(name: "White miso paste", category: .condiment, amount: IngredientAmount(quantity: 3, unit: .tablespoon)),
            Ingredient(name: "Chicken stock", category: .liquid, amount: IngredientAmount(quantity: 4, unit: .cup)),
            Ingredient(name: "Eggs", category: .dairy, amount: IngredientAmount(quantity: 2, unit: .piece)),
            Ingredient(name: "Garlic", category: .vegetable, amount: IngredientAmount(quantity: 3, unit: .clove), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Fresh ginger", category: .vegetable, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Sesame oil", category: .oil, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Scallions", category: .vegetable, amount: IngredientAmount(quantity: 3, unit: .piece), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Nori sheets", category: .vegetable, amount: IngredientAmount(quantity: 2, unit: .piece), isOptional: true, isGlutenFree: true, isVegan: true),
            Ingredient(name: "Chili oil", category: .condiment, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isOptional: true, isGlutenFree: true, isVegan: true),
        ]
        recipe.cookingLog = [
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -7, to: .now)!, prepTimeMinutes: 10, cookTimeMinutes: 15, rating: 4, notes: "Quick and satisfying."),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -21, to: .now)!, prepTimeMinutes: 12, cookTimeMinutes: 18, rating: 4),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -45, to: .now)!, prepTimeMinutes: 10, cookTimeMinutes: 14, rating: 5, notes: "Added corn — great addition."),
        ]
        return recipe
    }

    // 4 — Greek Salad
    private static func makeGreekSalad() -> Recipe {
        let recipe = Recipe(
            title: "Classic Greek Salad",
            summary: "Horiatiki — the real Greek salad. No lettuce. Just ripe tomatoes, cucumber, onion, olives, and a slab of feta.",
            cuisine: .greek,
            difficulty: .beginner,
            servings: 4,
            prepTimeMinutes: 15,
            cookTimeMinutes: 0,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Cut tomatoes into irregular wedges. Slice cucumber into half-moons. Slice red onion into thin rings."),
                RecipeDirection(stepNumber: 2, instruction: "Arrange vegetables on a platter. Scatter Kalamata olives and green pepper rings on top."),
                RecipeDirection(stepNumber: 3, instruction: "Place a thick slab of feta cheese in the center. Do not crumble — this is traditional."),
                RecipeDirection(stepNumber: 4, instruction: "Drizzle generously with extra virgin olive oil and a splash of red wine vinegar. Sprinkle with dried oregano and sea salt."),
            ],
            nutritionalInfo: NutritionalInfo(calories: 280, proteinGrams: 8, carbsGrams: 12, fatGrams: 22, fiberGrams: 3, sugarGrams: 7),
            dietaryRestrictions: [.vegetarian, .glutenFree],
            tags: ["salad", "no-cook", "summer", "vegetarian", "healthy"]
        )
        recipe.ingredients = [
            Ingredient(name: "Ripe tomatoes", category: .vegetable, amount: IngredientAmount(quantity: 4, unit: .piece), seasonalAvailability: [.summer, .autumn], isGlutenFree: true, isVegan: true),
            Ingredient(name: "English cucumber", category: .vegetable, amount: IngredientAmount(quantity: 1, unit: .whole), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Red onion", category: .vegetable, amount: IngredientAmount(quantity: 0.5, unit: .whole), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Kalamata olives", category: .vegetable, amount: IngredientAmount(quantity: 0.5, unit: .cup), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Feta cheese", category: .dairy, amount: IngredientAmount(quantity: 200, unit: .gram), isGlutenFree: true),
            Ingredient(name: "Extra virgin olive oil", category: .oil, amount: IngredientAmount(quantity: 3, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Red wine vinegar", category: .condiment, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Dried oregano", category: .herb, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true, isVegan: true),
        ]
        return recipe
    }

    // 5 — Chicken Tikka Masala
    private static func makeChickenTikkaMasala() -> Recipe {
        let recipe = Recipe(
            title: "Chicken Tikka Masala",
            summary: "Yogurt-marinated chicken in a creamy, spiced tomato sauce. Serve with basmati rice and warm naan.",
            cuisine: .indian,
            difficulty: .intermediate,
            servings: 4,
            prepTimeMinutes: 30,
            cookTimeMinutes: 35,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Mix yogurt with garam masala, turmeric, cumin, chili powder, salt, lemon juice, and garlic. Add chicken and marinate at least 30 minutes.", timer: TimerStep(durationSeconds: 1800, label: "Marinate chicken")),
                RecipeDirection(stepNumber: 2, instruction: "Thread chicken onto skewers or place on a sheet pan. Broil or grill until charred, about 12 minutes, turning once.", timer: TimerStep(durationSeconds: 720, label: "Broil chicken"),
                    safeTemperature: SafeTemperature(protein: "Chicken", minimumFahrenheit: 165, minimumCelsius: 74, notes: "USDA minimum for poultry")),
                RecipeDirection(stepNumber: 3, instruction: "In a large pan, sauté diced onion until softened. Add garlic, ginger, garam masala, and cumin. Cook 1 minute."),
                RecipeDirection(stepNumber: 4, instruction: "Add crushed tomatoes and simmer for 15 minutes until thickened.", timer: TimerStep(durationSeconds: 900, label: "Simmer sauce")),
                RecipeDirection(stepNumber: 5, instruction: "Stir in heavy cream and add the cooked chicken. Simmer gently for 5 more minutes. Garnish with cilantro."),
            ],
            nutritionalInfo: NutritionalInfo(calories: 520, proteinGrams: 38, carbsGrams: 18, fatGrams: 32, fiberGrams: 3, sugarGrams: 8, sodiumMg: 640),
            safeTemperatures: [SafeTemperature(protein: "Chicken", minimumFahrenheit: 165, minimumCelsius: 74)],
            tags: ["curry", "spicy", "crowd-pleaser", "chicken"]
        )
        recipe.isFavorite = true
        recipe.ingredients = [
            Ingredient(name: "Chicken thighs", category: .protein, amount: IngredientAmount(quantity: 1.5, unit: .pound)),
            Ingredient(name: "Plain yogurt", category: .dairy, amount: IngredientAmount(quantity: 1, unit: .cup)),
            Ingredient(name: "Garam masala", category: .spice, amount: IngredientAmount(quantity: 2, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Turmeric", category: .spice, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Cumin", category: .spice, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Crushed tomatoes", category: .vegetable, amount: IngredientAmount(quantity: 14, unit: .ounce), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Heavy cream", category: .dairy, amount: IngredientAmount(quantity: 0.5, unit: .cup)),
            Ingredient(name: "Yellow onion", category: .vegetable, amount: IngredientAmount(quantity: 1, unit: .whole), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Garlic", category: .vegetable, amount: IngredientAmount(quantity: 4, unit: .clove), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Fresh ginger", category: .vegetable, amount: IngredientAmount(quantity: 1, unit: .tablespoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Fresh cilantro", category: .herb, amount: IngredientAmount(quantity: 0.25, unit: .cup), isOptional: true, isGlutenFree: true, isVegan: true),
        ]
        recipe.cookingLog = [
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!, prepTimeMinutes: 35, cookTimeMinutes: 40, rating: 5, notes: "Family loved it. Used Greek yogurt."),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -20, to: .now)!, prepTimeMinutes: 30, cookTimeMinutes: 35, rating: 4),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -42, to: .now)!, prepTimeMinutes: 32, cookTimeMinutes: 38, rating: 5, notes: "Added kasuri methi at the end — incredible."),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -60, to: .now)!, prepTimeMinutes: 30, cookTimeMinutes: 35, rating: 4),
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -90, to: .now)!, prepTimeMinutes: 35, cookTimeMinutes: 40, rating: 5),
        ]
        return recipe
    }

    // 6 — Banana Bread
    private static func makeBananaBread() -> Recipe {
        let recipe = Recipe(
            title: "Brown Butter Banana Bread",
            summary: "The extra step of browning the butter transforms ordinary banana bread into something deeply nutty and caramelized.",
            cuisine: .american,
            difficulty: .beginner,
            servings: 8,
            prepTimeMinutes: 15,
            cookTimeMinutes: 55,
            directions: [
                RecipeDirection(stepNumber: 1, instruction: "Preheat oven to 350°F (175°C). Brown the butter in a saucepan over medium heat until fragrant and amber-colored, about 5 minutes. Let cool slightly.", timer: TimerStep(durationSeconds: 300, label: "Brown butter")),
                RecipeDirection(stepNumber: 2, instruction: "Mash bananas with a fork. Whisk in brown butter, sugar, egg, and vanilla until smooth."),
                RecipeDirection(stepNumber: 3, instruction: "Fold in flour, baking soda, and salt until just combined. Do not overmix."),
                RecipeDirection(stepNumber: 4, instruction: "Pour into a greased 9×5 loaf pan. Top with sliced banana and a sprinkle of flaky salt."),
                RecipeDirection(stepNumber: 5, instruction: "Bake until a toothpick inserted in the center comes out clean, about 50-55 minutes.", timer: TimerStep(durationSeconds: 3300, label: "Bake banana bread")),
            ],
            nutritionalInfo: NutritionalInfo(calories: 310, proteinGrams: 4, carbsGrams: 48, fatGrams: 12, fiberGrams: 2, sugarGrams: 28),
            dietaryRestrictions: [.vegetarian],
            tags: ["baking", "breakfast", "dessert", "banana"]
        )
        recipe.ingredients = [
            Ingredient(name: "Ripe bananas", category: .fruit, amount: IngredientAmount(quantity: 3, unit: .whole), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Unsalted butter", category: .dairy, amount: IngredientAmount(quantity: 0.5, unit: .cup)),
            Ingredient(name: "Brown sugar", category: .sweetener, amount: IngredientAmount(quantity: 0.75, unit: .cup), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Egg", category: .dairy, amount: IngredientAmount(quantity: 1, unit: .piece)),
            Ingredient(name: "Vanilla extract", category: .condiment, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true),
            Ingredient(name: "All-purpose flour", category: .grain, amount: IngredientAmount(quantity: 1.5, unit: .cup)),
            Ingredient(name: "Baking soda", category: .other, amount: IngredientAmount(quantity: 1, unit: .teaspoon), isGlutenFree: true, isVegan: true),
            Ingredient(name: "Walnuts", category: .nut, amount: IngredientAmount(quantity: 0.5, unit: .cup), isOptional: true, isGlutenFree: true, isVegan: true),
        ]
        recipe.cookingLog = [
            CookingLogEntry(date: Calendar.current.date(byAdding: .day, value: -10, to: .now)!, prepTimeMinutes: 15, cookTimeMinutes: 52, rating: 5, notes: "The brown butter makes all the difference."),
        ]
        return recipe
    }

    // MARK: - Pantry Items

    @MainActor
    private static func insertPantryItems(into context: ModelContext) -> [PantryItem] {
        let items = [
            PantryItem(name: "Rigatoni", category: .grain, quantity: 500, unit: .gram),
            PantryItem(name: "Eggs", category: .dairy, quantity: 8, unit: .piece, expirationDate: Calendar.current.date(byAdding: .day, value: 6, to: .now)),
            PantryItem(name: "Garlic", category: .vegetable, quantity: 1, unit: .whole, expirationDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)),
            PantryItem(name: "Fresh ginger", category: .vegetable, quantity: 1, unit: .piece, expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)),
            PantryItem(name: "Sesame oil", category: .oil, quantity: 250, unit: .milliliter),
            PantryItem(name: "White miso paste", category: .condiment, quantity: 300, unit: .gram, expirationDate: Calendar.current.date(byAdding: .month, value: 3, to: .now)),
            PantryItem(name: "Chicken stock", category: .liquid, quantity: 4, unit: .cup),
            PantryItem(name: "Cumin", category: .spice, quantity: 50, unit: .gram),
            PantryItem(name: "Garam masala", category: .spice, quantity: 40, unit: .gram),
            PantryItem(name: "Turmeric", category: .spice, quantity: 30, unit: .gram),
            PantryItem(name: "Extra virgin olive oil", category: .oil, quantity: 500, unit: .milliliter),
            PantryItem(name: "Red wine vinegar", category: .condiment, quantity: 250, unit: .milliliter),
            PantryItem(name: "All-purpose flour", category: .grain, quantity: 2, unit: .kilogram),
            PantryItem(name: "Brown sugar", category: .sweetener, quantity: 400, unit: .gram),
            PantryItem(name: "Ripe bananas", category: .fruit, quantity: 4, unit: .whole, expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)),
            PantryItem(name: "Unsalted butter", category: .dairy, quantity: 1, unit: .pound, expirationDate: Calendar.current.date(byAdding: .day, value: 21, to: .now)),
            PantryItem(name: "Ramen noodles", category: .grain, quantity: 400, unit: .gram),
            PantryItem(name: "Scallions", category: .vegetable, quantity: 5, unit: .piece, expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)),
        ]
        for item in items { context.insert(item) }
        return items
    }

    // MARK: - Meal Plan

    @MainActor
    private static func insertMealPlan(into context: ModelContext, recipes: [Recipe]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let startOfWeek = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7, to: today)!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!

        let plan = MealPlan(
            name: "This Week",
            startDate: startOfWeek,
            endDate: endOfWeek,
            calorieTarget: 2000,
            proteinTargetGrams: 120
        )
        context.insert(plan)

        // Spread some recipes across the week
        let meals = [
            PlannedMeal(mealType: .dinner, date: startOfWeek, recipe: recipes[0], servings: 2, notes: "Pasta night"),
            PlannedMeal(mealType: .lunch, date: calendar.date(byAdding: .day, value: 1, to: startOfWeek)!, recipe: recipes[3], servings: 2),
            PlannedMeal(mealType: .dinner, date: calendar.date(byAdding: .day, value: 2, to: startOfWeek)!, recipe: recipes[2], servings: 2, notes: "Ramen craving"),
            PlannedMeal(mealType: .dinner, date: calendar.date(byAdding: .day, value: 3, to: startOfWeek)!, recipe: recipes[4], servings: 4, notes: "Family dinner"),
            PlannedMeal(mealType: .breakfast, date: calendar.date(byAdding: .day, value: 4, to: startOfWeek)!, recipe: recipes[5], servings: 2),
            PlannedMeal(mealType: .dinner, date: calendar.date(byAdding: .day, value: 5, to: startOfWeek)!, recipe: recipes[1], servings: 6, notes: "Taco Saturday"),
        ]
        for meal in meals {
            context.insert(meal)
            plan.meals.append(meal)
        }
    }

    // MARK: - Grocery List

    @MainActor
    private static func insertGroceryList(into context: ModelContext) {
        let list = GroceryList(name: "Weekly Shop")
        context.insert(list)

        let items: [(String, Double, MeasurementUnit, StoreSection, Double?, Bool)] = [
            ("Chicken thighs", 1.5, .pound, .meat, 8.99, false),
            ("Plain yogurt", 1, .cup, .dairy, 4.49, false),
            ("Crushed tomatoes", 14, .ounce, .canned, 2.29, true),
            ("Heavy cream", 0.5, .cup, .dairy, 3.99, false),
            ("Feta cheese", 200, .gram, .dairy, 5.49, false),
            ("Ripe tomatoes", 4, .piece, .produce, 3.99, false),
            ("English cucumber", 1, .whole, .produce, 1.49, true),
            ("Red onion", 1, .whole, .produce, 0.89, true),
            ("Kalamata olives", 0.5, .cup, .international, 4.99, false),
            ("Corn tortillas", 16, .piece, .international, 3.49, false),
            ("Pork shoulder", 3, .pound, .meat, 14.99, false),
            ("Nori sheets", 2, .piece, .international, 3.29, false),
        ]
        for (name, qty, unit, section, price, purchased) in items {
            let item = GroceryItem(name: name, quantity: qty, unit: unit, storeSection: section, estimatedPrice: price)
            item.isPurchased = purchased
            context.insert(item)
            list.items.append(item)
        }
    }

    // MARK: - Restaurant Journal

    @MainActor
    private static func insertRestaurantJournal(into context: ModelContext) {
        let entry1 = RestaurantJournalEntry(
            restaurantName: "Delfina",
            location: "San Francisco, CA",
            cuisine: .italian,
            dateVisited: Calendar.current.date(byAdding: .day, value: -12, to: .now)!,
            rating: 5,
            review: "Exceptional handmade pasta. The spaghetti with plum tomatoes was deceptively simple and perfect. Will be trying to recreate the nettle pappardelle.",
            priceRange: .upscale,
            tags: ["pasta", "date night"]
        )
        let entry2 = RestaurantJournalEntry(
            restaurantName: "Taqueria El Farolito",
            location: "San Francisco, CA",
            cuisine: .mexican,
            dateVisited: Calendar.current.date(byAdding: .day, value: -4, to: .now)!,
            rating: 4,
            review: "The super burrito is enormous and delicious. Carnitas were well-seasoned. Cash only.",
            priceRange: .budget,
            tags: ["casual", "late-night"]
        )
        let entry3 = RestaurantJournalEntry(
            restaurantName: "Burma Superstar",
            location: "San Francisco, CA",
            cuisine: .other,
            dateVisited: Calendar.current.date(byAdding: .day, value: -25, to: .now)!,
            rating: 4,
            review: "Tea leaf salad is a must. Rainbow salad was also excellent. Long wait but worth it.",
            priceRange: .moderate,
            tags: ["burmese", "salads"]
        )
        context.insert(entry1)
        context.insert(entry2)
        context.insert(entry3)

        let wantToTry1 = RestaurantWantToTry(
            restaurantName: "Tartine Manufactory",
            location: "San Francisco, CA",
            cuisine: .french,
            reason: "Heard their morning buns are life-changing."
        )
        let wantToTry2 = RestaurantWantToTry(
            restaurantName: "Rintaro",
            location: "San Francisco, CA",
            cuisine: .japanese,
            reason: "Beautiful izakaya. Friend recommended the grilled rice ball."
        )
        context.insert(wantToTry1)
        context.insert(wantToTry2)
    }

    // MARK: - User Profile

    @MainActor
    private static func insertUserProfile(into context: ModelContext) {
        let profile = UserProfile(
            displayName: "Test Chef",
            dietaryRestrictions: [],
            preferredCuisines: [.italian, .japanese, .mexican, .indian],
            skillLevel: .intermediate,
            measurementSystem: .imperial,
            preferredAIProvider: .onDevice
        )
        profile.dailyCalorieTarget = 2000
        profile.dailyProteinTargetGrams = 120
        profile.weeklyGroceryBudget = 150.0
        profile.totalRecipesCooked = 12
        profile.totalTimeCookingMinutes = 540
        profile.totalTimePrepMinutes = 210
        context.insert(profile)
    }
}
