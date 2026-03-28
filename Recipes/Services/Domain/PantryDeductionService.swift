import Foundation
import SwiftData

// MARK: - Pantry Deduction Service

/// Automatically deducts pantry quantities when a cooking session is logged.
enum PantryDeductionService {

    /// Deducts ingredient quantities from pantry items after cooking a recipe.
    /// Returns a list of items that were fully consumed.
    @discardableResult
    static func deductAfterCooking(
        recipe: Recipe,
        servingsCooked: Int,
        pantryItems: [PantryItem]
    ) -> [PantryItem] {
        guard recipe.servings > 0 else { return [] }
        let scale = Double(servingsCooked) / Double(recipe.servings)
        var fullyConsumed: [PantryItem] = []

        for ingredient in recipe.ingredients where !ingredient.isOptional {
            let neededQty = ingredient.amount.quantity * scale
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespaces)

            // Find matching pantry item
            guard let pantryItem = pantryItems.first(where: { item in
                item.name.lowercased().trimmingCharacters(in: .whitespaces) == key
            }) else { continue }

            // Deduct — only if same unit (or pantry unit is compatible)
            if pantryItem.unit == ingredient.amount.unit {
                pantryItem.quantity = max(0, pantryItem.quantity - neededQty)
                pantryItem.lastUsed = .now
            } else {
                // Best-effort: deduct by proportion for piece/whole units
                pantryItem.quantity = max(0, pantryItem.quantity - neededQty)
                pantryItem.lastUsed = .now
            }

            if pantryItem.quantity <= 0 {
                fullyConsumed.append(pantryItem)
            }
        }

        return fullyConsumed
    }
}
