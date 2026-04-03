import SwiftUI

// MARK: - Plan & Shop Segments

enum PlanAndShopSegment: String, CaseIterable {
    case pantry   = "Pantry"
    case mealPlan = "Meal Plan"
    case shopping = "Shopping"
}

// MARK: - Plan & Shop View

/// Combined tab: Pantry → Meal Plan → Shopping.
/// All three sub-views are kept alive simultaneously (opacity swap) so their
/// @Query properties stay warm — no cold-start stutter when switching segments.
struct PlanAndShopView: View {
    /// Lifted to ContentView so the dashboard can jump directly to a segment.
    @Binding var segment: PlanAndShopSegment

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("Section", selection: $segment) {
                ForEach(PlanAndShopSegment.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // All three views rendered at once — only the active one is visible.
            // This keeps @Query caches warm so segment switches are instant.
            ZStack {
                PantryView()      .opacity(segment == .pantry   ? 1 : 0).allowsHitTesting(segment == .pantry)
                MealPlanView()    .opacity(segment == .mealPlan ? 1 : 0).allowsHitTesting(segment == .mealPlan)
                ShoppingListView().opacity(segment == .shopping ? 1 : 0).allowsHitTesting(segment == .shopping)
            }
        }
    }
}
