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

/// Base actions simple enough that no further explanation is needed (matched by prefix, case-insensitive).
let selfEvidentPrepBases: Set<String> = [
    "dice", "mince", "chop", "slice", "shred", "grate",
    "crush", "halve", "quarter", "cube", "peel", "trim",
    "zest", "julienne", "rinse", "roughly", "wash", "pit",
    "seed", "core", "cut", "tear"
]

func isSelfEvident(_ action: String) -> Bool {
    let base = (action.components(separatedBy: " ").first ?? action).lowercased()
    return selfEvidentPrepBases.contains(base)
}

/// A single prep task for one ingredient within one recipe.
struct PrepTask: Identifiable, Sendable {
    let id = UUID()
    let recipeName: String
    let amount: IngredientAmount
    let preparationNote: String
    let detail: String?          // source direction text, shown for complex actions
    var isCompleted: Bool = false
}

/// A group of prep tasks for one ingredient across multiple recipes.
struct PrepTaskGroup: Identifiable, Sendable {
    let id = UUID()
    let ingredientName: String
    let category: PrepCategory
    let totalAmount: String
    let estimatedMinutes: Int   // total active time for this group
    let urgencyOrder: Int       // lower = do first
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

    // MARK: - Verbs

    /// Actions that mean "do this while cooking" — not in advance.
    private static let cookingOnlyVerbs: Set<String> = [
        "sauté", "saute", "fry", "stir-fry", "pan-fry", "deep-fry",
        "brown", "bake", "broil", "boil", "simmer", "grill", "roast",
        "poach", "steam", "toast", "fold", "whisk", "stir", "mix",
        "blend", "combine", "toss", "add", "pour", "drizzle", "sprinkle"
    ]

    /// Actions that are genuine advance prep.
    private static let prepVerbMap: [String: String] = [
        "dice": "Dice", "diced": "Dice",
        "mince": "Mince", "minced": "Mince",
        "chop": "Chop", "chopped": "Chop",
        "slice": "Slice", "sliced": "Slice",
        "shred": "Shred", "shredded": "Shred",
        "grate": "Grate", "grated": "Grate",
        "crush": "Crush", "crushed": "Crush",
        "halve": "Halve", "halved": "Halve",
        "quarter": "Quarter", "quartered": "Quarter",
        "cube": "Cube", "cubed": "Cube",
        "peel": "Peel", "peeled": "Peel",
        "trim": "Trim", "trimmed": "Trim",
        "julienne": "Julienne", "julienned": "Julienne",
        "marinate": "Marinate", "marinated": "Marinate",
        "season": "Season",
        "zest": "Zest", "zested": "Zest",
        "pit": "Pit", "debone": "Debone",
        "butterfly": "Butterfly",
        "score": "Score",
        "rinse": "Rinse and drain",
        "soak": "Soak"
    ]

    // MARK: - Items to skip

