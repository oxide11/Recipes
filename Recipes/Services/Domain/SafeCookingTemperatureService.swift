import Foundation

// MARK: - Safe Cooking Temperature Service

/// Provides USDA-recommended safe minimum internal cooking temperatures
/// for proteins and other foods requiring temperature monitoring.
enum SafeCookingTemperatureService {

    static let temperatures: [SafeTemperature] = [
        // Poultry
        SafeTemperature(protein: "Chicken (whole)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "All parts must reach 165°F"),
        SafeTemperature(protein: "Chicken (breast)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: nil),
        SafeTemperature(protein: "Chicken (thigh)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "Dark meat is better at 175-180°F for texture"),
        SafeTemperature(protein: "Turkey (whole)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: 20, notes: "Let rest before carving"),
        SafeTemperature(protein: "Turkey (breast)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: 10, notes: nil),
        SafeTemperature(protein: "Duck", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: 10, notes: "Breast can be served medium at 135°F per preference"),
        SafeTemperature(protein: "Ground poultry", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: nil),

        // Beef
        SafeTemperature(protein: "Beef steak (rare)", minimumFahrenheit: 125, minimumCelsius: 52, restTimeMinutes: 3, notes: "USDA recommends 145°F; 125°F is common restaurant rare"),
        SafeTemperature(protein: "Beef steak (medium-rare)", minimumFahrenheit: 135, minimumCelsius: 57, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Beef steak (medium)", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA recommended minimum"),
        SafeTemperature(protein: "Beef steak (medium-well)", minimumFahrenheit: 150, minimumCelsius: 66, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Beef steak (well-done)", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Beef roast", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 10, notes: nil),
        SafeTemperature(protein: "Ground beef", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: "No rest time needed for ground meat"),

        // Pork
        SafeTemperature(protein: "Pork chop", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Pork tenderloin", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Pork roast", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 10, notes: nil),
        SafeTemperature(protein: "Pulled pork (shoulder)", minimumFahrenheit: 195, minimumCelsius: 91, restTimeMinutes: 15, notes: "Higher temp for tenderness and shredability"),
        SafeTemperature(protein: "Ground pork", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: nil),
        SafeTemperature(protein: "Ham (fresh)", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Ham (pre-cooked, reheating)", minimumFahrenheit: 140, minimumCelsius: 60, restTimeMinutes: nil, notes: nil),

        // Seafood
        SafeTemperature(protein: "Fish (fin fish)", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: nil, notes: "Flesh should be opaque and flake easily"),
        SafeTemperature(protein: "Salmon", minimumFahrenheit: 125, minimumCelsius: 52, restTimeMinutes: nil, notes: "USDA says 145°F; many chefs prefer 125°F for medium"),
        SafeTemperature(protein: "Tuna (seared)", minimumFahrenheit: 115, minimumCelsius: 46, restTimeMinutes: nil, notes: "Sushi-grade tuna can be served rare"),
        SafeTemperature(protein: "Shrimp", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: nil, notes: "Should be pink and opaque"),
        SafeTemperature(protein: "Lobster", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: nil, notes: "Shell turns red, flesh is opaque"),
        SafeTemperature(protein: "Scallops", minimumFahrenheit: 130, minimumCelsius: 54, restTimeMinutes: nil, notes: "Should be opaque and firm"),

        // Lamb
        SafeTemperature(protein: "Lamb chop (medium-rare)", minimumFahrenheit: 135, minimumCelsius: 57, restTimeMinutes: 3, notes: nil),
        SafeTemperature(protein: "Lamb chop (medium)", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA recommended minimum"),
        SafeTemperature(protein: "Lamb roast", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 10, notes: nil),
        SafeTemperature(protein: "Ground lamb", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: nil),

        // Other
        SafeTemperature(protein: "Eggs", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: "Cook until yolk and white are firm"),
        SafeTemperature(protein: "Egg dishes (casseroles)", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: nil),
        SafeTemperature(protein: "Leftovers (reheating)", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "Bring to 165°F throughout"),
    ]

    /// Look up safe temperatures for a protein.
    static func lookup(protein: String) -> [SafeTemperature] {
        let query = protein.lowercased()
        return temperatures.filter {
            $0.protein.lowercased().contains(query)
        }
    }

    /// Get the USDA minimum safe temperature for a protein.
    static func minimumSafeTemperature(for protein: String) -> SafeTemperature? {
        lookup(protein: protein).first
    }

    // MARK: - Ingredient → Safe Temperature

    /// USDA minimums for a species when a recipe names no specific cut. Built here
    /// rather than borrowed from a cut row so an automatic badge never shows a
    /// chef-preference temperature (rare steak, seared tuna, 125°F salmon) or the
    /// wrong cut's name.
    private static let usdaChicken   = SafeTemperature(protein: "Chicken", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "All poultry must reach 165°F")
    private static let usdaTurkey    = SafeTemperature(protein: "Turkey", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "All poultry must reach 165°F")
    private static let usdaPoultry   = SafeTemperature(protein: "Poultry", minimumFahrenheit: 165, minimumCelsius: 74, restTimeMinutes: nil, notes: "All poultry must reach 165°F")
    private static let usdaBeef      = SafeTemperature(protein: "Beef", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA minimum for whole cuts")
    private static let usdaPork      = SafeTemperature(protein: "Pork", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA minimum for whole cuts")
    private static let usdaLamb      = SafeTemperature(protein: "Lamb", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA minimum for whole cuts")
    private static let usdaVeal      = SafeTemperature(protein: "Veal", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: 3, notes: "USDA minimum for whole cuts")
    private static let usdaGroundVeal = SafeTemperature(protein: "Ground veal", minimumFahrenheit: 160, minimumCelsius: 71, restTimeMinutes: nil, notes: nil)
    private static let usdaShellfish = SafeTemperature(protein: "Shellfish", minimumFahrenheit: 145, minimumCelsius: 63, restTimeMinutes: nil, notes: "Flesh should be pearly and opaque")

    private static func entry(_ protein: String) -> SafeTemperature? {
        temperatures.first { $0.protein == protein }
    }

    /// Head nouns that mean "not a piece of protein cooked to temperature":
    /// "chicken stock", "fish sauce", "hamburger buns", "beef fat", "egg noodles".
    private static let nonProteinHeads: Set<String> = [
        "broth", "stock", "bouillon", "base", "sauce", "gravy", "noodle", "pasta",
        "bun", "cracker", "powder", "seasoning", "rub", "flavor", "flavour", "flavoring",
        "paste", "extract", "fat", "lard", "tallow", "schmaltz", "gelatin", "dripping",
        "granule", "cube", "bit", "skin", "bone", "jerky", "chip", "spread", "pate",
        "salad", "sandwich", "soup",
    ]

    /// Words anywhere in the name that rule out a badge: plant-based look-alikes,
    /// and cured, canned or dried forms that are not cooked to a safe temperature.
    private static let nonProteinWords: Set<String> = [
        "eggplant", "veggie", "vegetable", "vegetarian", "vegan", "plant", "imitation",
        "tofu", "tempeh", "seitan", "bean", "lentil", "chickpea", "mushroom",
        "cauliflower", "jackfruit", "canned", "tinned", "jerky", "cured", "dried", "powdered",
        // Cured pork is cooked to crisp or eaten as is, not to a temperature.
        "bacon", "pancetta", "prosciutto", "guanciale", "salami", "pepperoni", "lardon",
    ]

    private static let finFish: [String] = [
        "fish", "salmon", "tuna", "cod", "halibut", "tilapia", "trout", "haddock",
        "snapper", "bass", "mahi", "swordfish", "catfish", "mackerel", "sardine",
        "sole", "pollock", "branzino", "grouper", "perch", "flounder",
    ]

    /// The USDA safe temperature for an ingredient as written in a recipe, e.g.
    /// "boneless chicken thighs" → Chicken (thigh), 165°F. Nil when the ingredient
    /// isn't a raw protein that gets cooked to temperature.
    ///
    /// Matching is on whole words (with simple plurals), so "eggplant", "beefsteak
    /// tomato" and "graham crackers" never match "egg", "beef" or "ham". Eggs are
    /// deliberately excluded: they appear in most baked goods, where a 160°F badge
    /// would land on a mixing step. Shellfish without a temperature rule (clams,
    /// mussels, oysters: cook until the shells open) are excluded too.
    static func safeTemperature(forIngredientNamed name: String) -> SafeTemperature? {
        let words = name.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        guard let head = words.last else { return nil }
        let wordSet = Set(words)
        func has(_ k: String) -> Bool { wordSet.contains(k) || wordSet.contains(k + "s") || wordSet.contains(k + "es") }
        func hasAny(_ ks: [String]) -> Bool { ks.contains(where: has) }

        let headSingular: String = head.hasSuffix("es") && nonProteinHeads.contains(String(head.dropLast(2)))
            ? String(head.dropLast(2))
            : (head.hasSuffix("s") ? String(head.dropLast()) : head)
        if nonProteinHeads.contains(head) || nonProteinHeads.contains(headSingular) { return nil }
        if words.contains(where: nonProteinWords.contains) || wordSet.contains(where: { w in nonProteinWords.contains(String(w.dropLast())) && w.hasSuffix("s") }) {
            return nil
        }

        let gameBirds = ["hen", "quail", "goose", "pheasant", "poultry"]
        let poultry = hasAny(["chicken", "turkey", "duck"]) || hasAny(gameBirds)
        let namedMeat = poultry || hasAny(["beef", "pork", "lamb", "veal", "meat"])
        let ground = hasAny(["ground", "minced", "mince"]) && namedMeat   // not "ground cumin"
        let groundForm = hasAny(["burger", "hamburger", "meatball", "meatloaf", "patty"]) || wordSet.contains("patties")
        let sausage = hasAny(["sausage", "chorizo", "bratwurst", "kielbasa"])

        // Ground meat and anything made from it: 160°F (165°F for poultry).
        if ground || groundForm || sausage {
            if poultry { return entry("Ground poultry") }
            if has("lamb") { return entry("Ground lamb") }
            if has("veal") { return usdaGroundVeal }
            if has("pork") || sausage { return entry("Ground pork") }
            return entry("Ground beef")
        }

        // Poultry: 165°F.
        if has("turkey") {
            if has("breast") { return entry("Turkey (breast)") }
            if has("whole") { return entry("Turkey (whole)") }
            return usdaTurkey
        }
        if has("chicken") {
            if has("thigh") { return entry("Chicken (thigh)") }
            if has("breast") { return entry("Chicken (breast)") }
            if has("whole") { return entry("Chicken (whole)") }
            return usdaChicken
        }
        if has("duck") { return entry("Duck") }
        if hasAny(gameBirds) { return usdaPoultry }

        // Species before cut words, so "pork steak", "ham steak" and "tuna steak"
        // never fall into the beef-steak rows.
        if has("pork") {
            if hasAny(["shoulder", "butt", "pulled"]) { return entry("Pulled pork (shoulder)") }
            if has("chop") { return entry("Pork chop") }
            if has("tenderloin") { return entry("Pork tenderloin") }
            if hasAny(["roast", "loin"]) { return entry("Pork roast") }
            return usdaPork
        }
        if has("ham") {
            // Most recipe ham is fully cooked; raw ham is labelled "fresh ham".
            return has("fresh") ? entry("Ham (fresh)") : entry("Ham (pre-cooked, reheating)")
        }
        if has("lamb") {
            if hasAny(["chop", "rack", "cutlet"]) { return entry("Lamb chop (medium)") }
            if hasAny(["roast", "leg", "shoulder"]) { return entry("Lamb roast") }
            return usdaLamb
        }
        if has("veal") { return usdaVeal }

        // Seafood: USDA 145°F. Smoked fish is ready to eat.
        if hasAny(finFish) {
            return has("smoked") ? nil : entry("Fish (fin fish)")
        }
        if hasAny(["shrimp", "prawn"]) { return entry("Shrimp") }
        if has("lobster") { return entry("Lobster") }
        if hasAny(["scallop", "crab", "crawfish", "crayfish", "langoustine"]) { return usdaShellfish }

        // Beef, including a bare "steak" or a named steak cut.
        let steakCuts = ["steak", "ribeye", "sirloin", "strip", "filet", "porterhouse", "flank", "skirt", "hanger", "tenderloin"]
        let roastCuts = ["roast", "brisket", "chuck", "rump", "round", "prime", "rib"]
        if has("beef") || hasAny(steakCuts) || has("brisket") {
            if hasAny(steakCuts) { return entry("Beef steak (medium)") }
            if hasAny(roastCuts) { return entry("Beef roast") }
            return usdaBeef
        }

        return nil
    }

    /// Get all temperature entries grouped by protein type.
    static var grouped: [String: [SafeTemperature]] {
        let categories = ["Chicken", "Turkey", "Duck", "Beef", "Pork", "Ham",
                          "Fish", "Salmon", "Tuna", "Shrimp", "Lobster", "Scallop",
                          "Lamb", "Egg", "Leftover"]
        var result: [String: [SafeTemperature]] = [:]
        for category in categories {
            let matches = lookup(protein: category)
            if !matches.isEmpty {
                result[category] = matches
            }
        }
        return result
    }
}
