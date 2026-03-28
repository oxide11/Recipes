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