    /// Ingredients that should never appear on a prep list.
    private static let skipIngredients: Set<String> = [
        // Fruit that oxidizes or goes mushy when cut in advance
        "banana", "bananas", "avocado", "avocados",
        "apple", "apples", "pear", "pears",
        "mango", "mangoes", "peach", "peaches", "nectarine", "nectarines",
        "strawberry", "strawberries", "raspberry", "raspberries",
        "blueberry", "blueberries", "blackberry", "blackberries",
        "kiwi", "fig", "figs", "grape", "grapes",
        // Delicate greens that wilt
        "lettuce", "arugula", "spinach", "mixed greens", "baby greens",
        "fresh basil", "fresh mint", "fresh cilantro", "microgreens",
        // Dry baking goods — nothing to prep
        "flour", "all-purpose flour", "bread flour", "cake flour", "whole wheat flour",
        "baking powder", "baking soda", "cornstarch", "arrowroot",
        "sugar", "brown sugar", "powdered sugar", "icing sugar", "caster sugar",
        "cocoa powder", "yeast",
        // Seaweed / dried sheets
        "nori", "dried nori", "seaweed", "kombu", "wakame", "dulse",
        // Eggs — crack and add when cooking
        "egg", "eggs", "egg white", "egg whites", "egg yolk", "egg yolks",
        // Noodles and pasta — cooked right before serving, not in advance
        "noodles", "rice noodles", "glass noodles", "cellophane noodles",
        "vermicelli", "soba", "udon", "ramen",
        "pasta", "spaghetti", "linguine", "fettuccine", "penne", "rigatoni",
        "fusilli", "farfalle", "orzo", "lasagna", "lasagne", "tagliatelle",
        "nori", "nori sheet",
        // Aromatics used whole — no prep needed
        "bay leaf", "bay leaves", "star anise", "cardamom pods", "cinnamon stick", "cinnamon sticks",
        "whole cloves", "black peppercorns",
        // Tortillas and wrappers — used as-is
        "corn tortillas", "flour tortillas", "tortillas", "wonton wrappers",
        "spring roll wrappers", "rice paper", "rice paper wrappers",
        // Pre-processed canned/jarred goods — already prepped
        "crushed tomatoes", "canned crushed tomatoes",
        "diced tomatoes", "canned diced tomatoes",
        "whole peeled tomatoes", "canned tomatoes", "tomato paste", "tomato sauce",
        "canned chickpeas", "canned lentils", "canned black beans",
        "canned kidney beans", "canned white beans", "canned corn",
        "coconut milk", "canned coconut milk",
        // Condiments and small flavour additions
        "salt", "pepper", "black pepper", "white pepper", "red pepper flakes",
        "soy sauce", "fish sauce", "hot sauce", "worcestershire",
        "vanilla", "vanilla extract"
    ]

    /// Categories where advance prep has no value (just pour/measure at cook time).
    private static let skipCategories: Set<IngredientCategory> = [
        .liquid, .oil, .condiment, .sweetener, .spice, .dairy
    ]

    /// Legumes/grains that genuinely need soaking overnight — worth including.
    private static let requiresSoak: Set<String> = [
        "dried chickpeas", "chickpeas", "dried lentils", "lentils",
        "dried black beans", "black beans", "dried kidney beans", "kidney beans",
        "dried cannellini beans", "dried white beans", "dried navy beans",
        "dried pinto beans", "dried split peas", "split peas"
    ]

    // MARK: - Public API

