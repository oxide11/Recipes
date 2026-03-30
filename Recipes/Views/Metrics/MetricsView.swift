import SwiftUI
import SwiftData
import Charts

// MARK: - Metrics View

struct MetricsView: View {
    @Query private var recipes: [Recipe]
    @Query private var receipts: [GroceryReceipt]
    @Query private var restaurantEntries: [RestaurantJournalEntry]

    @State private var metrics = CookingMetrics()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overviewCards
                    cuisineChart
                    topIngredientsSection
                    topRecipesSection
                    savingsSection
                    restaurantStatsSection
                }
                .padding()
            }
            .navigationTitle("Cooking Metrics")
            .toolbarBackground(.automatic, for: .navigationBar)
            .task(id: recipes.count) {
                metrics = MetricsCalculator.calculate(recipes: recipes, receipts: receipts, restaurantEntries: restaurantEntries)
            }
            .task(id: receipts.count) {
                metrics = MetricsCalculator.calculate(recipes: recipes, receipts: receipts, restaurantEntries: restaurantEntries)
            }
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            MetricCard(
                title: "Recipes Cooked",
                value: "\(metrics.totalRecipesCooked)",
                icon: "flame",
                color: Brand.warmTan
            )
            MetricCard(
                title: "Time Cooking",
                value: formatMinutes(metrics.totalTimeCookingMinutes),
                icon: "clock",
                color: Brand.ingredientDairy
            )
            MetricCard(
                title: "Time Prepping",
                value: formatMinutes(metrics.totalTimePrepMinutes),
                icon: "scissors",
                color: Brand.herbGreen
            )
            MetricCard(
                title: "Grocery Spend",
                value: "$\(Int(metrics.totalGrocerySpend))",
                icon: "cart",
                color: Brand.ingredientSeasoning
            )

            if metrics.totalTimeSavedMinutes != 0 {
                MetricCard(
                    title: "Time Saved",
                    value: formatMinutes(metrics.totalTimeSavedMinutes),
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    color: Brand.herbGreen
                )
            }
        }
    }

    // MARK: - Cuisine Chart

    private let cuisineBarColors: [Color] = [
        Brand.spiceRed, Brand.warmTan, Brand.herbGreen,
        Brand.ingredientDairy, Brand.ingredientSeasoning, Brand.ingredientLiquid,
        Brand.muted, Brand.cream
    ]

    @ViewBuilder
    private var cuisineChart: some View {
        let cuisines = Array(metrics.favoriteCuisines.prefix(8))
        if !cuisines.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Most Cooked Cuisines")
                        .font(.headline)
                    Text("Based on your cooking history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart(Array(cuisines.enumerated()), id: \.offset) { index, cuisine in
                    BarMark(
                        x: .value("Count", cuisine.count),
                        y: .value("Cuisine", cuisine.cuisine.rawValue.capitalized)
                    )
                    .foregroundStyle(cuisineBarColors[index % cuisineBarColors.count])
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                        Text("\(cuisine.count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .frame(height: CGFloat(cuisines.count) * 36 + 16)
            }
            .padding()
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Top Ingredients

    @ViewBuilder
    private var topIngredientsSection: some View {
        if !metrics.mostUsedIngredients.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Most Used Ingredients")
                    .font(.headline)

                ForEach(metrics.mostUsedIngredients.prefix(10)) { ingredient in
                    HStack {
                        Text(ingredient.name.capitalized)
                        Spacer()
                        Text("\(ingredient.count)x")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .glassCard()
        }
    }

    // MARK: - Top Recipes

    @ViewBuilder
    private var topRecipesSection: some View {
        if !metrics.topRecipes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Most Cooked Recipes")
                    .font(.headline)

                ForEach(metrics.topRecipes.prefix(5)) { recipe in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(recipe.title)
                                .fontWeight(.medium)
                            if let rating = recipe.averageRating {
                                StarRatingView(rating: Int(rating.rounded()))
                            }
                        }
                        Spacer()
                        Text("\(recipe.cookCount)x")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Brand.warmTan.opacity(0.15), in: .capsule)
                    }
                }
            }
            .padding()
            .glassCard()
        }
    }

    // MARK: - Savings

    private var savingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated Savings")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("By cooking at home")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(Int(metrics.estimatedDiningOutSavings))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(Brand.herbGreen)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Brand.herbGreen.opacity(0.3))
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Restaurant Stats

    @ViewBuilder
    private var restaurantStatsSection: some View {
        if metrics.totalRestaurantsVisited > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Restaurant Journal")
                    .font(.headline)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    MetricCard(
                        title: "Visited",
                        value: "\(metrics.totalRestaurantsVisited)",
                        icon: "fork.knife",
                        color: Brand.warmTan
                    )
                    MetricCard(
                        title: "Dishes Tried",
                        value: "\(metrics.totalDishesOrdered)",
                        icon: "list.clipboard",
                        color: Brand.herbGreen
                    )
                }

                if let avgRating = metrics.averageRestaurantRating {
                    HStack {
                        Text("Average Rating")
                            .font(.subheadline)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(avgRating.rounded()) ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(Brand.warmTan)
                            }
                        }
                    }
                }

                if let lastVisit = metrics.lastRestaurantVisitDate {
                    HStack {
                        Text("Last Visit")
                            .font(.subheadline)
                        Spacer()
                        Text(lastVisit, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !metrics.topRestaurantCuisines.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top Cuisines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(metrics.topRestaurantCuisines.prefix(5)) { cuisine in
                            HStack {
                                Text(cuisine.cuisine.rawValue.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(cuisine.count)x")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding()
            .glassCard()
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
