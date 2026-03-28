import Foundation
import SwiftData

// MARK: - Demo Data (never inserted in Release builds)

/// Always compiles so call sites need no conditional guards.
/// The actual data insertion is gated by #if DEBUG inside insertIfNeeded,
/// so nothing runs — and no sample data leaks into — Release builds.
enum DemoData {

    static let insertedKey = "demoDataInserted_v3"

    /// Call once on first launch. No-op in Release builds.
    @MainActor
    static func insertIfNeeded(into context: ModelContext) {
        #if DEBUG
        // If the flag is set, also verify the store actually has data.
        // The flag can be stale if the app was reinstalled or the store was reset.
        if UserDefaults.standard.bool(forKey: insertedKey) {
            let count = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
            guard count == 0 else { return }        // store is empty — fall through and re-seed
            UserDefaults.standard.removeObject(forKey: insertedKey)
        }
        insert(into: context)
        UserDefaults.standard.set(true, forKey: insertedKey)
        #endif
    }

    #if DEBUG
    @MainActor
    static func insert(into context: ModelContext) {

        // Clear stale data before re-seeding.
        // MealPlan first so its cascade rule deletes PlannedMeals,
        // then explicitly delete PlannedMeal in case batch-delete skipped the cascade.
        try? context.delete(model: MealPlan.self)
        try? context.delete(model: PlannedMeal.self)
        try? context.delete(model: GroceryList.self)
        try? context.delete(model: Recipe.self)
        try? context.delete(model: PantryItem.self)

        // ── Recipes ──────────────────────────────────────────────────────────

        let pasta = makePasta()
        let tacos = makeTacos()
        let ramen = makeRamen()
        let curry = makeCurry()
        let souvlaki = makeSouvlaki()
        let croissants = makeCroissants()
        let bibimbap = makeBibimbap()
        let tagine = makeTagine()

        pasta.isFavorite = true
        ramen.isFavorite = true

        // Give a couple of recipes some cook history
        let log1 = CookingLogEntry(date: daysAgo(10), prepTimeMinutes: 12, cookTimeMinutes: 20, rating: 5, notes: "Perfect al dente!")
        let log2 = CookingLogEntry(date: daysAgo(3), prepTimeMinutes: 10, cookTimeMinutes: 18, rating: 4)
        pasta.cookingLog.append(contentsOf: [log1, log2])

        let log3 = CookingLogEntry(date: daysAgo(7), prepTimeMinutes: 30, cookTimeMinutes: 90, rating: 5, notes: "Rich and deeply flavored.")
        ramen.cookingLog.append(log3)

        [pasta, tacos, ramen, curry, souvlaki, croissants, bibimbap, tagine].forEach {
            context.insert($0)
        }

        // ── Pantry Items ─────────────────────────────────────────────────────

        let pantry: [PantryItem] = [
            PantryItem(name: "Olive Oil",       category: .liquidAndSauce, quantity: 1,   unit: .liter,      expirationDate: monthsFromNow(8)),
            PantryItem(name: "Garlic",           category: .produce,        quantity: 6,   unit: .clove,      expirationDate: weeksFromNow(3)),
            PantryItem(name: "Onion",            category: .produce,        quantity: 3,   unit: .whole,      expirationDate: weeksFromNow(2)),
            PantryItem(name: "Spaghetti",        category: .dryGoods,       quantity: 500, unit: .gram,       expirationDate: monthsFromNow(12)),
            PantryItem(name: "Canned Tomatoes",  category: .produce,        quantity: 2,   unit: .whole,      expirationDate: monthsFromNow(18)),
            PantryItem(name: "Chicken Breast",   category: .protein,        quantity: 600, unit: .gram,       expirationDate: daysFromNow(3)),
            PantryItem(name: "Cumin",            category: .seasoning,      quantity: 1,   unit: .whole,      expirationDate: monthsFromNow(6)),
            PantryItem(name: "Paprika",          category: .seasoning,      quantity: 1,   unit: .whole,      expirationDate: monthsFromNow(6)),
            PantryItem(name: "Soy Sauce",        category: .liquidAndSauce, quantity: 200, unit: .milliliter, expirationDate: monthsFromNow(12)),
            PantryItem(name: "Rice",             category: .dryGoods,       quantity: 2,   unit: .kilogram,   expirationDate: monthsFromNow(24)),
            PantryItem(name: "Eggs",             category: .protein,        quantity: 6,   unit: .whole,      expirationDate: weeksFromNow(2)),
            PantryItem(name: "Butter",           category: .dairy,          quantity: 250, unit: .gram,       expirationDate: weeksFromNow(3)),
            PantryItem(name: "Greek Yogurt",     category: .dairy,          quantity: 500, unit: .gram,       expirationDate: daysFromNow(6)),
            PantryItem(name: "Lemon",            category: .produce,        quantity: 2,   unit: .whole,      expirationDate: weeksFromNow(1)),
        ]
        pantry.forEach { context.insert($0) }

        // ── Meal Plan (this week) ─────────────────────────────────────────────

        let week = MealPlan(
            name: "This Week",
            startDate: startOfWeek(),
            endDate: endOfWeek(),
            budgetTarget: 120,
            calorieTarget: 2000
        )
        context.insert(week)

        let plannedMeals: [PlannedMeal] = [
            PlannedMeal(mealType: .dinner, date: daysFromNow(0), recipe: pasta,     servings: 2),
            PlannedMeal(mealType: .lunch,  date: daysFromNow(1), recipe: tacos,     servings: 2),
            PlannedMeal(mealType: .dinner, date: daysFromNow(2), recipe: ramen,     servings: 1),
            PlannedMeal(mealType: .dinner, date: daysFromNow(3), recipe: curry,     servings: 4),
            PlannedMeal(mealType: .lunch,  date: daysFromNow(4), recipe: souvlaki,  servings: 2),
            PlannedMeal(mealType: .dinner, date: daysFromNow(5), recipe: bibimbap,  servings: 2),
            PlannedMeal(mealType: .breakfast, date: daysFromNow(6), recipe: croissants, servings: 4),
        ]
        if let first = plannedMeals.first { first.isCompleted = true }
        plannedMeals.forEach {
            context.insert($0)
            week.meals.append($0)
        }

        // ── Grocery List ──────────────────────────────────────────────────────

        let groceries = GroceryList(name: "Weekly Shop", mealPlan: week)
        context.insert(groceries)

        let groceryItems: [GroceryItem] = [
            GroceryItem(name: "Pork Belly",       quantity: 400, unit: .gram,  storeSection: .meat,     estimatedPrice: 8.50),
            GroceryItem(name: "Ramen Noodles",    quantity: 2,   unit: .whole, storeSection: .international, estimatedPrice: 3.00),
            GroceryItem(name: "Coconut Milk",     quantity: 1,   unit: .whole, storeSection: .canned,   estimatedPrice: 2.50),
            GroceryItem(name: "Naan Bread",       quantity: 4,   unit: .whole, storeSection: .bakery,   estimatedPrice: 3.50),
            GroceryItem(name: "Lamb Shoulder",    quantity: 800, unit: .gram,  storeSection: .meat,     estimatedPrice: 14.00),
            GroceryItem(name: "Apricots (dried)", quantity: 100, unit: .gram,  storeSection: .dryGoods, estimatedPrice: 3.00),
            GroceryItem(name: "Spinach",          quantity: 200, unit: .gram,  storeSection: .produce,  estimatedPrice: 2.00),
            GroceryItem(name: "Carrots",          quantity: 4,   unit: .whole, storeSection: .produce,  estimatedPrice: 1.50),
        ]
        if groceryItems.count > 0 { groceryItems[0].isPurchased = true }
        if groceryItems.count > 1 { groceryItems[1].isPurchased = true }
        groceryItems.forEach {
            context.insert($0)
            groceries.items.append($0)
        }

        // ── Restaurant Journal ────────────────────────────────────────────────

        let nobu = RestaurantJournalEntry(
            restaurantName: "Nobu",
            location: "New York, NY",
            cuisine: .japanese,
            dateVisited: daysAgo(14),
            rating: 5,
            review: "Exceptional omakase. The black cod miso is life-changing. Service was flawless.",
            wouldRecommend: true,
            priceRange: .fine,
            tags: ["special occasion", "omakase", "sushi"]
        )
        nobu.dishesOrdered = [
            DishEntry(name: "Black Cod Miso",   description: "Signature dish, buttery and sweet", rating: 5, notes: "Must recreate this", wouldOrderAgain: true, wantToRecreate: true),
            DishEntry(name: "Rock Shrimp Tempura", description: "Creamy ponzu sauce", rating: 5, notes: nil, wouldOrderAgain: true, wantToRecreate: false),
            DishEntry(name: "Yellowtail Jalapeño", description: "Clean and bright", rating: 4, notes: nil, wouldOrderAgain: true, wantToRecreate: true),
        ]

        let taverna = RestaurantJournalEntry(
            restaurantName: "Taverna Opa",
            location: "Miami, FL",
            cuisine: .greek,
            dateVisited: daysAgo(30),
            rating: 4,
            review: "Lively atmosphere and fantastic mezze spread. The spanakopita rivaled my yiayia's.",
            wouldRecommend: true,
            priceRange: .moderate,
            tags: ["greek", "mezze", "lively"]
        )
        taverna.dishesOrdered = [
            DishEntry(name: "Spanakopita",     description: "Flaky and cheesy", rating: 5, notes: "Study the phyllo technique", wouldOrderAgain: true, wantToRecreate: true),
            DishEntry(name: "Lamb Souvlaki",   description: "Perfectly charred", rating: 4, notes: nil, wouldOrderAgain: true, wantToRecreate: false),
            DishEntry(name: "Baklava",         description: "Sweet and nutty", rating: 4, notes: nil, wouldOrderAgain: true, wantToRecreate: false),
        ]

        let lamaison = RestaurantJournalEntry(
            restaurantName: "La Maison",
            location: "San Francisco, CA",
            cuisine: .french,
            dateVisited: daysAgo(60),
            rating: 3,
            review: "Solid classics but nothing surprising. Crème brûlée was excellent; duck was dry.",
            wouldRecommend: false,
            priceRange: .upscale,
            tags: ["french", "classic", "brunch"]
        )
        lamaison.dishesOrdered = [
            DishEntry(name: "Crème Brûlée",     description: "Perfect caramel crust", rating: 5, notes: nil, wouldOrderAgain: true, wantToRecreate: true),
            DishEntry(name: "Duck Confit",       description: "A bit dry", rating: 2, notes: "Ask for sauce on the side next time", wouldOrderAgain: false, wantToRecreate: false),
            DishEntry(name: "French Onion Soup", description: "Classic, rich broth", rating: 4, notes: nil, wouldOrderAgain: true, wantToRecreate: true),
        ]

        [nobu, taverna, lamaison].forEach { context.insert($0) }

        // ── Want to Try ───────────────────────────────────────────────────────

        let wantToTry: [RestaurantWantToTry] = [
            RestaurantWantToTry(restaurantName: "n/naka",        location: "Los Angeles, CA",  cuisine: .japanese, reason: "Kaiseki perfection. Seen on Chef's Table."),
            RestaurantWantToTry(restaurantName: "Noma",          location: "Copenhagen, DK",   cuisine: .other,    reason: "World's best, before it closes."),
            RestaurantWantToTry(restaurantName: "Le Bernardin",  location: "New York, NY",      cuisine: .french,   reason: "Best seafood in America."),
            RestaurantWantToTry(restaurantName: "Trattoria da Enzo", location: "Rome, Italy",  cuisine: .italian,  reason: "Authentic cacio e pepe."),
        ]
        wantToTry.forEach { context.insert($0) }

        // ── User Profile ──────────────────────────────────────────────────────

        let profile = UserProfile(
            displayName: "Nicole",
            dietaryRestrictions: [],
            preferredCuisines: [.italian, .japanese, .greek, .french],
            skillLevel: .intermediate,
            measurementSystem: .imperial,
            preferredAIProvider: .onDevice
        )
        profile.weeklyGroceryBudget = 150
        profile.dailyCalorieTarget = 2000
        profile.totalRecipesCooked = 3
        profile.totalTimeCookingMinutes = 128
        profile.totalTimePrepMinutes = 52
        context.insert(profile)

        do {
            try context.save()
        } catch {
            print("⚠️ DemoData: Failed to save context — \(error)")
        }
    }

