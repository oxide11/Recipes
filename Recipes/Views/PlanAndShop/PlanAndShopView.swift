import SwiftUI

// MARK: - Cook Segments (Recipes ↔ Meal Plan)

enum CookSegment: String, CaseIterable {
    case recipes  = "Recipes"
    case mealPlan = "Meal Plan"
}

// MARK: - Cook View

/// Combined tab: Recipes ↔ Meal Plan.
/// Both sub-views are kept alive simultaneously (opacity swap) so their
/// @Query properties stay warm — no cold-start stutter when switching segments.
struct CookView: View {
    @Binding var segment: CookSegment

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $segment) {
                ForEach(CookSegment.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ZStack {
                RecipeListView()
                    .opacity(segment == .recipes ? 1 : 0)
                    .allowsHitTesting(segment == .recipes)
                    .ignoresSafeArea(segment == .recipes ? [] : .keyboard)
                MealPlanView()
                    .opacity(segment == .mealPlan ? 1 : 0)
                    .allowsHitTesting(segment == .mealPlan)
                    .ignoresSafeArea(segment == .mealPlan ? [] : .keyboard)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Pantry & Shop Segments (Pantry ↔ Shopping)

enum PantryShopSegment: String, CaseIterable {
    case pantry   = "Pantry"
    case shopping = "Shopping"
}

// MARK: - Pantry & Shop View

/// Combined tab: Pantry ↔ Shopping list.
/// Both sub-views are kept alive simultaneously (opacity swap) so their
/// @Query properties stay warm — no cold-start stutter when switching segments.
struct PantryShopView: View {
    @Binding var segment: PantryShopSegment

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $segment) {
                ForEach(PantryShopSegment.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            ZStack {
                PantryView()
                    .opacity(segment == .pantry ? 1 : 0)
                    .allowsHitTesting(segment == .pantry)
                    .ignoresSafeArea(segment == .pantry ? [] : .keyboard)
                ShoppingListView()
                    .opacity(segment == .shopping ? 1 : 0)
                    .allowsHitTesting(segment == .shopping)
                    .ignoresSafeArea(segment == .shopping ? [] : .keyboard)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

