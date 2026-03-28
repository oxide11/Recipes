import Foundation
import FoundationModels

// MARK: - Nutritional Info

/// Macro and micronutrient data for a recipe or single serving.
struct NutritionalInfo: Codable, Hashable, Sendable {
    // Macros
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double

    // Optional micronutrients
    var sodiumMg: Double?
    var cholesterolMg: Double?
    var saturatedFatGrams: Double?
    var transFatGrams: Double?
    var potassiumMg: Double?
    var vitaminAPercent: Double?
    var vitaminCPercent: Double?
    var calciumPercent: Double?
    var ironPercent: Double?

    var servingSize: String?

    /// Computed macro percentages based on total calories.
    var proteinPercentage: Double {
        guard calories > 0 else { return 0 }
        return (proteinGrams * 4.0 / calories) * 100
    }

    var carbsPercentage: Double {
        guard calories > 0 else { return 0 }
        return (carbsGrams * 4.0 / calories) * 100
    }

    var fatPercentage: Double {
        guard calories > 0 else { return 0 }
        return (fatGrams * 9.0 / calories) * 100
    }

    init(
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        sugarGrams: Double = 0,
        sodiumMg: Double? = nil,
        cholesterolMg: Double? = nil,
        saturatedFatGrams: Double? = nil,
        transFatGrams: Double? = nil,
        potassiumMg: Double? = nil,
        vitaminAPercent: Double? = nil,
        vitaminCPercent: Double? = nil,
        calciumPercent: Double? = nil,
        ironPercent: Double? = nil,
        servingSize: String? = nil
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
        self.cholesterolMg = cholesterolMg
        self.saturatedFatGrams = saturatedFatGrams
        self.transFatGrams = transFatGrams
        self.potassiumMg = potassiumMg
        self.vitaminAPercent = vitaminAPercent
        self.vitaminCPercent = vitaminCPercent
        self.calciumPercent = calciumPercent
        self.ironPercent = ironPercent
        self.servingSize = servingSize
    }
}

// MARK: - AI-Generable Nutritional Estimate

/// Used with Apple Foundation Models to generate nutritional estimates from recipe text.
@Generable
struct NutritionalEstimate {
    @Guide(description: "Estimated total calories per serving")
    var caloriesPerServing: Int

    @Guide(description: "Estimated protein in grams per serving")
    var proteinGrams: Int

    @Guide(description: "Estimated carbohydrates in grams per serving")
    var carbsGrams: Int

    @Guide(description: "Estimated fat in grams per serving")
    var fatGrams: Int

    @Guide(description: "Estimated fiber in grams per serving")
    var fiberGrams: Int

    @Guide(description: "Estimated sugar in grams per serving")
    var sugarGrams: Int
}