    // MARK: - Recipe Factories

    private static func makePasta() -> Recipe {
        let ingredients = [
            Ingredient(name: "Spaghetti",        category: .dryGoods,     amount: .init(quantity: 400, unit: .gram)),
            Ingredient(name: "Guanciale",         category: .protein,   amount: .init(quantity: 150, unit: .gram)),
            Ingredient(name: "Pecorino Romano",   category: .dairy,     amount: .init(quantity: 80,  unit: .gram), isDairyFree: false),
            Ingredient(name: "Egg Yolks",         category: .protein,   amount: .init(quantity: 4,   unit: .whole)),
            Ingredient(name: "Black Pepper",      category: .seasoning,     amount: .init(quantity: 2,   unit: .teaspoon)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Bring a large pot of heavily salted water to a boil. Cook spaghetti until 2 minutes before al dente.", timer: .init(durationSeconds: 600, label: "Boil pasta")),
            RecipeDirection(stepNumber: 2, instruction: "Render guanciale in a cold pan over medium heat until golden and crispy, about 8 minutes. Remove from heat.", timer: .init(durationSeconds: 480, label: "Render guanciale")),
            RecipeDirection(stepNumber: 3, instruction: "Whisk egg yolks with grated Pecorino Romano and a generous amount of cracked black pepper in a bowl."),
            RecipeDirection(stepNumber: 4, instruction: "Reserve 1 cup of pasta water. Drain pasta and add to the guanciale pan off the heat. Toss vigorously."),
            RecipeDirection(stepNumber: 5, instruction: "Add the egg mixture, splashing in pasta water a little at a time to create a silky, creamy sauce. Serve immediately."),
        ]
        let r = Recipe(
            title: "Spaghetti Carbonara",
            summary: "A Roman classic — silky egg sauce, crispy guanciale, and no cream in sight.",
            cuisine: .italian,
            difficulty: .intermediate,
            servings: 2,
            prepTimeMinutes: 10,
            cookTimeMinutes: 20,
            ingredients: ingredients,
            directions: directions,
            nutritionalInfo: NutritionalInfo(
                calories: 650, proteinGrams: 28, carbsGrams: 72, fatGrams: 28,
                fiberGrams: 3, sugarGrams: 4,
                sodiumMg: 820, cholesterolMg: 285, saturatedFatGrams: 10
            ),
            tags: ["pasta", "classic", "quick"]
        )
        return r
    }

    private static func makeTacos() -> Recipe {
        let ingredients = [
            Ingredient(name: "Skirt Steak",       category: .protein,   amount: .init(quantity: 500, unit: .gram)),
            Ingredient(name: "Corn Tortillas",    category: .dryGoods,     amount: .init(quantity: 8,   unit: .whole), isGlutenFree: true),
            Ingredient(name: "White Onion",       category: .produce, amount: .init(quantity: 1,   unit: .whole)),
            Ingredient(name: "Cilantro",          category: .seasoning,      amount: .init(quantity: 1,   unit: .bunch)),
            Ingredient(name: "Lime",              category: .produce,     amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Chipotle Peppers",  category: .seasoning,     amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Avocado",           category: .produce, amount: .init(quantity: 2,   unit: .whole)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Blend chipotle peppers with 2 tbsp olive oil, juice of 1 lime, salt, and garlic to make the marinade."),
            RecipeDirection(stepNumber: 2, instruction: "Coat skirt steak in the marinade and let rest at room temperature for 30 minutes.", timer: .init(durationSeconds: 1800, label: "Marinate")),
            RecipeDirection(stepNumber: 3, instruction: "Grill over high heat, 3 minutes per side for medium-rare. Rest 5 minutes then slice thinly against the grain.", timer: .init(durationSeconds: 360, label: "Grill steak")),
            RecipeDirection(stepNumber: 4, instruction: "Warm tortillas directly over a gas flame or dry skillet. Mash avocado with lime and salt."),
            RecipeDirection(stepNumber: 5, instruction: "Fill each tortilla with sliced steak, diced white onion, cilantro, and avocado. Squeeze over lime."),
        ]
        return Recipe(
            title: "Carne Asada Tacos",
            summary: "Street-style tacos with chipotle-marinated skirt steak and fresh toppings.",
            cuisine: .mexican,
            difficulty: .beginner,
            servings: 4,
            prepTimeMinutes: 15,
            cookTimeMinutes: 10,
            ingredients: ingredients,
            directions: directions,
            nutritionalInfo: NutritionalInfo(
                calories: 480, proteinGrams: 34, carbsGrams: 38, fatGrams: 20,
                fiberGrams: 6, sugarGrams: 3,
                sodiumMg: 620, cholesterolMg: 90, saturatedFatGrams: 6
            ),
            dietaryRestrictions: [.glutenFree],
            tags: ["tacos", "grilling", "street food", "weekend"]
        )
    }

    private static func makeRamen() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pork Belly",       category: .protein,   amount: .init(quantity: 400, unit: .gram)),
            Ingredient(name: "Chicken Stock",    category: .liquidAndSauce,    amount: .init(quantity: 2,   unit: .liter)),
            Ingredient(name: "Soy Sauce",        category: .liquidAndSauce, amount: .init(quantity: 4,   unit: .tablespoon)),
            Ingredient(name: "Mirin",            category: .liquidAndSauce, amount: .init(quantity: 2,   unit: .tablespoon)),
            Ingredient(name: "Ramen Noodles",    category: .dryGoods,     amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Soft-Boiled Eggs", category: .protein,   amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Nori",             category: .dryGoods,     amount: .init(quantity: 4,   unit: .slice)),
            Ingredient(name: "Spring Onion",     category: .produce, amount: .init(quantity: 3,   unit: .whole)),
            Ingredient(name: "Sesame Oil",       category: .liquidAndSauce,       amount: .init(quantity: 1,   unit: .tablespoon)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Simmer chicken stock with soy sauce, mirin, and a piece of kombu for 20 minutes to make tare.", timer: .init(durationSeconds: 1200, label: "Simmer tare")),
            RecipeDirection(stepNumber: 2, instruction: "Sear pork belly until golden on all sides. Add to the stock and braise for 90 minutes until tender.", timer: .init(durationSeconds: 5400, label: "Braise pork")),
            RecipeDirection(stepNumber: 3, instruction: "Soft-boil eggs for 6.5 minutes, transfer to ice water, peel and marinate in soy and mirin for at least 1 hour.", timer: .init(durationSeconds: 390, label: "Boil eggs")),
            RecipeDirection(stepNumber: 4, instruction: "Cook ramen noodles according to package directions. Drain and divide between bowls."),
            RecipeDirection(stepNumber: 5, instruction: "Ladle hot broth over noodles. Top with sliced chashu pork, a marinated egg, nori, spring onion, and a drizzle of sesame oil."),
        ]
        return Recipe(
            title: "Tonkotsu-Style Ramen",
            summary: "Deeply rich pork broth with tender chashu, marinated eggs, and springy noodles.",
            cuisine: .japanese,
            difficulty: .advanced,
            servings: 2,
            prepTimeMinutes: 30,
            cookTimeMinutes: 120,
            ingredients: ingredients,
            directions: directions,
            nutritionalInfo: NutritionalInfo(
                calories: 780, proteinGrams: 42, carbsGrams: 68, fatGrams: 34,
                fiberGrams: 4, sugarGrams: 8,
                sodiumMg: 1840, cholesterolMg: 210, saturatedFatGrams: 12
            ),
            tags: ["ramen", "noodles", "weekend project", "comfort food"]
        )
    }

    private static func makeCurry() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken Thighs",   category: .protein,   amount: .init(quantity: 800, unit: .gram)),
            Ingredient(name: "Coconut Milk",     category: .liquidAndSauce,    amount: .init(quantity: 400, unit: .milliliter), isDairyFree: true),
            Ingredient(name: "Onion",            category: .produce, amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Garlic",           category: .produce, amount: .init(quantity: 4,   unit: .clove)),
            Ingredient(name: "Ginger",           category: .seasoning,     amount: .init(quantity: 1,   unit: .tablespoon)),
            Ingredient(name: "Curry Powder",     category: .seasoning,     amount: .init(quantity: 2,   unit: .tablespoon)),
            Ingredient(name: "Garam Masala",     category: .seasoning,     amount: .init(quantity: 1,   unit: .teaspoon)),
            Ingredient(name: "Canned Tomatoes",  category: .produce, amount: .init(quantity: 400, unit: .gram)),
            Ingredient(name: "Spinach",          category: .produce, amount: .init(quantity: 100, unit: .gram)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Fry finely diced onions in oil over medium heat until deep golden brown, about 15 minutes. This is the base.", timer: .init(durationSeconds: 900, label: "Brown onions")),
            RecipeDirection(stepNumber: 2, instruction: "Add garlic and ginger paste, fry 2 minutes. Add curry powder and garam masala, fry 1 minute until fragrant."),
            RecipeDirection(stepNumber: 3, instruction: "Add canned tomatoes and cook down until oil separates, about 10 minutes. Season with salt."),
            RecipeDirection(stepNumber: 4, instruction: "Add chicken thighs and coat in the masala. Pour in coconut milk and simmer 25 minutes until chicken is cooked through.", timer: .init(durationSeconds: 1500, label: "Simmer curry")),
            RecipeDirection(stepNumber: 5, instruction: "Stir in fresh spinach until wilted. Adjust seasoning and serve with basmati rice or naan."),
        ]
        return Recipe(
            title: "Chicken Tikka Masala",
            summary: "Comfort curry with golden-fried onions, coconut milk, and fragrant spices.",
            cuisine: .indian,
            difficulty: .intermediate,
            servings: 4,
            prepTimeMinutes: 20,
            cookTimeMinutes: 40,
            ingredients: ingredients,
            directions: directions,
            dietaryRestrictions: [.glutenFree, .dairyFree],
            tags: ["curry", "chicken", "weeknight", "spicy"]
        )
    }

    private static func makeSouvlaki() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pork Shoulder",    category: .protein,   amount: .init(quantity: 600, unit: .gram)),
            Ingredient(name: "Lemon Juice",      category: .produce,     amount: .init(quantity: 3,   unit: .tablespoon)),
            Ingredient(name: "Olive Oil",        category: .liquidAndSauce,       amount: .init(quantity: 4,   unit: .tablespoon)),
            Ingredient(name: "Oregano (dried)",  category: .seasoning,     amount: .init(quantity: 2,   unit: .teaspoon)),
            Ingredient(name: "Garlic",           category: .produce, amount: .init(quantity: 3,   unit: .clove)),
            Ingredient(name: "Pita Bread",       category: .dryGoods,     amount: .init(quantity: 4,   unit: .whole)),
            Ingredient(name: "Tzatziki",         category: .dairy,     amount: .init(quantity: 200, unit: .gram), isDairyFree: false),
            Ingredient(name: "Tomato",           category: .produce, amount: .init(quantity: 2,   unit: .whole)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Cut pork into 3cm cubes. Mix with olive oil, lemon juice, minced garlic, oregano, salt, and pepper. Marinate minimum 2 hours.", timer: .init(durationSeconds: 7200, label: "Marinate")),
            RecipeDirection(stepNumber: 2, instruction: "Thread pork onto metal skewers and grill over high heat, turning every 2 minutes, until slightly charred and cooked through.", timer: .init(durationSeconds: 600, label: "Grill skewers")),
            RecipeDirection(stepNumber: 3, instruction: "Warm pita on the grill for 30 seconds per side."),
            RecipeDirection(stepNumber: 4, instruction: "Serve pork on pita with tzatziki, sliced tomatoes, and a squeeze of lemon."),
        ]
        return Recipe(
            title: "Pork Souvlaki",
            summary: "Lemon-herb marinated pork skewers served in warm pita with cool tzatziki.",
            cuisine: .greek,
            difficulty: .beginner,
            servings: 4,
            prepTimeMinutes: 15,
            cookTimeMinutes: 15,
            ingredients: ingredients,
            directions: directions,
            tags: ["greek", "grilling", "summer", "skewers"]
        )
    }

