import Foundation
import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Ingredient Category (Color Coding)

enum IngredientCategory: String, Codable, CaseIterable, Sendable {
    case protein
    case vegetable
    case fruit
    case grain
    case dairy
    case spice
    case herb
    case baking
    case oil
    case condiment
    case liquid
    case sweetener
    case nut
    case legume
    case other

    var sortOrder: Int {
        switch self {
        case .protein:   return 0
        case .vegetable: return 1
        case .fruit:     return 2
        case .grain:     return 3
        case .legume:    return 4
        case .nut:       return 5
        case .dairy:     return 6
        case .baking:    return 7
        case .sweetener: return 8
        case .spice:     return 9
        case .herb:      return 10
        case .oil:       return 11
        case .condiment: return 12
        case .liquid:    return 13
        case .other:     return 14
        }
    }

    var displayColor: IngredientColor {
        switch self {
        case .protein:   return .red
        case .vegetable: return .green
        case .fruit:     return .orange
        case .grain:     return .amber
        case .dairy:     return .blue
        case .spice:     return .purple
        case .herb:      return .lime
        case .baking:    return .pink
        case .oil:       return .yellow
        case .condiment: return .teal
        case .liquid:    return .cyan
        case .sweetener: return .pink
        case .nut:       return .brown
        case .legume:    return .mint
        case .other:     return .gray
        }
    }

    var storeSection: StoreSection {
        switch self {
        case .protein:   return .meat
        case .vegetable: return .produce
        case .fruit:     return .produce
        case .grain:     return .dryGoods
        case .dairy:     return .dairy
        case .spice:     return .spices
        case .herb:      return .produce
        case .baking:    return .dryGoods
        case .oil:       return .condiments
        case .condiment: return .condiments
        case .liquid:    return .beverages
        case .sweetener: return .dryGoods
        case .nut:       return .snacks
        case .legume:    return .canned
        case .other:     return .other
        }
    }

    /// Human-readable section name used in the pantry view.
    var pantrySection: String {
        switch self {
        case .protein:             return "Protein"
        case .vegetable, .fruit:   return "Produce"
        case .grain, .legume, .nut:return "Dry Goods"
        case .dairy:               return "Dairy"
        case .baking, .sweetener:  return "Baking"
        case .spice, .herb:        return "Spice Rack"
        case .oil, .condiment,
             .liquid:              return "Condiments & Oils"
        case .other:               return "Other"
        }
    }

}

enum IngredientColor: String, Codable, Sendable {
    case red, green, orange, amber, blue, purple, yellow
    case teal, cyan, pink, brown, mint, lime, gray

    var swiftUIColor: Color {
        switch self {
        case .red:    return Brand.ingredientProtein
        case .green:  return Brand.ingredientProduce
        case .orange: return Brand.warmTan
        case .amber:  return Brand.ingredientDryGoods
        case .blue:   return Brand.ingredientDairy
        case .purple: return Brand.ingredientSeasoning
        case .yellow: return Brand.warmTan.opacity(0.8)
        case .teal:   return Brand.ingredientLiquid
        case .cyan:   return Brand.ingredientLiquid.opacity(0.8)
        case .pink:   return Brand.spiceRed.opacity(0.6)
        case .brown:  return Brand.ingredientDryGoods.opacity(0.8)
        case .mint:   return Brand.herbGreen.opacity(0.7)
        case .lime:   return Brand.herbGreen.opacity(0.5)
        case .gray:   return Brand.muted
        }
    }
}

// MARK: - Season

enum Season: String, Codable, CaseIterable, Sendable {
    case spring, summer, autumn, winter

    static var current: Season { current(for: .northern) }

    static func current(for hemisphere: Hemisphere) -> Season {
        let month = Calendar.current.component(.month, from: .now)
        switch hemisphere {
        case .northern:
            switch month {
            case 4...6:  return .spring   // Apr–Jun: produce arrives ~Apr 1
            case 7...9:  return .summer
            case 10...11: return .autumn
            default:     return .winter   // Dec–Mar
            }
        case .southern:
            switch month {
            case 4...6:  return .autumn
            case 7...9:  return .winter
            case 10...11: return .spring
            default:     return .summer   // Dec–Mar
            }
        }
    }

    /// The season that follows this one.
    var next: Season {
        switch self {
        case .spring: return .summer
        case .summer: return .autumn
        case .autumn: return .winter
        case .winter: return .spring
        }
    }

    /// The calendar month (1-based) on which this season starts for a given hemisphere.
    func startMonth(for hemisphere: Hemisphere) -> Int {
        switch hemisphere {
        case .northern:
            switch self {
            case .spring: return 4   // Apr 1 — when spring produce actually arrives
            case .summer: return 7
            case .autumn: return 10
            case .winter: return 12
            }
        case .southern:
            switch self {
            case .spring: return 10
            case .summer: return 1
            case .autumn: return 4
            case .winter: return 7
            }
        }
    }
}

