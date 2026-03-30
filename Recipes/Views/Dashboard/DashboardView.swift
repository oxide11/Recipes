import SwiftUI
import SwiftData

// MARK: - Dashboard View (Mise Tab)

struct DashboardView: View {
    @Query(sort: \PantryItem.expirationDate) private var pantryItems: [PantryItem]
    @Query private var plannedMeals: [PlannedMeal]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query private var receipts: [GroceryReceipt]
    @Query private var profiles: [UserProfile]

    private var userName: String {
        profiles.first?.displayName ?? ""
    }

    private var todaysMeals: [PlannedMeal] {
        let today = Calendar.current.startOfDay(for: Date())
        return plannedMeals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    private var expiringItems: [PantryItem] {
        pantryItems.filter { $0.isExpiringSoon && !$0.isExpired }
    }

    private var quickRecipes: [Recipe] {
        recipes.filter { $0.estimatedTotalMinutes <= 30 }
    }

    private var weeklySpend: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return receipts.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.totalAmount }
    }

    private var weeklyCookCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return recipes.reduce(0) { total, recipe in
            total + recipe.cookingLog.filter { $0.date >= weekAgo }.count
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    todaysMealsSection
                    expiringSoonSection
                    quickRecipesSection
                    weeklySummarySection
                }
                .padding()
            }
            .background(Brand.midnight)
            .navigationTitle("Mise")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.miseDisplay)
                .foregroundStyle(Brand.cream)

            Text(DashboardView.dateString)
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = userName.isEmpty ? "" : ", \(userName)"
        switch hour {
        case 5..<12:  return "Good Morning\(name)"
        case 12..<17: return "Good Afternoon\(name)"
        case 17..<22: return "Good Evening\(name)"
        default:      return "Good Night\(name)"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    private static var dateString: String {
        dateFormatter.string(from: .now)
    }

    // MARK: - Today's Meals

    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Meals")
                .font(.miseHeading)
                .foregroundStyle(Brand.cream)

            if todaysMeals.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title3)
                        .foregroundStyle(Brand.muted)
                    Text("No meals planned today — head to Plan & Shop to get started.")
                        .font(.miseBody)
                        .foregroundStyle(Brand.muted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            } else {
                ForEach(todaysMeals, id: \.id) { meal in
                    if let recipe = meal.recipe {
                        NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                            mealRow(meal: meal, recipeName: recipe.title)
                        }
                        .buttonStyle(.plain)
                    } else {
                        mealRow(meal: meal, recipeName: "Unplanned")
                    }
                }
            }
        }
    }

    private func mealRow(meal: PlannedMeal, recipeName: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType.displayName)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
                Text(recipeName)
                    .font(.miseBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Brand.cream)
            }

            Spacer()

            Circle()
                .fill(colorForMealType(meal.mealType).opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: meal.isCompleted ? "checkmark" : "fork.knife")
                        .font(.callout)
                        .foregroundStyle(colorForMealType(meal.mealType))
                }
        }
        .padding()
        .glassCard()
    }

    private func colorForMealType(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch:     return Brand.herbGreen
        case .dinner:    return Brand.spiceRed
        case .snack:     return Brand.warmTan
        default:         return Brand.warmTan
        }
    }

    // MARK: - Expiring Soon

    private var expiringSoonSection: some View {
        Group {
            if !expiringItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expiring Soon")
                        .font(.miseHeading)
                        .foregroundStyle(Brand.cream)

                    ForEach(expiringItems.prefix(5), id: \.id) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.miseBody)
                                    .foregroundStyle(Brand.cream)
                                if let expDate = item.expirationDate {
                                    Text(daysUntilText(expDate))
                                        .font(.miseMeta)
                                        .foregroundStyle(Brand.spiceRed)
                                }
                            }

                            Spacer()

                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(Brand.spiceRed.opacity(0.7))
                        }
                        .padding()
                        .glassCard()
                    }
                }
            }
        }
    }

    private func daysUntilText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days <= 0 { return "Expires today" }
        if days == 1 { return "Expires tomorrow" }
        return "Expires in \(days) days"
    }

    // MARK: - Quick Recipes

    private var quickRecipesSection: some View {
        Group {
            if !quickRecipes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Recipes")
                        .font(.miseHeading)
                        .foregroundStyle(Brand.cream)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(quickRecipes.prefix(10), id: \.id) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                    RecipeCardCompact(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Weekly Summary

    private var weeklySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.miseHeading)
                .foregroundStyle(Brand.cream)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Cooked",
                    value: "\(weeklyCookCount)",
                    icon: "flame",
                    color: Brand.warmTan
                )
                MetricCard(
                    title: "Pantry Items",
                    value: "\(pantryItems.count)",
                    icon: "archivebox",
                    color: Brand.herbGreen
                )
                MetricCard(
                    title: "Recipes",
                    value: "\(recipes.count)",
                    icon: "book.closed",
                    color: Brand.warmTan
                )
                MetricCard(
                    title: "Spent",
                    value: "$\(Int(weeklySpend))",
                    icon: "dollarsign.circle",
                    color: Brand.spiceRed
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("Dashboard - iPhone") {
    DashboardView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}

#Preview("Dashboard - With Data") {
    DashboardView()
        .environment(AIServiceRouter())
        .modelContainer(previewContainer)
}
