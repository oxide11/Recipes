import Testing
@testable import Recipes

// MARK: - Measurement Conversion Tests

@Suite("Measurement Conversions")
struct MeasurementConversionTests {

    @Test("Convert cups to milliliters")
    func cupsToMilliliters() {
        let amount = IngredientAmount(quantity: 1, unit: .cup)
        let result = MeasurementConversionService.convert(amount: amount, to: .milliliter)
        #expect(result != nil)
        #expect(result!.unit == .milliliter)
        #expect(abs(result!.quantity - 236.59) < 0.1)
    }

    @Test("Convert Fahrenheit to Celsius")
    func fahrenheitToCelsius() {
        let amount = IngredientAmount(quantity: 350, unit: .fahrenheit)
        let result = MeasurementConversionService.convert(amount: amount, to: .celsius)
        #expect(result != nil)
        #expect(result!.unit == .celsius)
        #expect(abs(result!.quantity - 176.7) < 0.1)
    }

    @Test("Convert ounces to grams")
    func ouncesToGrams() {
        let amount = IngredientAmount(quantity: 8, unit: .ounce)
        let result = MeasurementConversionService.convert(amount: amount, to: .gram)
        #expect(result != nil)
        #expect(abs(result!.quantity - 226.8) < 0.1)
    }

    @Test("Scale ingredient amount")
    func scaleAmount() {
        let amount = IngredientAmount(quantity: 2, unit: .cup)
        let scaled = MeasurementConversionService.scale(amount: amount, by: 1.5)
        #expect(scaled.quantity == 3.0)
        #expect(scaled.unit == .cup)
    }

    @Test("Same unit returns unchanged")
    func sameUnit() {
        let amount = IngredientAmount(quantity: 5, unit: .gram)
        let result = MeasurementConversionService.convert(amount: amount, to: .gram)
        #expect(result != nil)
        #expect(result!.quantity == 5)
    }
}

// MARK: - Substitution Engine Tests

@Suite("Substitution Engine")
struct SubstitutionEngineTests {

    @Test("Find butter substitutions")
    func butterSubstitutions() {
        let subs = SubstitutionEngine.findSubstitutions(for: "butter")
        #expect(!subs.isEmpty)
    }

    @Test("Filter by dietary restriction")
    func veganSubstitutions() {
        let subs = SubstitutionEngine.findSubstitutions(for: "milk", restrictions: [.vegan])
        #expect(!subs.isEmpty)
        for sub in subs {
            #expect(sub.dietaryBenefit.contains(.vegan))
        }
    }

    @Test("Unknown ingredient returns empty")
    func unknownIngredient() {
        let subs = SubstitutionEngine.findSubstitutions(for: "unicorn horn")
        #expect(subs.isEmpty)
    }
}

// MARK: - Seasonal Awareness Tests

@Suite("Seasonal Awareness")
struct SeasonalAwarenessTests {

    @Test("Currently in season returns results")
    func currentSeason() {
        let inSeason = SeasonalAwarenessService.currentlyInSeason()
        #expect(!inSeason.isEmpty)
    }

    @Test("Year-round ingredients are always in season")
    func yearRoundIngredients() {
        #expect(SeasonalAwarenessService.isInSeason("onion"))
        #expect(SeasonalAwarenessService.isInSeason("garlic"))
    }

    @Test("Unknown ingredients default to in-season")
    func unknownIngredient() {
        #expect(SeasonalAwarenessService.isInSeason("dragonscale pepper"))
    }

    @Test("Seasonality score calculates correctly")
    func seasonalityScore() {
        let score = SeasonalAwarenessService.seasonalityScore(ingredientNames: ["onion", "garlic", "potato"])
        #expect(score > 0)
    }
}

// MARK: - Safe Cooking Temperature Tests

@Suite("Safe Cooking Temperatures")
struct SafeCookingTemperatureTests {

    @Test("Lookup chicken returns results")
    func chickenTemps() {
        let temps = SafeCookingTemperatureService.lookup(protein: "chicken")
        #expect(!temps.isEmpty)
        #expect(temps.first!.minimumFahrenheit == 165)
    }

    @Test("Lookup beef steak returns multiple doneness levels")
    func beefSteakTemps() {
        let temps = SafeCookingTemperatureService.lookup(protein: "beef steak")
        #expect(temps.count >= 4)
    }
}

// MARK: - Recipe as Code Parser Tests

@Suite("Recipe as Code Parser")
struct RecipeAsCodeParserTests {

    @Test("Parse basic recipe definition")
    func parseBasic() throws {
        let input = """
        title: "Test Pasta"
        servings: 4
        cuisine: italian

        ingredients:
          - pasta: 400g
          - garlic: 4 cloves, minced
          - olive oil: 2 tbsp

        outcomes:
          - pasta is al dente
          - garlic is golden
        """

        let definition = try RecipeDefinitionParser.parse(from: input)
        #expect(definition.title == "Test Pasta")
        #expect(definition.servings == 4)
        #expect(definition.ingredients.count == 3)
        #expect(definition.outcomes.count == 2)
    }
}

// MARK: - Nutritional Info Tests

@Suite("Nutritional Info")
struct NutritionalInfoTests {

    @Test("Macro percentages sum roughly to 100")
    func macroPercentages() {
        let info = NutritionalInfo(
            calories: 500,
            proteinGrams: 30,
            carbsGrams: 50,
            fatGrams: 20
        )
        let total = info.proteinPercentage + info.carbsPercentage + info.fatPercentage
        #expect(abs(total - 100) < 5) // Allow small rounding margin
    }

    @Test("Zero calories returns zero percentages")
    func zeroCalories() {
        let info = NutritionalInfo(calories: 0)
        #expect(info.proteinPercentage == 0)
        #expect(info.carbsPercentage == 0)
        #expect(info.fatPercentage == 0)
    }
}
