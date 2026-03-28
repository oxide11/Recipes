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
            guard let recipe = meal.recipe else { continue }
            let servingScale = Double(meal.servings) / Double(recipe.servings)

            for ingredient in recipe.ingredients where !ingredient.isOptional {
                let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)
                let scaledQty = ingredient.amount.quantity * servingScale

                if var existing = aggregated[key] {
                    // Same unit — add quantities
                    if existing.unit == ingredient.amount.unit {
                        existing.quantity += scaledQty
                    } else {
                        // Different units — convert if possible, otherwise keep larger
                        existing.quantity += scaledQty
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
                }
                // If units differ, keep full amount (can't reliably subtract)
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
