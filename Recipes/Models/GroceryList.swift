import Foundation
import SwiftData

// MARK: - Store Section

enum StoreSection: String, Codable, CaseIterable, Sendable {
    case produce
    case meat
    case seafood
    case dairy
    case bakery
    case frozen
    case canned
    case dryGoods
    case spices
    case condiments
    case beverages
    case snacks
    case deli
    case international
    case other

    var displayName: String {
        switch self {
        case .produce:       return "Produce"
        case .meat:          return "Meat & Poultry"
        case .seafood:       return "Seafood"
        case .dairy:         return "Dairy & Eggs"
        case .bakery:        return "Bakery"
        case .frozen:        return "Frozen"
        case .canned:        return "Canned Goods"
        case .dryGoods:      return "Dry Goods & Pasta"
        case .spices:        return "Spices & Seasonings"
        case .condiments:    return "Condiments & Sauces"
        case .beverages:     return "Beverages"
        case .snacks:        return "Snacks"
        case .deli:          return "Deli"
        case .international: return "International"
        case .other:         return "Other"
        }
    }
}

// MARK: - Grocery Item

@Model
final class GroceryItem {
    var id: UUID
    var name: String
    var quantity: Double
    var unit: MeasurementUnit
    var storeSection: StoreSection
    var isPurchased: Bool
    var estimatedPrice: Double?
    var actualPrice: Double?
    var substituteFor: String?
    var notes: String?
    var isStaple: Bool = false
    /// EKReminder.calendarItemIdentifier for the linked Reminders item, if any.
    var remindersIdentifier: String? = nil

    init(
        name: String,
        quantity: Double,
        unit: MeasurementUnit,
        storeSection: StoreSection = .other,
        estimatedPrice: Double? = nil,
        isStaple: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.storeSection = storeSection
        self.isPurchased = false
        self.estimatedPrice = estimatedPrice
        self.isStaple = isStaple
    }
}

// MARK: - Grocery List

@Model
final class GroceryList {
    var id: UUID
    var name: String
    var dateCreated: Date

    @Relationship(deleteRule: .cascade)
    var items: [GroceryItem]

    @Relationship(deleteRule: .nullify)
    var mealPlan: MealPlan?

    @Relationship(deleteRule: .nullify)
    var receipts: [GroceryReceipt]

    var totalEstimatedCost: Double {
        items.compactMap(\.estimatedPrice).reduce(0, +)
    }

    var totalActualCost: Double {
        items.compactMap(\.actualPrice).reduce(0, +)
    }

    var progress: Double {
        guard !items.isEmpty else { return 0 }
        let purchased = items.filter(\.isPurchased).count
        return Double(purchased) / Double(items.count)
    }

    /// Items grouped by store section for the guided shopping experience.
    var itemsBySection: [StoreSection: [GroceryItem]] {
        Dictionary(grouping: items, by: \.storeSection)
    }

    init(name: String, mealPlan: MealPlan? = nil) {
        self.id = UUID()
        self.name = name
        self.dateCreated = .now
        self.items = []
        self.mealPlan = mealPlan
        self.receipts = []
    }
}

// MARK: - Grocery Receipt

@Model
final class GroceryReceipt {
    var id: UUID
    var imageData: Data?
    var storeName: String?
    var date: Date
    var totalAmount: Double
    var items: [ReceiptLineItem]

    @Relationship(deleteRule: .nullify)
    var groceryList: GroceryList?

    init(storeName: String? = nil, date: Date = .now, totalAmount: Double = 0) {
        self.id = UUID()
        self.storeName = storeName
        self.date = date
        self.totalAmount = totalAmount
        self.items = []
    }
}

struct ReceiptLineItem: Codable, Hashable, Sendable {
    var name: String
    var price: Double
    var quantity: Int
}
