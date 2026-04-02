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
    @State private var isInRecipeDetail = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $segment) {
                ForEach(PlanAndShopSegment.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(height: isInRecipeDetail ? 0 : nil)
            .opacity(isInRecipeDetail ? 0 : 1)
            .clipped()
            .animation(.easeInOut(duration: 0.22), value: isInRecipeDetail)

            // Content
            switch segment {
            case .pantry:
                PantryView()
            case .mealPlan:
                MealPlanView(isInDetail: $isInRecipeDetail)
            case .shopping:
                ShoppingListView()
            }
        }
    }
}