    static func generate(from meals: [PlannedMeal]) -> [PrepTaskGroup] {
        var ingredientEntries: [(name: String, amount: IngredientAmount, recipeName: String, action: String, detail: String?, category: IngredientCategory)] = []

        for meal in meals {
            guard let recipe = meal.recipe else { continue }
            let servingScale = Double(meal.servings) / Double(max(recipe.servings, 1))

            for direction in recipe.directions {
                for ref in direction.ingredients {
                    let ingredientCategory = recipe.ingredients
                        .first(where: { $0.name.lowercased() == ref.ingredientName.lowercased() })?.category ?? .other

                    // Skip categories that don't benefit from advance prep
                    if skipCategories.contains(ingredientCategory) { continue }

                    // Skip ingredients that don't benefit from advance prep
                    let nameLower = ref.ingredientName.lowercased()
                    if skipIngredients.contains(where: { nameLower.contains($0) }) { continue }

                    guard let (action, sourceClause) = extractPrepAction(
                        from: direction.instruction,
                        for: ref.ingredientName,
                        category: ingredientCategory
                    ) else { continue }

                    // Skip if the action is purely a cooking action (not an advance prep)
                    if isCookingOnlyAction(action) { continue }

                    // Skip trivial "measure out" tasks — not worth putting on a prep list
                    if action == "Measure out" { continue }

                    // Special case: dried legumes that need an overnight soak DO belong here
                    if ingredientCategory == .legume && !requiresSoak.contains(where: { nameLower.contains($0) }) {
                        continue
                    }

                    let scaledAmount = IngredientAmount(
                        quantity: ref.amount.quantity * servingScale,
                        unit: ref.amount.unit
                    )

                    // Only attach detail for actions that aren't self-evident
                    let detail = isSelfEvident(action) ? nil : sourceClause

                    ingredientEntries.append((
                        name: ref.ingredientName,
                        amount: scaledAmount,
                        recipeName: recipe.title,
                        action: action,
                        detail: detail,
                        category: ingredientCategory
                    ))
                }
            }
        }

        // Group by normalized ingredient name
        let grouped = Dictionary(grouping: ingredientEntries) { $0.name.lowercased() }

        var taskGroups: [PrepTaskGroup] = []

        for (_, entries) in grouped {
            guard let first = entries.first else { continue }
            let category = mapToPrep(first.category)

            let tasks = entries.map { (entry: (name: String, amount: IngredientAmount, recipeName: String, action: String, detail: String?, category: IngredientCategory)) in
                PrepTask(
                    recipeName: entry.recipeName,
                    amount: entry.amount,
                    preparationNote: entry.action,
                    detail: entry.detail
                )
            }

            // Estimate total active minutes across all tasks in this group
            let totalMinutes = entries.reduce(0) { sum, entry in
                sum + (actionTimeEstimates[entry.action] ?? 3)
            }

            // Urgency driven by the most urgent action in this group
            let minUrgency = entries.map { urgencyOrder(for: $0.action) }.min() ?? 3

            taskGroups.append(PrepTaskGroup(
                ingredientName: first.name,
                category: category,
                totalAmount: combinedAmountString(entries.map(\.amount)),
                estimatedMinutes: totalMinutes,
                urgencyOrder: minUrgency,
                tasks: tasks
            ))
        }

        return taskGroups.sorted {
            if $0.urgencyOrder != $1.urgencyOrder { return $0.urgencyOrder < $1.urgencyOrder }
            if $0.category.sortOrder != $1.category.sortOrder { return $0.category.sortOrder < $1.category.sortOrder }
            return $0.ingredientName < $1.ingredientName
        }
    }

    /// Groups by urgency order for display — preserves the start-first ordering within each section.
    static func groupedByUrgency(_ groups: [PrepTaskGroup]) -> [(title: String, icon: String, groups: [PrepTaskGroup])] {
        let urgencyMeta: [(order: Int, title: String, icon: String)] = [
            (0, "Start First",   "clock.arrow.circlepath"),
            (1, "Protein Prep", "flame.fill"),
            (2, "Knife Work",   "scissors"),
            (3, "Everything Else", "tray.fill"),
        ]
        let dict = Dictionary(grouping: groups, by: \.urgencyOrder)
        return urgencyMeta.compactMap { meta in
            guard let items = dict[meta.order], !items.isEmpty else { return nil }
            return (title: meta.title, icon: meta.icon, groups: items)
        }
    }

    // MARK: - Time & Urgency

    /// Estimated active minutes per action. Passive time (marinating, soaking) is noted separately.
    static let actionTimeEstimates: [String: Int] = [
        "Marinate": 5, "Season": 3,
        "Soak overnight": 2, "Rinse and soak": 3,
        "Trim and portion": 5, "Butterfly": 6, "Debone": 8, "Score": 3,
        "Dice": 4, "Chop": 3, "Wash and chop": 4, "Mince": 4,
        "Mince or grate": 4, "Slice": 4, "Shred": 5, "Grate": 4,
        "Grate or crumble": 4, "Crush": 2, "Halve": 2, "Quarter": 2,
        "Cube": 4, "Peel": 3, "Trim": 3, "Julienne": 6,
        "Roughly chop": 3, "Wash and slice": 3, "Zest": 3, "Rinse and drain": 2,
    ]