    private static func makeCroissants() -> Recipe {
        let ingredients = [
            Ingredient(name: "Bread Flour",      category: .dryGoods,   amount: .init(quantity: 500, unit: .gram)),
            Ingredient(name: "Butter (cold)",    category: .dairy,   amount: .init(quantity: 280, unit: .gram), isDairyFree: false),
            Ingredient(name: "Whole Milk",       category: .dairy,   amount: .init(quantity: 140, unit: .milliliter), isDairyFree: false),
            Ingredient(name: "Instant Yeast",    category: .dryGoods,   amount: .init(quantity: 7,   unit: .gram)),
            Ingredient(name: "Sugar",            category: .seasoning, amount: .init(quantity: 55, unit: .gram)),
            Ingredient(name: "Salt",             category: .seasoning,   amount: .init(quantity: 10,  unit: .gram)),
            Ingredient(name: "Egg (for wash)",   category: .protein, amount: .init(quantity: 1,   unit: .whole)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Mix flour, yeast, sugar, salt, and milk. Knead 5 minutes to form a smooth dough. Refrigerate overnight.", timer: .init(durationSeconds: 300, label: "Knead dough")),
            RecipeDirection(stepNumber: 2, instruction: "Pound cold butter into a flat square. Enclose the butter block in the dough and seal edges."),
            RecipeDirection(stepNumber: 3, instruction: "Roll dough into a large rectangle. Fold into thirds (letter fold). Refrigerate 30 min. Repeat 3 more times.", timer: .init(durationSeconds: 1800, label: "Chill between folds")),
            RecipeDirection(stepNumber: 4, instruction: "Roll final dough thin, cut into triangles and roll tightly from base to tip. Proof 2 hours until puffy.", timer: .init(durationSeconds: 7200, label: "Final proof")),
            RecipeDirection(stepNumber: 5, instruction: "Brush with egg wash, bake at 200°C (400°F) for 18 minutes until deep golden.", timer: .init(durationSeconds: 1080, label: "Bake"), safeTemperature: .init(protein: "Internal dough", minimumFahrenheit: 190, minimumCelsius: 88, notes: "Fully baked through")),
        ]
        return Recipe(
            title: "Classic French Croissants",
            summary: "Buttery, flaky laminated pastry — a weekend project worth every fold.",
            cuisine: .french,
            difficulty: .expert,
            servings: 8,
            prepTimeMinutes: 60,
            cookTimeMinutes: 20,
            ingredients: ingredients,
            directions: directions,
            tags: ["baking", "french", "pastry", "weekend project", "breakfast"]
        )
    }

    private static func makeBibimbap() -> Recipe {
        let ingredients = [
            Ingredient(name: "Short-Grain Rice",  category: .dryGoods,     amount: .init(quantity: 2,   unit: .cup)),
            Ingredient(name: "Ground Beef",       category: .protein,   amount: .init(quantity: 300, unit: .gram)),
            Ingredient(name: "Spinach",           category: .produce, amount: .init(quantity: 150, unit: .gram)),
            Ingredient(name: "Carrots",           category: .produce, amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Bean Sprouts",      category: .produce, amount: .init(quantity: 150, unit: .gram)),
            Ingredient(name: "Gochujang",         category: .liquidAndSauce, amount: .init(quantity: 3,   unit: .tablespoon)),
            Ingredient(name: "Sesame Oil",        category: .liquidAndSauce,       amount: .init(quantity: 2,   unit: .tablespoon)),
            Ingredient(name: "Soy Sauce",         category: .liquidAndSauce, amount: .init(quantity: 2,   unit: .tablespoon)),
            Ingredient(name: "Fried Egg",         category: .protein,   amount: .init(quantity: 2,   unit: .whole)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Cook rice and keep warm. Blanch spinach 30 seconds, squeeze dry, season with sesame oil and salt."),
            RecipeDirection(stepNumber: 2, instruction: "Julienne carrots, sauté in sesame oil 3 minutes. Blanch bean sprouts 1 minute, dress with sesame oil and salt."),
            RecipeDirection(stepNumber: 3, instruction: "Brown ground beef in soy sauce, sesame oil, and a little sugar until cooked. Season to taste."),
            RecipeDirection(stepNumber: 4, instruction: "Fry eggs sunny-side up, yolk still runny."),
            RecipeDirection(stepNumber: 5, instruction: "Assemble: rice in bowl, arrange vegetables and beef in sections. Top with egg and a big spoonful of gochujang. Mix before eating."),
        ]
        return Recipe(
            title: "Bibimbap",
            summary: "Korean mixed rice bowl loaded with seasoned vegetables, savoury beef, and a fried egg.",
            cuisine: .korean,
            difficulty: .intermediate,
            servings: 2,
            prepTimeMinutes: 25,
            cookTimeMinutes: 20,
            ingredients: ingredients,
            directions: directions,
            dietaryRestrictions: [.glutenFree],
            tags: ["korean", "rice bowl", "colourful", "weeknight"]
        )
    }

    private static func makeTagine() -> Recipe {
        let ingredients = [
            Ingredient(name: "Lamb Shoulder",    category: .protein,   amount: .init(quantity: 800, unit: .gram)),
            Ingredient(name: "Onion",            category: .produce, amount: .init(quantity: 2,   unit: .whole)),
            Ingredient(name: "Dried Apricots",   category: .produce,     amount: .init(quantity: 100, unit: .gram)),
            Ingredient(name: "Chickpeas",        category: .dryGoods,    amount: .init(quantity: 400, unit: .gram)),
            Ingredient(name: "Ras el Hanout",    category: .seasoning,     amount: .init(quantity: 2,   unit: .tablespoon)),
            Ingredient(name: "Honey",            category: .seasoning, amount: .init(quantity: 1,   unit: .tablespoon)),
            Ingredient(name: "Chicken Stock",    category: .liquidAndSauce,    amount: .init(quantity: 400, unit: .milliliter)),
            Ingredient(name: "Almonds (toasted)",category: .dryGoods,       amount: .init(quantity: 50,  unit: .gram)),
            Ingredient(name: "Coriander",        category: .seasoning,      amount: .init(quantity: 1,   unit: .bunch)),
        ]
        let directions: [RecipeDirection] = [
            RecipeDirection(stepNumber: 1, instruction: "Brown lamb pieces in batches in olive oil until golden on all sides. Set aside."),
            RecipeDirection(stepNumber: 2, instruction: "Fry sliced onions until soft. Add ras el hanout and cook 1 minute until fragrant."),
            RecipeDirection(stepNumber: 3, instruction: "Return lamb to pot. Add stock, apricots, honey, and chickpeas. Bring to a boil."),
            RecipeDirection(stepNumber: 4, instruction: "Transfer to a tagine or cover tightly and simmer over low heat for 1.5 hours until lamb is very tender.", timer: .init(durationSeconds: 5400, label: "Slow cook tagine"), safeTemperature: .init(protein: "Lamb", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3)),
            RecipeDirection(stepNumber: 5, instruction: "Garnish with toasted almonds and fresh coriander. Serve with couscous or flatbread."),
        ]
        return Recipe(
            title: "Lamb & Apricot Tagine",
            summary: "Slow-cooked Moroccan stew with sweet apricots, warm spices, and tender lamb.",
            cuisine: .moroccan,
            difficulty: .intermediate,
            servings: 4,
            prepTimeMinutes: 20,
            cookTimeMinutes: 100,
            ingredients: ingredients,
            directions: directions,
            dietaryRestrictions: [.glutenFree, .dairyFree],
            tags: ["moroccan", "slow cook", "lamb", "winter", "entertaining"]
        )
    }

    // MARK: - Date Helpers

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .now
    }

    private static func daysFromNow(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: .now) ?? .now
    }

    private static func weeksFromNow(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: n, to: .now) ?? .now
    }

    private static func monthsFromNow(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: n, to: .now) ?? .now
    }

    private static func startOfWeek() -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    private static func endOfWeek() -> Date {
        let start = startOfWeek()
        return Calendar.current.date(byAdding: .day, value: 6, to: start) ?? .now
    }
    #endif // DEBUG
}
