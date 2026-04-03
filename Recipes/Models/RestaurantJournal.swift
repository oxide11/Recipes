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

    // Location coordinates for MapKit
    var latitude: Double?
    var longitude: Double?

    // Maps metadata
    var phoneNumber: String?
    var mapsURL: String?

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    init(
        restaurantName: String,
        location: String? = nil,
        cuisine: Cuisine? = nil,
        dateVisited: Date = .now,
        rating: Int? = nil,
        review: String? = nil,
        wouldRecommend: Bool = true,
        priceRange: PriceRange? = nil,
        tags: [String] = [],
        latitude: Double? = nil,
        longitude: Double? = nil,
        phoneNumber: String? = nil,
        mapsURL: String? = nil
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
        self.latitude = latitude
        self.longitude = longitude
        self.phoneNumber = phoneNumber
        self.mapsURL = mapsURL
    }
}

// MARK: - Dish Entry

struct DishEntry: Codable, Hashable, Sendable, Identifiable {
    /// Not persisted — generated fresh on each decode for ForEach stability within a session.
    var id: UUID = UUID()
    var name: String          // empty string = unnamed
    var description: String?
    var rating: Int?          // 1-5
    var notes: String?
    var wouldOrderAgain: Bool
    var wantToRecreate: Bool
    var photoFilename: String?

    var displayName: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? "Unnamed dish" : name
    }

    // Exclude `id` from Codable so existing stored JSON (which has no "id" key) decodes cleanly.
    enum CodingKeys: String, CodingKey {
        case name, description, rating, notes, wouldOrderAgain, wantToRecreate, photoFilename
    }
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

    // Location coordinates for MapKit
    var latitude: Double?
    var longitude: Double?

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    init(
        restaurantName: String,
        location: String? = nil,
        cuisine: Cuisine? = nil,
        reason: String? = nil,
        sourceURL: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = UUID()
        self.restaurantName = restaurantName
        self.location = location
        self.cuisine = cuisine
        self.reason = reason
        self.sourceURL = sourceURL
        self.dateAdded = .now
        self.hasVisited = false
        self.latitude = latitude
        self.longitude = longitude
    }
}
