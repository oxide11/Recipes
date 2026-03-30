import Foundation

// MARK: - Open Food Facts API Service

/// Integrates with the Open Food Facts API to look up product information
/// from barcodes. This is a free, open-source product database.
enum OpenFoodFactsService {

    struct Product: Sendable {
        var name: String
        var brand: String?
        var category: IngredientCategory
        var barcode: String
        var imageURL: String?
        var nutriments: ProductNutriments?
        var quantity: String?
    }

    struct ProductNutriments: Sendable {
        var caloriesPer100g: Double?
        var fatPer100g: Double?
        var carbsPer100g: Double?
        var proteinPer100g: Double?
        var fiberPer100g: Double?
        var sugarPer100g: Double?
        var sodiumPer100g: Double?
    }

    // MARK: - Lookup

    /// Look up a product by barcode using the Open Food Facts API.
    static func lookup(barcode: String) async throws -> Product? {
        let sanitized = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(sanitized).json?fields=product_name,brands,categories_tags,image_url,nutriments,quantity"

        guard let url = URL(string: urlString) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("RecipesApp/1.0 iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let status = json?["status"] as? Int, status == 1,
              let productData = json?["product"] as? [String: Any] else {
            return nil
        }

        return parseProduct(from: productData, barcode: barcode)
    }

    // MARK: - Search

    /// Search for products by name.
    static func search(query: String, page: Int = 1) async throws -> [Product] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&json=1&page=\(page)&page_size=10&fields=product_name,brands,categories_tags,code,image_url,nutriments,quantity"

        guard let url = URL(string: urlString) else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("RecipesApp/1.0 iOS", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let products = json?["products"] as? [[String: Any]] else {
            return []
        }

        return products.compactMap { parseProduct(from: $0, barcode: $0["code"] as? String ?? "") }
    }

    // MARK: - Parsing

    private static func parseProduct(from data: [String: Any], barcode: String) -> Product? {
        guard let name = data["product_name"] as? String, !name.isEmpty else {
            return nil
        }

        let brand = data["brands"] as? String
        let imageURL = data["image_url"] as? String
        let quantity = data["quantity"] as? String
        let categoryTags = data["categories_tags"] as? [String] ?? []
        let category = inferCategory(from: categoryTags)

        var nutriments: ProductNutriments?
        if let nutriData = data["nutriments"] as? [String: Any] {
            nutriments = ProductNutriments(
                caloriesPer100g: nutriData["energy-kcal_100g"] as? Double,
                fatPer100g: nutriData["fat_100g"] as? Double,
                carbsPer100g: nutriData["carbohydrates_100g"] as? Double,
                proteinPer100g: nutriData["proteins_100g"] as? Double,
                fiberPer100g: nutriData["fiber_100g"] as? Double,
                sugarPer100g: nutriData["sugars_100g"] as? Double,
                sodiumPer100g: nutriData["sodium_100g"] as? Double
            )
        }

        return Product(
            name: name,
            brand: brand,
            category: category,
            barcode: barcode,
            imageURL: imageURL,
            nutriments: nutriments,
            quantity: quantity
        )
    }

    /// Infer an IngredientCategory from Open Food Facts category tags.
    private static func inferCategory(from tags: [String]) -> IngredientCategory {
        IngredientNormalizer.inferCategory(fromTags: tags)
    }
}
