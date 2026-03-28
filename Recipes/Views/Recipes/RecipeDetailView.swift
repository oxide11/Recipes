import SwiftUI
import SwiftData

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext

    @Environment(AIServiceRouter.self) private var aiRouter
    @State private var showingVariations = false
    @State private var showingLogEntry = false
    @State private var selectedServings: Int
    @State private var showNutrition = false
    @State private var checkedIngredients: Set<UUID> = []
    @State private var isEstimatingNutrition = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _selectedServings = State(initialValue: recipe.servings)
    }

    private var servingMultiplier: Double {
        guard recipe.servings > 0 else { return 1.0 }
        return Double(selectedServings) / Double(recipe.servings)
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
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                }
                .sensoryFeedback(.impact(flexibility: .soft), trigger: recipe.isFavorite)
                .accessibilityLabel(recipe.isFavorite ? "Remove from favourites" : "Add to favourites")

                Menu {
                    Button("Log Cooking Session", systemImage: "flame") {
                        showingLogEntry = true
                    }
                    ShareLink(item: recipeShareText)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
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
                .accessibilityLabel("Decrease servings")
                Text("\(selectedServings)")
                    .fontWeight(.semibold)
                Button { selectedServings += 1 } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Increase servings")
                .sensoryFeedback(.selection, trigger: selectedServings)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }

    private var sortedIngredients: [Ingredient] {
        recipe.ingredients.sorted { $0.category.sortOrder < $1.category.sortOrder }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if !checkedIngredients.isEmpty {
                    Button("Clear") {
                        withAnimation { checkedIngredients.removeAll() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Brand.warmTan)
                }
            }

            ForEach(sortedIngredients) { ingredient in
                IngredientRow(
                    ingredient: ingredient,
                    servingMultiplier: servingMultiplier,
                    isChecked: checkedIngredients.contains(ingredient.id),
                    onToggle: {
                        withAnimation(.snappy(duration: 0.2)) {
                            if checkedIngredients.contains(ingredient.id) {
                                checkedIngredients.remove(ingredient.id)
                            } else {
                                checkedIngredients.insert(ingredient.id)
                            }
                        }
                    }
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
                DirectionStepView(
                    direction: direction,
                    allIngredients: recipe.ingredients,
                    servingMultiplier: servingMultiplier
                )
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
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy) { showNutrition.toggle() }
                } label: {
                    HStack {
                        Text("Nutrition Facts")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: showNutrition ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if showNutrition {
                    NutritionCardView(info: nutrition)
                }
            }
        } else {
            Button {
                Task { await estimateNutrition() }
            } label: {
                HStack(spacing: 8) {
                    if isEstimatingNutrition {
                        ProgressView().tint(Brand.warmTan)
                        Text("Estimating…")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Estimate Nutrition")
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Brand.warmTan)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isEstimatingNutrition)
        }
    }

    private func estimateNutrition() async {
        isEstimatingNutrition = true
        defer { isEstimatingNutrition = false }

        let ingredientDescriptions = recipe.ingredients.map {
            "\($0.amount.displayString) \($0.name)"
        }

        // Build a prompt for cloud fallback
        let ingredientList = ingredientDescriptions.joined(separator: ", ")
        let prompt = """
        Estimate nutrition per serving for a recipe with \(recipe.servings) servings.
        Ingredients: \(ingredientList)
        Return ONLY a JSON object, no prose:
        {"calories":0,"proteinGrams":0,"carbsGrams":0,"fatGrams":0,"fiberGrams":0,"sugarGrams":0,"sodiumMg":0}
        """

        do {
            // Try on-device structured generation first
            if await aiRouter.foundationModelService.isAvailable {
                let estimate = try await aiRouter.foundationModelService.estimateNutrition(
                    ingredients: ingredientDescriptions,
                    servings: recipe.servings
                )
                recipe.nutritionalInfo = NutritionalInfo(
                    calories: Double(estimate.caloriesPerServing),
                    proteinGrams: Double(estimate.proteinGrams),
                    carbsGrams: Double(estimate.carbsGrams),
                    fatGrams: Double(estimate.fatGrams),
                    fiberGrams: Double(estimate.fiberGrams),
                    sugarGrams: Double(estimate.sugarGrams)
                )
                showNutrition = true
                return
            }

            // Cloud fallback — parse JSON response
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .nutritionalEstimation)
            var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("```") {
                cleaned = cleaned.components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
            }
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONDecoder().decode(NutritionEstimateResponse.self, from: data) {
                recipe.nutritionalInfo = NutritionalInfo(
                    calories: json.calories,
                    proteinGrams: json.proteinGrams,
                    carbsGrams: json.carbsGrams,
                    fatGrams: json.fatGrams,
                    fiberGrams: json.fiberGrams,
                    sugarGrams: json.sugarGrams,
                    sodiumMg: json.sodiumMg
                )
                showNutrition = true
            }
        } catch {
            // Silently fail — button will remain visible so user can retry
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
                    .background(in: .rect(cornerRadius: 8))
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var cookingLogSection: some View {
        if !recipe.cookingLog.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Cooking Log")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("Cooked \(recipe.cookCount)×")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Average rating
                if let avg = recipe.averageRating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(avg.rounded()) ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .font(.subheadline)
                        }
                        Text(String(format: "%.1f avg", avg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Photo strip from log entries that have photos
                let photos = recipe.cookingLog.compactMap(\.photo)
                if !photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(photos) { photo in
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(.rect(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                // Individual log entries
                ForEach(recipe.cookingLog.sorted { $0.date > $1.date }) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let rating = entry.rating {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                        }
                        if let notes = entry.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !entry.substitutionsMade.isEmpty {
                            Text("Subs: " + entry.substitutionsMade.joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    if entry.id != recipe.cookingLog.sorted(by: { $0.date > $1.date }).last?.id {
                        Divider()
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
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

// MARK: - Nutrition Estimate Response (cloud fallback)

private struct NutritionEstimateResponse: Decodable {
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    let sodiumMg: Double?
}
