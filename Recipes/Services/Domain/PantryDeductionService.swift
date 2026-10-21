import Foundation
import SwiftData

// MARK: - Pantry Deduction Service

/// Reduces pantry quantities when a cooking session is logged.
enum PantryDeductionService {

    /// Deducts ingredient quantities from pantry items after cooking a recipe.
    /// Returns the items that were fully used up so the caller can offer to remove them.
    ///
    /// Matching uses canonical ingredient names ("yellow onions" matches "onion").
    /// Quantities are converted to the pantry item's unit when both are volumes or
    /// both are weights; a volume-to-weight mismatch is skipped rather than guessed.
    @discardableResult
    static func deductAfterCooking(
        recipe: Recipe,
        servingsCooked: Int,
        pantryItems: [PantryItem]
    ) -> [PantryItem] {
        guard recipe.servings > 0 else { return [] }
        let scale = Double(max(servingsCooked, 1)) / Double(recipe.servings)
        var fullyConsumed: [PantryItem] = []

        let pantryByCanonical: [String: PantryItem] = Dictionary(
            pantryItems.map { (IngredientNormalizer.canonicalize($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for ingredient in recipe.ingredients where !ingredient.isOptional {
            guard ingredient.amount.unit != .asNeeded, ingredient.amount.quantity > 0 else { continue }
            let key = IngredientNormalizer.canonicalize(ingredient.name)
            guard let pantryItem = pantryByCanonical[key] else { continue }

            let needed = IngredientAmount(quantity: ingredient.amount.quantity * scale, unit: ingredient.amount.unit)
            guard let inPantryUnits = MeasurementConversionService.convert(amount: needed, to: pantryItem.unit) else {
                continue // e.g. grams vs cups: no density table, leave the pantry alone
            }

            pantryItem.quantity = max(0, pantryItem.quantity - inPantryUnits.quantity)
            pantryItem.lastUsed = .now

            if pantryItem.quantity <= 0 {
                fullyConsumed.append(pantryItem)
            }
        }

        return fullyConsumed
    }
}
