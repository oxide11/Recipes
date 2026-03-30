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
    case oil
    case condiment
    case liquid
    case sweetener
    case nut
    case legume
    case herb
    case other

    var sortOrder: Int {
        switch self {
        case .protein:   return 0
        case .vegetable: return 1
        case .fruit:     return 2
        case .grain:     return 3
        case .dairy:     return 4
        case .spice:     return 5
        case .oil:       return 6
        case .condiment: return 7
        case .liquid:    return 8
        case .sweetener: return 9
        case .nut:       return 10
        case .legume:    return 11
        case .herb:      return 12
        case .other:     return 13
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
        case .oil:       return .yellow
        case .condiment: return .teal
        case .liquid:    return .cyan
        case .sweetener: return .pink
        case .nut:       return .brown
        case .legume:    return .mint
        case .herb:      return .lime
        case .other:     return .gray
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

    static var current: Season {
        let month = Calendar.current.component(.month, from: .now)
        switch month {
        case 3...5:  return .spring
        case 6...8:  return .summer
        case 9...11: return .autumn
        default:     return .winter
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
    case piece, pinch, dash, bunch, clove, slice, whole
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
        let formatted = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", quantity)
            : String(format: "%.1f", quantity)
        return "\(formatted) \(unit.rawValue)"
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
    var purchasePrice: Double? = nil

    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return expiration < .now
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
