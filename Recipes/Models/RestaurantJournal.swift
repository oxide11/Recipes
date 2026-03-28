import Foundation
import SwiftData

// MARK: - Restaurant Journal Entry

@Model
final class RestaurantJournalEntry {
    var id: UUID
    var restaurantName: String
    var location: String?
    var cuisine: Cuisine?
    var dateVisited: Date
    var rating: Int?  // 1-5
    var review: String?
    var dishesOrdered: [DishEntry]

    @Relationship(deleteRule: .cascade)
    var photos: [RecipePhoto]

    var wouldRecommend: Bool
    var priceRange: PriceRange?
    var tags: [String]

    init(
        restaurantName: String,
        location: String? = nil,
        cuisine: Cuisine? = nil,
        dateVisited: Date = .now,
        rating: Int? = nil,
        review: String? = nil,
        wouldRecommend: Bool = true,
        priceRange: PriceRange? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.restaurantName = restaurantName
        self.location = location
        self.cuisine = cuisine
        self.dateVisited = dateVisited
        self.rating = rating
        self.review = review
        self.dishesOrdered = []
        self.photos = []
        self.wouldRecommend = wouldRecommend
        self.priceRange = priceRange
        self.tags = tags
    }
}

// MARK: - Dish Entry

struct DishEntry: Codable, Hashable, Sendable {
    var name: String
    var description: String?
    var rating: Int?  // 1-5
    var notes: String?
    var wouldOrderAgain: Bool
    var wantToRecreate: Bool
}

// MARK: - Price Range

enum PriceRange: String, Codable, CaseIterable, Sendable {
    case budget     // $
    case moderate   // $$
    case upscale    // $$$
    case fine       // $$$$

    var displayString: String {
        switch self {
        case .budget:   return "$"
        case .moderate: return "$$"
        case .upscale:  return "$$$"
        case .fine:     return "$$$$"
        }
    }
}

// MARK: - Restaurant Want-to-Try

@Model
final class RestaurantWantToTry {
    var id: UUID
    var restaurantName: String
    var location: String?
    var cuisine: Cuisine?
    var reason: String?
    var sourceURL: String?
    var dateAdded: Date
    var hasVisited: Bool

    init(
        restaurantName: String,
        location: String? = nil,
        cuisine: Cuisine? = nil,
        reason: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = UUID()
        self.restaurantName = restaurantName
        self.location = location
        self.cuisine = cuisine
        self.reason = reason
        self.sourceURL = sourceURL
        self.dateAdded = .now
        self.hasVisited = false
    }
}