    /// Optional passive time note shown alongside the time estimate.
    static let actionPassiveNote: [String: String] = [
        "Marinate":       "then let sit 1–24 hrs",
        "Soak overnight": "then soak 8+ hrs",
        "Rinse and soak": "then soak 1–2 hrs",
    ]

    // All lowercase — compared case-insensitively
    private static let knifeWorkVerbs: Set<String> = [
        "dice", "chop", "mince", "slice", "shred", "grate",
        "crush", "halve", "quarter", "cube", "peel", "julienne",
        "roughly", "seed", "core", "cut into", "tear"
    ]

    /// Lower urgency order = do earlier in the session.
    private static func urgencyOrder(for action: String) -> Int {
        let lower = action.lowercased()
        if ["marinate", "soak", "rinse"].contains(where: { lower.hasPrefix($0) }) { return 0 }
        if ["trim and portion", "butterfly", "debone"].contains(lower) { return 1 }
        if knifeWorkVerbs.contains(where: { lower.contains($0) }) { return 2 }
        return 3
    }

    // MARK: - Cut Modifier

    /// Extracts a size or style modifier near a verb in a clause (e.g. "finely" → " finely").
    private static func cutModifier(in clause: String, for verb: String) -> String {
        // Adverb modifiers that describe how to cut
        let adverbs: [String] = [
            "finely", "fine", "roughly", "coarsely", "thinly", "thin",
            "thickly", "thick", "diagonally", "crosswise", "lengthwise"
        ]
        // Shape/size descriptors that follow the verb
        let shapes: [String] = [
            "into half-moons", "into rings", "into strips", "into wedges",
            "into florets", "into cubes", "into chunks", "into matchsticks",
            "small dice", "medium dice", "large dice"
        ]

        let words = clause.components(separatedBy: .whitespaces)
        guard let verbIndex = words.firstIndex(where: { $0.hasPrefix(verb) }) else { return "" }

        // Shape phrases take priority — check the whole clause
        for shape in shapes {
            if clause.contains(shape) { return " \(shape)" }
        }

        // Check up to 3 words before the verb (e.g. "finely dice", "very finely dice")
        if verbIndex > 0 {
            for offset in 1...min(3, verbIndex) {
                let word = words[verbIndex - offset]
                if let mod = adverbs.first(where: { word == $0 }) { return " \(mod)" }
            }
        }

        // Check up to 5 words after the verb (e.g. "dice the onion finely")
        let remaining = words.count - verbIndex - 1
        if remaining > 0 {
            for offset in 1...min(5, remaining) {
                let word = words[verbIndex + offset]
                if let mod = adverbs.first(where: { word == $0 }) { return " \(mod)" }
            }
        }

        return ""
    }

    // MARK: - Private Helpers

    /// Extract a prep action and source clause from the direction mentioning the ingredient.
    /// Returns nil if no meaningful prep action could be determined (item should be skipped).
    private static func extractPrepAction(
        from instruction: String,
        for ingredientName: String,
        category: IngredientCategory
    ) -> (action: String, sourceClause: String?)? {
        let lower = instruction.lowercased()
        let ingredientLower = ingredientName.lowercased()

        // Split instruction into clauses on punctuation and conjunctions
        let clauses = lower.components(separatedBy: CharacterSet(charactersIn: ".,;"))

        // Find the clause that mentions this ingredient (or its last meaningful word)
        let ingredientWords = ingredientLower.components(separatedBy: " ").filter { $0.count > 2 }
        let relevantClause = clauses.first(where: { clause in
            ingredientWords.contains(where: { clause.contains($0) })
        })

        if let clause = relevantClause {
            // Look for a prep verb in this specific clause,
            // but skip verbs that appear in the ingredient name itself (descriptors, not actions)
            for (verb, label) in prepVerbMap.sorted(by: { $0.key.count > $1.key.count }) {
                if clause.contains(verb) && !ingredientLower.contains(verb) {
                    let action = label + cutModifier(in: clause, for: verb)
                    return (action: action, sourceClause: instruction)
                }
            }
        }

        // Fruit with no specific verb found — don't guess, skip it
        if category == .fruit { return nil }

        // Fall back to category-based default — still try to find a size qualifier in the clause
        let fallback = categoryDefault(for: category, ingredientName: ingredientLower)
        var fallbackModifier = ""
        if let clause = relevantClause {
            let adverbs = ["finely", "roughly", "coarsely", "thinly", "thickly", "diagonally"]
            let clauseWords = clause.components(separatedBy: .whitespaces)
            fallbackModifier = clauseWords.first(where: { adverbs.contains($0) }).map { " \($0)" } ?? ""
        }
        return (action: fallback + fallbackModifier, sourceClause: relevantClause.map { _ in instruction })
    }

