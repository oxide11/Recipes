import Foundation

// MARK: - Meal Prep Models

/// A category of prep work (e.g., proteins, vegetables, grains).
enum PrepCategory: String, CaseIterable, Identifiable, Sendable {
    case protein    = "Proteins"
    case vegetable  = "Vegetables & Aromatics"
    case grain      = "Grains & Starches"
    case dairy      = "Dairy"
    case seasoning  = "Spices & Seasonings"
    case sauce      = "Sauces & Liquids"
    case other      = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .protein:   return "flame.fill"
        case .vegetable: return "leaf.fill"
        case .grain:     return "takeoutbag.and.cup.and.straw.fill"
        case .dairy:     return "cup.and.saucer.fill"
        case .seasoning: return "sparkles"
        case .sauce:     return "drop.fill"
        case .other:     return "tray.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .protein:   return 0
        case .vegetable: return 1
        case .grain:     return 2
        case .dairy:     return 3
        case .seasoning: return 4
        case .sauce:     return 5
        case .other:     return 6
        }
    }
}

/// A single prep task for one ingredient within one recipe.
struct PrepTask: Identifiable, Sendable {
    let id = UUID()
    let recipeName: String
    let amount: IngredientAmount
    let preparationNote: String  // e.g. "dice", "mince", "slice into half-moons"
    var isCompleted: Bool = false
}

/// A group of prep tasks for one ingredient across multiple recipes.
struct PrepTaskGroup: Identifiable, Sendable {
    let id = UUID()
    let ingredientName: String
    let category: PrepCategory
    let totalAmount: String  // human-readable combined amount
    var tasks: [PrepTask]

    var isFullyCompleted: Bool {
        tasks.allSatisfy(\.isCompleted)
    }

    var completedCount: Int {
        tasks.filter(\.isCompleted).count
    }
}

// MARK: - Generator

/// Generates a combined meal-prep plan from a set of planned meals.
enum MealPrepPlanGenerator {

    /// Generate grouped prep tasks from planned meals on a given day.
    static func generate(from meals: [PlannedMeal]) -> [PrepTaskGroup] {
        // Collect all ingredient refs across all meals with recipe context
        var ingredientEntries: [(name: String, amount: IngredientAmount, recipeName: String, instruction: String)] = []

        for meal in meals {
            guard let recipe = meal.recipe else { continue }
            let servingScale = Double(meal.servings) / Double(max(recipe.servings, 1))

            for direction in recipe.directions {
                for ref in direction.ingredients {
                    let scaledAmount = IngredientAmount(
                        quantity: ref.amount.quantity * servingScale,
                        unit: ref.amount.unit
                    )
                    ingredientEntries.append((
                        name: ref.ingredientName,
                        amount: scaledAmount,
                        recipeName: recipe.title,
                        instruction: extractPrep(from: direction.instruction, for: ref.ingredientName)
                    ))
                }
            }
        }

        // Group by normalized ingredient name
        let grouped = Dictionary(grouping: ingredientEntries) { $0.name.lowercased() }

        // Build PrepTaskGroups
        var taskGroups: [PrepTaskGroup] = []

        for (_, entries) in grouped {
            guard let first = entries.first else { continue }
            let displayName = first.name
            let category = categorize(ingredient: displayName, meals: meals)

            let tasks = entries.map { entry in
                PrepTask(
                    recipeName: entry.recipeName,
                    amount: entry.amount,
                    preparationNote: entry.instruction
                )
            }

            let totalAmount = combinedAmountString(entries.map(\.amount))

            taskGroups.append(PrepTaskGroup(
                ingredientName: displayName,
                category: category,
                totalAmount: totalAmount,
                tasks: tasks
            ))
        }

        // Sort by category order, then by ingredient name
        return taskGroups.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            return $0.ingredientName < $1.ingredientName
        }
    }

    /// Groups by PrepCategory for section display.
    static func groupedByCategory(_ groups: [PrepTaskGroup]) -> [(category: PrepCategory, groups: [PrepTaskGroup])] {
        let dict = Dictionary(grouping: groups, by: \.category)
        return dict.keys
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { (category: $0, groups: dict[$0]!) }
    }

    // MARK: - Private Helpers

    /// Extract a concise preparation note from a direction for a given ingredient.
    private static func extractPrep(from instruction: String, for ingredientName: String) -> String {
        let lower = instruction.lowercased()
        let ingredientLower = ingredientName.lowercased()

        // Common prep verbs to look for near the ingredient name
        let prepVerbs = ["dice", "diced", "mince", "minced", "chop", "chopped", "slice", "sliced",
                         "cut", "shred", "shredded", "mash", "mashed", "grate", "grated",
                         "whisk", "whisked", "fold", "sauté", "brown", "broil", "marinate",
                         "season", "cook", "boil", "simmer", "bake", "drain", "halved", "crush"]

        // Find prep verbs that appear near the ingredient
        let foundVerbs = prepVerbs.filter { lower.contains($0) }

        if foundVerbs.isEmpty {
            return "Prepare as directed"
        }

        // If the ingredient is mentioned, try to extract the clause containing it
        if lower.contains(ingredientLower) || lower.contains(ingredientLower.components(separatedBy: " ").last ?? "") {
            // Return a simplified note from the first relevant verb
            let primaryVerb = foundVerbs.first!
            return "\(primaryVerb.capitalized) for \(ingredientName.lowercased())"
        }

        return "Prepare as directed"
    }

    /// Combine amounts into a human-readable string.
    private static func combinedAmountString(_ amounts: [IngredientAmount]) -> String {
        // Group by unit
        let byUnit = Dictionary(grouping: amounts, by: \.unit)

        let parts: [String] = byUnit.map { unit, amounts in
            let total = amounts.reduce(0.0) { $0 + $1.quantity }
            let formatted = total.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", total)
                : String(format: "%.1f", total)
            return "\(formatted) \(unit.rawValue)"
        }

        return parts.joined(separator: " + ")
    }

    /// Map an ingredient name to a PrepCategory based on the recipe's ingredient data.
    private static func categorize(ingredient: String, meals: [PlannedMeal]) -> PrepCategory {
        let lower = ingredient.lowercased()

        // Try to find the ingredient in the recipes to get its category
        for meal in meals {
            guard let recipe = meal.recipe else { continue }
            if let found = recipe.ingredients.first(where: { $0.name.lowercased() == lower }) {
                switch found.category {
                case .protein:                    return .protein
                case .vegetable, .fruit:          return .vegetable
                case .grain, .legume, .nut:       return .grain
                case .dairy:                      return .dairy
                case .spice, .herb:               return .seasoning
                case .condiment, .oil, .liquid, .sweetener: return .sauce
                case .other:                      return .other
                }
            }
        }

        return .other
    }
}
