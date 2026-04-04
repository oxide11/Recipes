import Foundation

// MARK: - Pantry Starter Kit

/// Static cuisine → starter ingredient mapping used during onboarding.
/// Each list is curated to feel like a real kitchen setup for that style,
/// not an exhaustive pantry dump.
enum PantryStarterKit {

    struct StarterIngredient {
        let name: String
        let category: IngredientCategory
        let unit: MeasurementUnit
        let quantity: Double
    }

    /// Ingredients every kitchen should have, regardless of cuisine.
    /// Added first so they're always at the top of the list.
    static let universals: [StarterIngredient] = [
        .init(name: "Salt",              category: .spice,     unit: .tablespoon, quantity: 4),
        .init(name: "Black pepper",      category: .spice,     unit: .tablespoon, quantity: 2),
        .init(name: "Olive oil",         category: .oil,       unit: .cup,        quantity: 1),
        .init(name: "Neutral oil",       category: .oil,       unit: .cup,        quantity: 1),
        .init(name: "White vinegar",     category: .condiment, unit: .cup,        quantity: 0.5),
        .init(name: "Garlic",            category: .vegetable, unit: .whole,      quantity: 1),
        .init(name: "Yellow onion",      category: .vegetable, unit: .whole,      quantity: 2),
        .init(name: "Butter",            category: .dairy,     unit: .ounce,      quantity: 8),
        .init(name: "Eggs",              category: .protein,   unit: .whole,      quantity: 6),
        .init(name: "Flour",             category: .grain,     unit: .cup,        quantity: 2),
        .init(name: "Sugar",             category: .sweetener, unit: .cup,        quantity: 1),
    ]