    /// Returns true if the action is something done during cooking, not in advance.
    private static func isCookingOnlyAction(_ action: String) -> Bool {
        let lower = action.lowercased()
        return cookingOnlyVerbs.contains(where: { lower.hasPrefix($0) })
    }

    /// Sensible category-based default when no specific verb is found.
    private static func categoryDefault(for category: IngredientCategory, ingredientName: String) -> String {
        switch category {
        case .protein:
            return "Trim and portion"
        case .vegetable:
            if ingredientName.contains("garlic") { return "Mince" }
            if ingredientName.contains("ginger") { return "Mince or grate" }
            if ingredientName.contains("onion") || ingredientName.contains("shallot") { return "Dice" }
            if ingredientName.contains("carrot") || ingredientName.contains("celery") { return "Dice" }
            if ingredientName.contains("tomato") { return "Dice" }
            if ingredientName.contains("pepper") || ingredientName.contains("capsicum") { return "Dice" }
            if ingredientName.contains("olive") { return "Pit and halve" }
            if ingredientName.contains("mushroom") { return "Slice" }
            if ingredientName.contains("zucchini") || ingredientName.contains("courgette") { return "Slice" }
            if ingredientName.contains("leek") { return "Slice" }
            if ingredientName.contains("broccoli") || ingredientName.contains("cauliflower") { return "Cut into florets" }
            if ingredientName.contains("cabbage") { return "Shred" }
            if ingredientName.contains("kale") || ingredientName.contains("chard") { return "Roughly chop" }
            if ingredientName.contains("parsley") || ingredientName.contains("cilantro") ||
               ingredientName.contains("chive") || ingredientName.contains("dill") { return "Roughly chop" }
            if ingredientName.contains("scallion") || ingredientName.contains("green onion") { return "Slice" }
            if ingredientName.contains("fennel") { return "Slice thinly" }
            if ingredientName.contains("beet") { return "Peel and dice" }
            if ingredientName.contains("potato") || ingredientName.contains("sweet potato") { return "Peel and dice" }
            return "Chop"
        case .fruit:
            return "Wash and slice"
        case .grain:
            return "Rinse and soak"
        case .legume:
            return "Soak overnight"
        case .dairy:
            if ingredientName.contains("cheese") { return "Grate or crumble" }
            return "Portion out"
        case .spice, .herb:
            if ingredientName.contains("fresh") { return "Wash and chop" }
            return "Measure out"
        case .nut:
            return "Roughly chop"
        case .other:
            return "Portion out"
        case .oil, .condiment, .liquid, .sweetener:
            return "Portion out"
        }
    }

    /// Combine amounts into a human-readable string.
    private static func combinedAmountString(_ amounts: [IngredientAmount]) -> String {
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

    /// Map ingredient category to prep display category.
    private static func mapToPrep(_ category: IngredientCategory) -> PrepCategory {
        switch category {
        case .protein:                              return .protein
        case .vegetable, .fruit:                    return .vegetable
        case .grain, .legume, .nut:                 return .grain
        case .dairy:                                return .dairy
        case .spice, .herb:                         return .seasoning
        case .condiment, .oil, .liquid, .sweetener: return .sauce
        case .other:                                return .other
        }
    }
}
