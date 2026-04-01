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

        // Aggregate all ingredients across meals
        var aggregated: [String: AggregatedIngredient] = [:]

        for meal in plan.meals {
            guard let recipe = meal.recipe, recipe.servings > 0 else { continue }
            let servingScale = Double(meal.servings) / Double(recipe.servings)

            for ingredient in recipe.ingredients where !ingredient.isOptional {
                let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard !assumedStaples.contains(key) else { continue }
                let scaledQty = ingredient.amount.quantity * servingScale

                if var existing = aggregated[key] {
                    if existing.unit == ingredient.amount.unit {
                        existing.quantity += scaledQty
                    } else if let converted = MeasurementConversionService.convert(
                        amount: IngredientAmount(quantity: scaledQty, unit: ingredient.amount.unit),
                        to: existing.unit
                    ) {
                        existing.quantity += converted.quantity
                    } else {
                        // Incompatible units (e.g. volume vs weight) — keep as separate entry
                        let altKey = key + "_\(ingredient.amount.unit.rawValue)"
                        aggregated[altKey] = AggregatedIngredient(
                            name: ingredient.name,
                            quantity: scaledQty,
                            unit: ingredient.amount.unit,
                            category: ingredient.category
                        )
                        continue
                    }
                    aggregated[key] = existing
                } else {
                    aggregated[key] = AggregatedIngredient(
                        name: ingredient.name,
                        quantity: scaledQty,
                        unit: ingredient.amount.unit,
                        category: ingredient.category
                    )
                }
            }
        }

        // Subtract pantry stock
        for (key, var agg) in aggregated {
            let pantryMatch = pantryItems.first { item in
                item.name.lowercased().trimmingCharacters(in: .whitespaces) == key
            }

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
        for (_, agg) in aggregated where agg.quantity > 0 {
            let section = storeSectionForCategory(agg.category)
            let item = GroceryItem(
                name: agg.name,
                quantity: agg.quantity,
                unit: agg.unit,
                storeSection: section
            )
            list.items.append(item)
        }

        return list
    }

    // MARK: - Helpers

    /// Ingredients that are assumed to be on hand and don't need to appear on a shopping list.
    private static let assumedStaples: Set<String> = [
        "water", "ice", "ice water", "cold water", "boiling water",
        "salt", "kosher salt", "sea salt", "table salt",
        "black pepper", "pepper", "ground black pepper",
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
        case .nut:       return .snacks
        case .legume:    return .canned
        case .herb:      return .produce
        case .other:     return .other
        }
    }
}
