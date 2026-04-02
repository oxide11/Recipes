import SwiftUI

// MARK: - Plan & Shop Segments

private enum PlanAndShopSegment: String, CaseIterable {
    case pantry   = "Pantry"
    case mealPlan = "Meal Plan"
    case shopping = "Shopping"
}

// MARK: - Plan & Shop View

/// Combined tab: Pantry → Meal Plan → Shopping.
/// Each segment renders the existing standalone view unchanged.
struct PlanAndShopView: View {
    @State private var segment: PlanAndShopSegment = .mealPlan

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .pantry:   PantryView()
                case .mealPlan: MealPlanView()
                case .shopping: ShoppingListView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $segment) {
                        ForEach(PlanAndShopSegment.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
            }
        }
    }
}
