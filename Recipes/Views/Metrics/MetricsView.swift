import SwiftUI
import SwiftData
import Charts

// MARK: - Metrics View

struct MetricsView: View {
    @Query private var recipes: [Recipe]
    @Query private var receipts: [GroceryReceipt]

    private var metrics: CookingMetrics {
        MetricsCalculator.calculate(recipes: recipes, receipts: receipts)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overviewCards
                    cuisineChart
                    topIngredientsSection
                    topRecipesSection
                    savingsSection
                }
                .padding()
            }
            .navigationTitle("Cooking Metrics")
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            MetricCard(
                title: "Recipes Cooked",
                value: "\(metrics.totalRecipesCooked)",
                icon: "flame",
                color: .orange
            )
            MetricCard(
                title: "Time Cooking",
                value: formatMinutes(metrics.totalTimeCookingMinutes),
                icon: "clock",
                color: .blue
            )
            MetricCard(
                title: "Time Prepping",
                value: formatMinutes(metrics.totalTimePrepMinutes),
                icon: "scissors",
                color: .green
            )
            MetricCard(
                title: "Grocery Spend",
                value: "$\(Int(metrics.totalGrocerySpend))",
                icon: "cart",
                color: .purple
            )
        }
    }

    // MARK: - Cuisine Chart

    @ViewBuilder
    private var cuisineChart: some View {
        if !metrics.favoriteCuisines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Favourite Cuisines")
                    .font(.headline)

                Chart(metrics.favoriteCuisines.prefix(8)) { cuisine in
                    BarMark(
                        x: .value("Count", cuisine.count),
                        y: .value("Cuisine", cuisine.cuisine.rawValue.capitalized)
                    )
                    .foregroundStyle(.tint)
                }
                .frame(height: 200)
            }
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
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
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
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
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= Int(rating.rounded()) ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Text("\(recipe.cookCount)x")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.1), in: .capsule)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
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
                        .foregroundStyle(.green)
                }
                Spacer()
                Image(systemName: "leaf.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green.opacity(0.3))
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
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
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }
}
