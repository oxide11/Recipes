import SwiftUI
import SwiftData

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext

    @State private var showingVariations = false
    @State private var showingLogEntry = false
    @State private var selectedServings: Int
    @State private var showNutrition = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _selectedServings = State(initialValue: recipe.servings)
    }

    private var servingMultiplier: Double {
        Double(selectedServings) / Double(recipe.servings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                quickInfoBar
                ingredientsSection
                directionsSection
                safeTemperaturesSection
                nutritionSection
                variationsSection
                cookingLogSection
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                }

                Menu {
                    Button("Log Cooking Session", systemImage: "flame") {
                        showingLogEntry = true
                    }
                    ShareLink(item: recipeShareText)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingLogEntry) {
            CookingLogEntryView(recipe: recipe)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = recipe.summary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                ForEach(recipe.dietaryRestrictions, id: \.self) { restriction in
                    Text(restriction.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.1), in: .capsule)
                }
            }
        }
    }

    private var quickInfoBar: some View {
        HStack(spacing: 0) {
            infoItem(title: "Prep", value: "\(recipe.prepTimeMinutes)m", icon: "scissors")
            Divider().frame(height: 30)
            infoItem(title: "Cook", value: "\(recipe.cookTimeMinutes)m", icon: "flame")
            Divider().frame(height: 30)
            infoItem(title: "Difficulty", value: recipe.difficulty.rawValue.capitalized, icon: "chart.bar")
            Divider().frame(height: 30)

            // Adjustable servings
            HStack(spacing: 4) {
                Button { if selectedServings > 1 { selectedServings -= 1 } } label: {
                    Image(systemName: "minus.circle")
                }
                Text("\(selectedServings)")
                    .fontWeight(.semibold)
                Button { selectedServings += 1 } label: {
                    Image(systemName: "plus.circle")
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(recipe.ingredients) { ingredient in
                IngredientRow(
                    ingredient: ingredient,
                    servingMultiplier: servingMultiplier
                )
            }
        }
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directions")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(recipe.directions) { direction in
                DirectionStepView(direction: direction)
            }
        }
    }

    @ViewBuilder
    private var safeTemperaturesSection: some View {
        if !recipe.safeTemperatures.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Safe Temperatures")
                    .font(.title2)
                    .fontWeight(.bold)

                ForEach(recipe.safeTemperatures, id: \.self) { temp in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(temp.protein)
                                .fontWeight(.medium)
                            if let notes = temp.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(temp.minimumFahrenheit))°F / \(Int(temp.minimumCelsius))°C")
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            if let rest = temp.restTimeMinutes {
                                Text("Rest: \(rest) min")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(.red.opacity(0.05), in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var nutritionSection: some View {
        if let nutrition = recipe.nutritionalInfo {
            DisclosureGroup("Nutrition Facts", isExpanded: $showNutrition) {
                NutritionCardView(info: nutrition)
            }
            .font(.title2)
            .fontWeight(.bold)
        }
    }

    @ViewBuilder
    private var variationsSection: some View {
        if !recipe.variations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Variations")
                    .font(.title2)
                    .fontWeight(.bold)

                ForEach(recipe.variations) { variation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(variation.name)
                            .fontWeight(.medium)
                        if let desc = variation.recipeDescription {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var cookingLogSection: some View {
        if !recipe.cookingLog.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cooking Log")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Cooked \(recipe.cookCount) time\(recipe.cookCount == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)

                if let avg = recipe.averageRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(avg.rounded()) ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                        Text(String(format: "%.1f", avg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func infoItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var recipeShareText: String {
        var text = recipe.title + "\n\n"
        text += "Ingredients:\n"
        for ing in recipe.ingredients {
            text += "- \(ing.amount.displayString) \(ing.name)\n"
        }
        text += "\nDirections:\n"
        for dir in recipe.directions {
            text += "\(dir.stepNumber). \(dir.instruction)\n"
        }
        return text
    }
}
