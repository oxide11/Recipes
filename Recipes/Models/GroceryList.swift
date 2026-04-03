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

    var sortOrder: Int {
        switch self {
        case .produce:       return 0
        case .meat:          return 1
        case .seafood:       return 2
        case .dairy:         return 3
        case .deli:          return 4
        case .bakery:        return 5
        case .dryGoods:      return 6
        case .canned:        return 7
        case .condiments:    return 8
        case .spices:        return 9
        case .international: return 10
        case .frozen:        return 11
        case .snacks:        return 12
        case .beverages:     return 13
        case .other:         return 14
        }
    }
}

// MARK: - StoreSection Pantry Category Mapping

extension StoreSection {
    /// Maps a store section to an IngredientCategory for pantry auto-addition.
    /// Returns nil for non-food sections (`.other`) — callers skip pantry insertion
    /// when this is nil.
    var pantryCategory: IngredientCategory? {
        switch self {
        case .produce:       return .vegetable
        case .meat:          return .protein
        case .seafood:       return .protein
        case .dairy:         return .dairy
        case .bakery:        return .grain
        case .dryGoods:      return .grain
        case .spices:        return .spice
        case .condiments:    return .condiment
        case .beverages:     return .liquid
        case .frozen:        return .other
        case .canned:        return .other
        case .snacks:        return .other
        case .deli:          return .protein
        case .international: return .other
        case .other:         return nil  // non-food, don't add to pantry
        }
    }
}

// MARK: - StoreSection Guessing

extension StoreSection {
    /// Keyword-based section guess from an item name. More specific multi-word
    /// terms come before general single-word ones to avoid substring false positives
    /// (e.g. "nutritional yeast" before "nut", "easter egg" before "egg").
    static func guess(for name: String) -> StoreSection {
        let n = name.lowercased()
        let map: [(StoreSection, [String])] = [
            (.snacks,     ["easter egg","chocolate egg","kinder","candy egg"]),
            (.condiments, ["nutritional yeast","yeast flakes","nooch",
                           "sauce","ketchup","mustard","mayo","mayonnaise","vinegar","oil","dressing",
                           "salsa","hummus","pesto","soy sauce","hot sauce","sriracha","tahini",
                           "fish sauce","oyster sauce","hoisin","worcestershire","miso"]),
            (.produce,    ["apple","banana","berry","berries","spinach","lettuce","tomato","onion","garlic",
                           "pepper","carrot","broccoli","cucumber","lemon","lime","avocado","mushroom",
                           "basil","cilantro","parsley","kale","zucchini","potato","celery","corn",
                           "mango","pineapple","grape","peach","pear","plum","strawberry","blueberry",
                           "raspberry","arugula","beet","radish","leek","fennel","asparagus","squash",
                           "bok choy","cabbage","cauliflower","eggplant","grapefruit","watermelon"]),
            (.dairy,      ["milk","cheese","yogurt","butter","cream","kefir","sour cream",
                           "cottage cheese","ricotta","mozzarella","cheddar","parmesan","feta","brie",
                           "gouda","gruyere","halloumi","quark","crème fraîche"]),
            (.dairy,      ["egg"]),
            (.meat,       ["chicken","beef","pork","turkey","lamb","steak","ground beef","bacon",
                           "sausage","ham","salmon","tuna","shrimp","fish","cod","tilapia","scallop",
                           "crab","lobster","anchovy","sardine","prosciutto","pancetta","chorizo"]),
            (.bakery,     ["bread","bagel","muffin","croissant","bun","roll","tortilla","pita","wrap",
                           "sourdough","focaccia","naan","roti"]),
            (.frozen,     ["frozen","ice cream","popsicle","gelato"]),
            (.spices,     ["salt","pepper","cumin","cinnamon","paprika","oregano","thyme","rosemary",
                           "turmeric","ginger","spice","seasoning","chili flake","bay leaf","clove",
                           "curry","masala","za'atar","sumac","cardamom","coriander","allspice",
                           "nutmeg","cayenne","chili powder","onion powder","garlic powder","dill",
                           "fennel seed","caraway","fenugreek","smoked paprika"]),
            (.dryGoods,   ["pasta","rice","flour","sugar","oat","cereal","quinoa","lentil","bean",
                           "chickpea","noodle","breadcrumb","cracker","granola","barley","couscous",
                           "polenta","farro","bulgur","millet","tapioca","cornstarch","baking soda",
                           "baking powder","cocoa","yeast"]),
            (.beverages,  ["juice","water","soda","coffee","tea","wine","beer","kombucha","sparkling",
                           "almond milk","oat milk","coconut water","electrolyte","protein shake",
                           "cold brew","matcha","cider"]),
            (.snacks,     ["chip","nuts","almond","cashew","walnut","peanut","popcorn","pretzel",
                           "chocolate","candy","cookie","granola bar","trail mix","jerky","rice cake"]),
            (.canned,     ["canned","tomato paste","coconut milk","broth","stock","soup","tinned"]),
        ]
        for (section, keywords) in map {
            if keywords.contains(where: { n.contains($0) }) { return section }
        }
        return .other
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

    /// Returns a formatted amount string, or nil when the quantity/unit is
    /// the default sentinel (1 piece) meaning no amount was specified.
    var formattedAmount: String? {
        guard !(quantity == 1 && unit == .piece) else { return nil }
        let quantityStr = quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
        return "\(quantityStr) \(unit.rawValue)"
    }

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
