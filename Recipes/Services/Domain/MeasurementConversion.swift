import Foundation

// MARK: - Measurement Conversion Service

/// Automatically converts between imperial and metric measurement systems.
enum MeasurementConversionService {

    // MARK: - Volume Conversions

    private static let volumeToMilliliters: [MeasurementUnit: Double] = [
        .teaspoon:   4.929,
        .tablespoon: 14.787,
        .cup:        236.588,
        .fluidOunce: 29.574,
        .milliliter: 1.0,
        .liter:      1000.0
    ]

    // MARK: - Weight Conversions

    private static let weightToGrams: [MeasurementUnit: Double] = [
        .ounce:    28.3495,
        .pound:    453.592,
        .gram:     1.0,
        .kilogram: 1000.0
    ]

    // MARK: - Convert

    static func convert(
        amount: IngredientAmount,
        to targetUnit: MeasurementUnit
    ) -> IngredientAmount? {
        // Same unit
        if amount.unit == targetUnit {
            return amount
        }

        // Temperature conversion
        if amount.unit == .fahrenheit && targetUnit == .celsius {
            let celsius = (amount.quantity - 32) * 5.0 / 9.0
            return IngredientAmount(quantity: celsius.rounded(toPlaces: 1), unit: .celsius)
        }
        if amount.unit == .celsius && targetUnit == .fahrenheit {
            let fahrenheit = amount.quantity * 9.0 / 5.0 + 32
            return IngredientAmount(quantity: fahrenheit.rounded(toPlaces: 1), unit: .fahrenheit)
        }

        // Volume conversion
        if let sourceML = volumeToMilliliters[amount.unit],
           let targetML = volumeToMilliliters[targetUnit] {
            let ml = amount.quantity * sourceML
            let converted = ml / targetML
            return IngredientAmount(quantity: converted.rounded(toPlaces: 2), unit: targetUnit)
        }

        // Weight conversion
        if let sourceG = weightToGrams[amount.unit],
           let targetG = weightToGrams[targetUnit] {
            let grams = amount.quantity * sourceG
            let converted = grams / targetG
            return IngredientAmount(quantity: converted.rounded(toPlaces: 2), unit: targetUnit)
        }

        // Cannot convert between volume and weight without density
        return nil
    }

    /// Convert all measurements in a recipe to the target system.
    static func convertRecipe(
        ingredients: [Ingredient],
        to system: MeasurementSystem
    ) -> [(Ingredient, IngredientAmount)] {
        ingredients.map { ingredient in
            let targetUnit = preferredUnit(for: ingredient.amount.unit, system: system)
            let converted = convert(amount: ingredient.amount, to: targetUnit) ?? ingredient.amount
            return (ingredient, converted)
        }
    }

    /// Scale a recipe's ingredient amounts by a multiplier.
    static func scale(amount: IngredientAmount, by multiplier: Double) -> IngredientAmount {
        IngredientAmount(
            quantity: (amount.quantity * multiplier).rounded(toPlaces: 2),
            unit: amount.unit
        )
    }

    // MARK: - Helpers

    private static func preferredUnit(
        for unit: MeasurementUnit,
        system: MeasurementSystem
    ) -> MeasurementUnit {
        switch system {
        case .metric:
            switch unit {
            case .teaspoon, .tablespoon, .fluidOunce: return .milliliter
            case .cup:                                 return .milliliter
            case .ounce, .pound:                       return .gram
            case .fahrenheit:                          return .celsius
            default:                                   return unit
            }
        case .imperial:
            switch unit {
            case .milliliter: return .fluidOunce
            case .liter:                return .cup
            case .gram:                 return .ounce
            case .kilogram:             return .pound
            case .celsius:              return .fahrenheit
            default:                    return unit
            }
        }
    }
}

// MARK: - Double Extension

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
