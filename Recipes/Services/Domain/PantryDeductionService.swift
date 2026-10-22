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
    ///
    /// Two kinds of pantry item are never deducted, because their quantity isn't a
    /// real count: "1 piece" is the app-wide placeholder for "I have some" (every add
    /// path used it before quantities were editable), and staples are assumed to be
    /// kept on hand. The post-cook sheet still lists them so the user can mark them used up.
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
            guard !isPlaceholderQuantity(pantryItem), !pantryItem.isStaple else { continue }

            let needed = IngredientAmount(quantity: ingredient.amount.quantity * scale, unit: ingredient.amount.unit)
            guard let inPantryUnits = MeasurementConversionService.convert(amount: needed, to: pantryItem.unit) else {
                continue // e.g. grams vs cups: no density table, leave the pantry alone
            }

            pantryItem.quantity = max(0, pantryItem.quantity - inPantryUnits.quantity)
            pantryItem.lastUsed = .now
            markRealQuantity(pantryItem)

            if pantryItem.quantity <= 0 {
                fullyConsumed.append(pantryItem)
            }
        }

        return fullyConsumed
    }

    /// "1 piece" means "an unknown amount" throughout the app (see GroceryItem.formattedAmount),
    /// unless the item is known to hold a real count: it was deducted before (3 eggs → 1 egg)
    /// or the user entered a quantity in a pantry form.
    static func isPlaceholderQuantity(_ item: PantryItem) -> Bool {
        item.quantity == 1 && item.unit == .piece && !hasRealQuantity(item)
    }

    // MARK: - Real-quantity marker

    /// IDs of pantry items whose quantity is a real count. Kept in UserDefaults rather
    /// than on PantryItem because a new stored property needs a schema migration, and
    /// `lastUsed` can't serve: the pantry's "Keep" button also sets it. A stale ID for a
    /// deleted item is harmless, since IDs are never reused.
    private static let realQuantityKey = "pantry_realQuantityItemIDs"

    static func hasRealQuantity(_ item: PantryItem) -> Bool {
        let ids = UserDefaults.standard.stringArray(forKey: realQuantityKey) ?? []
        return ids.contains(item.id.uuidString)
    }

    static func markRealQuantity(_ item: PantryItem) {
        var ids = UserDefaults.standard.stringArray(forKey: realQuantityKey) ?? []
        guard !ids.contains(item.id.uuidString) else { return }
        ids.append(item.id.uuidString)
        UserDefaults.standard.set(ids, forKey: realQuantityKey)
    }
}