// MARK: - Measurement Unit

enum MeasurementUnit: String, Codable, CaseIterable, Sendable {
    // Volume
    case teaspoon, tablespoon, cup, fluidOunce
    case milliliter, liter
    // Weight
    case ounce, pound, gram, kilogram
    // Count
    case piece, pinch, dash, bunch, clove, slice, whole, can
    // Unquantified
    case asNeeded
    // Temperature
    case fahrenheit, celsius

    var isMetric: Bool {
        switch self {
        case .milliliter, .liter, .gram, .kilogram, .celsius:
            return true
        default:
            return false
        }
    }

    var isImperial: Bool {
        switch self {
        case .teaspoon, .tablespoon, .cup, .fluidOunce, .ounce, .pound, .fahrenheit:
            return true
        default:
            return false
        }
    }
}

// MARK: - Ingredient Amount

struct IngredientAmount: Codable, Hashable, Sendable {
    var quantity: Double
    var unit: MeasurementUnit

    var displayString: String {
        if unit == .asNeeded {
            return quantity == 0 ? "remaining" : "as needed"
        }
        return "\(Self.formatQuantity(quantity)) \(unit.rawValue)"
    }

    /// A sentinel amount for step chips where the instruction says "remaining X".
    static let remaining = IngredientAmount(quantity: 0, unit: .asNeeded)

    static func formatQuantity(_ quantity: Double) -> String {
        let whole = Int(quantity)
        let fraction = quantity - Double(whole)

        // Common fractions with tolerance
        let fractions: [(value: Double, symbol: String)] = [
            (1.0/8,  "⅛"), (1.0/4,  "¼"), (1.0/3,  "⅓"),
            (3.0/8,  "⅜"), (1.0/2,  "½"), (5.0/8,  "⅝"),
            (2.0/3,  "⅔"), (3.0/4,  "¾"), (7.0/8,  "⅞")
        ]
        let tolerance = 0.04

        if fraction < tolerance {
            // Whole number
            return "\(whole)"
        }

        if let match = fractions.first(where: { abs(fraction - $0.value) < tolerance }) {
            return whole > 0 ? "\(whole)\(match.symbol)" : match.symbol
        }

        // Fallback to 1 decimal place
        return String(format: "%.1f", quantity)
    }
}

// MARK: - Ingredient Model

@Model
final class Ingredient {
    var id: UUID
    var name: String
    var category: IngredientCategory
    var amount: IngredientAmount
    var isOptional: Bool
    var seasonalAvailability: [Season]
    var barcode: String?
    var notes: String?

    /// Dietary flags
    var isGlutenFree: Bool
    var isDairyFree: Bool
    var isVegan: Bool
    var isNutFree: Bool

    init(
        name: String,
        category: IngredientCategory,
        amount: IngredientAmount,
        isOptional: Bool = false,
        seasonalAvailability: [Season] = Season.allCases,
        barcode: String? = nil,
        notes: String? = nil,
        isGlutenFree: Bool = false,
        isDairyFree: Bool = false,
        isVegan: Bool = false,
        isNutFree: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.amount = amount
        self.isOptional = isOptional
        self.seasonalAvailability = seasonalAvailability
        self.barcode = barcode
        self.notes = notes
        self.isGlutenFree = isGlutenFree
        self.isDairyFree = isDairyFree
        self.isVegan = isVegan
        self.isNutFree = isNutFree
    }
}

// MARK: - Pantry Item

@Model
final class PantryItem {
    var id: UUID
    var name: String
    var category: IngredientCategory
    var barcode: String?
    var quantity: Double
    var unit: MeasurementUnit
    var expirationDate: Date?
    var dateAdded: Date
    var lastUsed: Date?
    var isFrozen: Bool = false
    var isStaple: Bool = false
    var purchasePrice: Double? = nil

    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        // Expired only after the end of the expiration day, not during it.
        let endOfDay = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: expiration) ?? expiration)
        return .now >= endOfDay
    }

    var isExpiringSoon: Bool {
        guard let expiration = expirationDate else { return false }
        let threeDays = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        return expiration <= threeDays && !isExpired
    }

    init(
        name: String,
        category: IngredientCategory,
        barcode: String? = nil,
        quantity: Double,
        unit: MeasurementUnit,
        expirationDate: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.barcode = barcode
        self.quantity = quantity
        self.unit = unit
        self.expirationDate = expirationDate
        self.dateAdded = .now
    }
}