    static let kits: [Cuisine: [StarterIngredient]] = [
        .italian: [
            .init(name: "Olive oil",          category: .oil,       unit: .cup,       quantity: 1),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Canned tomatoes",     category: .vegetable, unit: .can,       quantity: 2),
            .init(name: "Pasta",               category: .grain,     unit: .pound,     quantity: 1),
            .init(name: "Parmesan",            category: .dairy,     unit: .ounce,     quantity: 4),
            .init(name: "Dried oregano",       category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Red pepper flakes",   category: .spice,     unit: .tablespoon,quantity: 1),
        ],
        .japanese: [
            .init(name: "Soy sauce",           category: .condiment, unit: .cup,       quantity: 1),
            .init(name: "Sesame oil",          category: .oil,       unit: .cup,       quantity: 0.5),
            .init(name: "Short-grain rice",    category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Rice vinegar",        category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Fresh ginger",        category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Mirin",               category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Nori",                category: .other,     unit: .piece,     quantity: 10),
        ],
        .mexican: [
            .init(name: "Cumin",               category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Chili powder",        category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Black beans",         category: .legume,    unit: .can,       quantity: 2),
            .init(name: "Lime",                category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Cilantro",            category: .herb,      unit: .bunch,     quantity: 1),
            .init(name: "Jalapeños",           category: .vegetable, unit: .whole,     quantity: 4),
            .init(name: "Dried ancho chili",   category: .spice,     unit: .piece,     quantity: 4),
        ],
        .american: [
            .init(name: "Butter",              category: .dairy,     unit: .ounce,     quantity: 8),
            .init(name: "All-purpose flour",   category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Eggs",                category: .protein,   unit: .whole,     quantity: 6),
            .init(name: "Chicken stock",       category: .liquid,    unit: .cup,       quantity: 4),
            .init(name: "Yellow onion",        category: .vegetable, unit: .whole,     quantity: 2),
            .init(name: "Breadcrumbs",         category: .grain,     unit: .cup,       quantity: 1),
            .init(name: "Worcestershire sauce",category: .condiment, unit: .tablespoon,quantity: 3),
        ],
        .mediterranean: [
            .init(name: "Olive oil",           category: .oil,       unit: .cup,       quantity: 1),
            .init(name: "Lemon",               category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Chickpeas",           category: .legume,    unit: .can,       quantity: 2),
            .init(name: "Feta cheese",         category: .dairy,     unit: .ounce,     quantity: 6),
            .init(name: "Kalamata olives",     category: .condiment, unit: .cup,       quantity: 1),
            .init(name: "Cumin",               category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Za'atar",             category: .spice,     unit: .tablespoon,quantity: 2),
        ],
        .indian: [
            .init(name: "Basmati rice",        category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Turmeric",            category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Garam masala",        category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Cumin seeds",         category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Ground coriander",    category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Ghee",                category: .oil,       unit: .cup,       quantity: 0.5),
            .init(name: "Red lentils",         category: .legume,    unit: .cup,       quantity: 2),
        ],
        .thai: [
            .init(name: "Fish sauce",          category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Coconut milk",        category: .liquid,    unit: .can,       quantity: 2),
            .init(name: "Thai chili",          category: .vegetable, unit: .whole,     quantity: 6),
            .init(name: "Lemongrass",          category: .herb,      unit: .whole,     quantity: 2),
            .init(name: "Lime",                category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Rice noodles",        category: .grain,     unit: .ounce,     quantity: 8),
            .init(name: "Palm sugar",          category: .sweetener, unit: .tablespoon,quantity: 3),
        ],
        .chinese: [
            .init(name: "Soy sauce",           category: .condiment, unit: .cup,       quantity: 1),
            .init(name: "Sesame oil",          category: .oil,       unit: .cup,       quantity: 0.5),
            .init(name: "Jasmine rice",        category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Oyster sauce",        category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Fresh ginger",        category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Cornstarch",          category: .grain,     unit: .cup,       quantity: 0.5),
        ],
        .korean: [
            .init(name: "Gochujang",           category: .condiment, unit: .tablespoon,quantity: 4),
            .init(name: "Sesame oil",          category: .oil,       unit: .cup,       quantity: 0.5),
            .init(name: "Soy sauce",           category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Short-grain rice",    category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Green onions",        category: .vegetable, unit: .bunch,     quantity: 1),
            .init(name: "Doenjang",            category: .condiment, unit: .tablespoon,quantity: 3),
        ],
        .french: [
            .init(name: "Butter",              category: .dairy,     unit: .ounce,     quantity: 8),
            .init(name: "Heavy cream",         category: .dairy,     unit: .cup,       quantity: 1),
            .init(name: "Dijon mustard",       category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Shallots",            category: .vegetable, unit: .whole,     quantity: 4),
            .init(name: "Dried thyme",         category: .herb,      unit: .tablespoon,quantity: 2),
            .init(name: "Bay leaves",          category: .herb,      unit: .piece,     quantity: 4),
            .init(name: "Chicken stock",       category: .liquid,    unit: .cup,       quantity: 4),
        ],
        .greek: [
            .init(name: "Olive oil",           category: .oil,       unit: .cup,       quantity: 1),
            .init(name: "Lemon",               category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Feta cheese",         category: .dairy,     unit: .ounce,     quantity: 6),
            .init(name: "Dried oregano",       category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Kalamata olives",     category: .condiment, unit: .cup,       quantity: 1),
            .init(name: "Cucumber",            category: .vegetable, unit: .whole,     quantity: 2),
        ],
        .moroccan: [
            .init(name: "Cumin",               category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Ground coriander",    category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Cinnamon",            category: .spice,     unit: .tablespoon,quantity: 1),
            .init(name: "Chickpeas",           category: .legume,    unit: .can,       quantity: 2),
            .init(name: "Preserved lemon",     category: .condiment, unit: .whole,     quantity: 2),
            .init(name: "Harissa",             category: .condiment, unit: .tablespoon,quantity: 2),
            .init(name: "Couscous",            category: .grain,     unit: .cup,       quantity: 2),
        ],
        .spanish: [
            .init(name: "Olive oil",           category: .oil,       unit: .cup,       quantity: 1),
            .init(name: "Smoked paprika",      category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Saffron",             category: .spice,     unit: .pinch,     quantity: 2),
            .init(name: "Canned tomatoes",     category: .vegetable, unit: .can,       quantity: 2),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Sherry vinegar",      category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Short-grain rice",    category: .grain,     unit: .cup,       quantity: 2),
        ],
        .vietnamese: [
            .init(name: "Fish sauce",          category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Rice noodles",        category: .grain,     unit: .ounce,     quantity: 8),
            .init(name: "Fresh mint",          category: .herb,      unit: .bunch,     quantity: 1),
            .init(name: "Bean sprouts",        category: .vegetable, unit: .cup,       quantity: 2),
            .init(name: "Lime",                category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Sriracha",            category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Jasmine rice",        category: .grain,     unit: .cup,       quantity: 2),
        ],
        .brazilian: [
            .init(name: "Black beans",         category: .legume,    unit: .can,       quantity: 2),
            .init(name: "Lime",                category: .fruit,     unit: .whole,     quantity: 4),
            .init(name: "Cilantro",            category: .herb,      unit: .bunch,     quantity: 1),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Cumin",               category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Hot sauce",           category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Long-grain rice",     category: .grain,     unit: .cup,       quantity: 2),
        ],
        .ethiopian: [
            .init(name: "Berbere spice blend", category: .spice,     unit: .tablespoon,quantity: 3),
            .init(name: "Red lentils",         category: .legume,    unit: .cup,       quantity: 2),
            .init(name: "Chickpeas",           category: .legume,    unit: .can,       quantity: 2),
            .init(name: "Cardamom",            category: .spice,     unit: .tablespoon,quantity: 1),
            .init(name: "Fenugreek",           category: .spice,     unit: .tablespoon,quantity: 1),
            .init(name: "Garlic",              category: .vegetable, unit: .whole,     quantity: 1),
            .init(name: "Yellow onion",        category: .vegetable, unit: .whole,     quantity: 2),
        ],
        .turkish: [
            .init(name: "Olive oil",           category: .oil,       unit: .cup,       quantity: 1),
            .init(name: "Bulgur",              category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Sumac",               category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "Tahini",              category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Pomegranate molasses",category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Dried mint",          category: .herb,      unit: .tablespoon,quantity: 2),
            .init(name: "Cumin",               category: .spice,     unit: .tablespoon,quantity: 2),
        ],
        .german: [
            .init(name: "Mustard",             category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Bread",               category: .grain,     unit: .whole,     quantity: 1),
            .init(name: "Sauerkraut",          category: .vegetable, unit: .cup,       quantity: 2),
            .init(name: "Smoked paprika",      category: .spice,     unit: .tablespoon,quantity: 2),
            .init(name: "White wine vinegar",  category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Bay leaves",          category: .herb,      unit: .piece,     quantity: 4),
            .init(name: "Beef stock",          category: .liquid,    unit: .cup,       quantity: 4),
        ],
        .british: [
            .init(name: "Worcestershire sauce",category: .condiment, unit: .tablespoon,quantity: 3),
            .init(name: "Malt vinegar",        category: .condiment, unit: .cup,       quantity: 0.5),
            .init(name: "Dried thyme",         category: .herb,      unit: .tablespoon,quantity: 2),
            .init(name: "Butter",              category: .dairy,     unit: .ounce,     quantity: 8),
            .init(name: "All-purpose flour",   category: .grain,     unit: .cup,       quantity: 2),
            .init(name: "Chicken stock",       category: .liquid,    unit: .cup,       quantity: 4),
            .init(name: "Yellow onion",        category: .vegetable, unit: .whole,     quantity: 2),
        ],
    ]

    /// Returns deduplicated starter ingredients: universals first, then
    /// cuisine-specific additions in encounter order.
    static func ingredients(for cuisines: [Cuisine]) -> [StarterIngredient] {
        var seen = Set<String>()
        let base = universals.filter { seen.insert($0.name.lowercased()).inserted }
        let extras = cuisines
            .flatMap { kits[$0] ?? [] }
            .filter { seen.insert($0.name.lowercased()).inserted }
        return base + extras
    }
}
