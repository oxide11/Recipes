import Foundation
import SwiftData

// MARK: - Shopping List Generator

/// Generates a consolidated shopping list from a meal plan's recipes,
/// merging duplicate ingredients and subtracting pantry stock.
enum ShoppingListGenerator {

    /// Generate a GroceryList from a MealPlan, merging duplicate ingredients
    /// and optionally subtracting what's already in the pantry.
    static func generateList(
        from plan: MealPlan,
        pantryItems: [PantryItem] = [],
        name: String? = nil
    ) -> GroceryList {
        let listName = name ?? "Shopping — \(plan.name)"
        let list = GroceryList(name: listName, mealPlan: plan)
        list.items = generateItems(from: plan, pantryItems: pantryItems)
        return list
    }

    /// Grocery items needed for the plan's meals, merged by canonical ingredient and
    /// net of pantry stock. The app keeps one persistent shopping list, so callers
    /// append these to it rather than creating a new list.
    ///
    /// - Parameters:
    ///   - dateRange: Only meals on these days are included (nil = whole plan).
    ///   - existingItems: Unpurchased items already on the list; their ingredients are skipped.
    static func generateItems(
        from plan: MealPlan,
        dateRange: ClosedRange<Date>? = nil,
        pantryItems: [PantryItem] = [],
        existingItems: [GroceryItem] = []
    ) -> [GroceryItem] {
        // Build canonical pantry index for fast lookup
        let pantryCanonicals = Set(pantryItems.map { IngredientNormalizer.canonicalize($0.name) })
        let alreadyListed = Set(existingItems.filter { !$0.isPurchased }.map { IngredientNormalizer.canonicalize($0.name) })

        // Aggregate all ingredients across meals, keyed by canonical name
        var aggregated: [String: AggregatedIngredient] = [:]

        let calendar = Calendar.current
        let meals = plan.meals.filter { meal in
            guard let dateRange else { return true }
            let day = calendar.startOfDay(for: meal.date)
            return dateRange.contains(day)
        }

        for meal in meals {
            guard let recipe = meal.recipe, recipe.servings > 0 else { continue }
            let servingScale = Double(meal.servings) / Double(recipe.servings)

            for ingredient in recipe.ingredients where !ingredient.isOptional {
                let canonical = IngredientNormalizer.canonicalize(ingredient.name)
                guard !assumedStaples.contains(canonical) else { continue }
                guard !IngredientNormalizer.isAssumedStaple(ingredient.name) else { continue }
                if alreadyListed.contains(canonical) { continue }

                // Skip if pantry already has this (or its canonical form)
                if pantryCanonicals.contains(canonical) { continue }

                // Skip if pantry has a usable substitution — no need to buy
                if IngredientNormalizer.findSubstitute(for: canonical, inPantryCanonicals: pantryCanonicals) != nil { continue }

                let scaledQty = ingredient.amount.quantity * servingScale

                if var existing = aggregated[canonical] {
                    if existing.unit == ingredient.amount.unit {
                        existing.quantity += scaledQty
                    } else if let converted = MeasurementConversionService.convert(
                        amount: IngredientAmount(quantity: scaledQty, unit: ingredient.amount.unit),
                        to: existing.unit
                    ) {
                        existing.quantity += converted.quantity
                    } else {
                        // Incompatible units (e.g. volume vs weight) — keep as separate entry
                        let altKey = canonical + "_\(ingredient.amount.unit.rawValue)"
                        aggregated[altKey] = AggregatedIngredient(
                            name: ingredient.name,
                            quantity: scaledQty,
                            unit: ingredient.amount.unit,
                            category: ingredient.category
                        )
                        continue
                    }
                    aggregated[canonical] = existing
                } else {
                    aggregated[canonical] = AggregatedIngredient(
                        name: ingredient.name,
                        quantity: scaledQty,
                        unit: ingredient.amount.unit,
                        category: ingredient.category
                    )
                }
            }
        }

        // Subtract pantry stock for any remaining items
        // (handles partial coverage — e.g. recipe needs 2 cups, pantry has 1 cup)
        for (key, var agg) in aggregated {
            let canonical = IngredientNormalizer.canonicalize(agg.name)
            let pantryMatch = pantryItems.first { IngredientNormalizer.canonicalize($0.name) == canonical }

            if let pantry = pantryMatch {
                if pantry.unit == agg.unit {
                    agg.quantity = max(0, agg.quantity - pantry.quantity)
                } else if let converted = MeasurementConversionService.convert(
                    amount: IngredientAmount(quantity: pantry.quantity, unit: pantry.unit),
                    to: agg.unit
                ) {
                    agg.quantity = max(0, agg.quantity - converted.quantity)
                }
                // If units are truly incompatible (volume vs weight), keep full amount
            }

            aggregated[key] = agg
        }

        // Convert to GroceryItems (skip items fully covered by pantry)
        return aggregated.values
            .filter { $0.quantity > 0 }
            .sorted { $0.name < $1.name }
            .map { agg in
                GroceryItem(
                    name: agg.name,
                    quantity: (agg.quantity * 100).rounded() / 100,
                    unit: agg.unit,
                    storeSection: storeSectionForCategory(agg.category)
                )
            }
    }

    // MARK: - Helpers

    /// Canonical ingredient names assumed to be on hand — skipped even without pantry data.
    /// These use canonical names (post-canonicalize) so variants collapse automatically.
    private static let assumedStaples: Set<String> = [
        "water", "ice", "ice water", "cold water", "boiling water",
        "salt",   // covers kosher salt, sea salt, table salt via canonicalize()
        "pepper", // covers black pepper, ground black pepper via canonicalize()
    ]

    private struct AggregatedIngredient {
        var name: String
        var quantity: Double
        var unit: MeasurementUnit
        var category: IngredientCategory
    }

    private static func storeSectionForCategory(_ category: IngredientCategory) -> StoreSection {
        switch category {
        case .protein:   return .meat
        case .vegetable: return .produce
        case .fruit:     return .produce
        case .grain:     return .dryGoods
        case .dairy:     return .dairy
        case .spice:     return .spices
        case .oil:       return .condiments
        case .condiment: return .condiments
        case .liquid:    return .beverages
        case .sweetener: return .dryGoods
        case .baking:    return .dryGoods
        case .nut:       return .snacks
        case .legume:    return .canned
        case .herb:      return .produce
        case .other:     return .other
        }
    }
}
