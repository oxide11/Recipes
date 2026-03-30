import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var modelContext

    @Environment(AIServiceRouter.self) private var aiRouter
    @State private var showingVariations = false
    @State private var showingLogEntry = false
    @State private var showingCookingMode = false
    @State private var showingBlinkHelp = false
    @State private var showingExport = false
    @State private var selectedServings: Int
    @State private var showNutrition = false
    @State private var checkedIngredients: Set<UUID> = []
    @State private var isEstimatingNutrition = false
    @State private var nutritionEstimateError: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isEditing = false

    init(recipe: Recipe) {
        self.recipe = recipe
        _selectedServings = State(initialValue: recipe.servings)
    }

    private var servingMultiplier: Double {
        guard recipe.servings > 0 else { return 1.0 }
        return Double(selectedServings) / Double(recipe.servings)
    }

    /// Maps lowercased ingredient names to their category color for syntax-style highlighting.
    private var ingredientColors: [String: Color] {
        var map: [String: Color] = [:]
        for ingredient in recipe.ingredients {
            map[ingredient.name.lowercased()] = ingredient.category.displayColor.swiftUIColor
        }
        return map
    }

    /// Maps lowercased ingredient names to their category for lookup.
    private var ingredientCategories: [String: IngredientCategory] {
        var map: [String: IngredientCategory] = [:]
        for ingredient in recipe.ingredients {
            map[ingredient.name.lowercased()] = ingredient.category
        }
        return map
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                photoGallerySection
                quickInfoBar
                ingredientsSection
                directionsSection
                safeTemperaturesSection

                if isEditing {
                    tagsSection
                    dietaryRestrictionsEditSection
                }

                nutritionSection
                variationsSection
                cookingLogSection
            }
            .padding()
            .animation(.snappy(duration: 0.25), value: isEditing)
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.snappy(duration: 0.25)) { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                }
                .fontWeight(isEditing ? .semibold : .regular)

                if !isEditing {
                    Button {
                        recipe.isFavorite.toggle()
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: recipe.isFavorite)
                    .accessibilityLabel(recipe.isFavorite ? "Remove from favourites" : "Add to favourites")

                    Button {
                        showingCookingMode = true
                    } label: {
                        Image(systemName: "play.circle")
                    }
                    .accessibilityLabel("Start Cooking Mode")

                    Menu {
                        Button("Log Cooking Session", systemImage: "flame") {
                            showingLogEntry = true
                        }
                        Button("Hands-Free Setup", systemImage: "accessibility") {
                            showingBlinkHelp = true
                        }
                        Button("Export Recipe", systemImage: "square.and.arrow.up") {
                            showingExport = true
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Add Photo", systemImage: "camera")
                        }
                        ShareLink(item: recipeShareText)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showingLogEntry) {
            CookingLogEntryView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showingCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .sheet(isPresented: $showingBlinkHelp) {
            BlinkNavigationHelpView()
        }
        .sheet(isPresented: $showingExport) {
            RecipeExportView(recipe: recipe)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let photo = RecipePhoto(imageData: data)
                    recipe.photos.append(photo)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var photoGallerySection: some View {
        if !recipe.photos.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Photos")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(recipe.photos.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(recipe.photos) { photo in
                            if let uiImage = UIImage(data: photo.imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 200, height: 150)
                                    .clipShape(.rect(cornerRadius: 12))
                                    .overlay(alignment: .bottomTrailing) {
                                        if let caption = photo.caption {
                                            Text(caption)
                                                .font(.caption2)
                                                .padding(4)
                                                .background(in: .capsule)
                                                .glassEffect(.regular, in: .capsule)
                                                .padding(8)
                                        }
                                    }
                                    .contextMenu {
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            recipe.photos.removeAll { $0.id == photo.id }
                                        }
                                    }
                            }
                        }
                    }
                }
                .contentMargins(.vertical, 12, for: .scrollContent)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                TextField("Recipe Title", text: $recipe.title)
                    .font(.title2)
                    .fontWeight(.bold)

                TextField("Summary", text: Binding(
                    get: { recipe.summary ?? "" },
                    set: { recipe.summary = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2...5)
            } else {
                if let summary = recipe.summary {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            if !recipe.dietaryRestrictions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(recipe.dietaryRestrictions, id: \.self) { restriction in
                        Text(restriction.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.tint.opacity(0.1), in: .capsule)
                    }
                }
            }
        }
    }

    private var quickInfoBar: some View {
        Group {
            if isEditing {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        editableInfoItem(title: "Prep (min)", value: $recipe.prepTimeMinutes, icon: "scissors")
                        Divider().frame(height: 40)
                        editableInfoItem(title: "Cook (min)", value: $recipe.cookTimeMinutes, icon: "flame")
                    }

                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Image(systemName: "chart.bar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Difficulty", selection: $recipe.difficulty) {
                                ForEach(RecipeDifficulty.allCases, id: \.self) { d in
                                    Text(d.rawValue.capitalized).tag(d)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)

                        Divider().frame(height: 40)

                        VStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("Cuisine", selection: $recipe.cuisine) {
                                ForEach(Cuisine.allCases, id: \.self) { c in
                                    Text(c.rawValue.capitalized).tag(c)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 4) {
                        Text("Servings:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper("\(recipe.servings)", value: $recipe.servings, in: 1...50)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .onChange(of: recipe.servings) { _, newValue in
                                selectedServings = newValue
                            }
                    }
                }
                .padding()
                .background(in: .rect(cornerRadius: 12))
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            } else {
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
        }
    }

    private var sortedIngredients: [Ingredient] {
        recipe.ingredients.sorted(by: { $0.category.sortOrder < $1.category.sortOrder })
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if isEditing {
                    Button {
                        let newIngredient = Ingredient(
                            name: "",
                            category: .other,
                            amount: IngredientAmount(quantity: 1, unit: .piece)
                        )
                        recipe.ingredients.append(newIngredient)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Brand.herbGreen)
                    }
                } else if !checkedIngredients.isEmpty {
                    Button("Clear") {
                        withAnimation { checkedIngredients.removeAll() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Brand.warmTan)
                }
            }

            if isEditing {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    EditableIngredientRow(ingredient: ingredient) {
                        recipe.ingredients.removeAll { $0.id == ingredient.id }
                    }
                    if index < recipe.ingredients.count - 1 {
                        Divider()
                    }
                }
            } else {
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
    }

    private var directionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Directions")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if isEditing {
                    Button {
                        let newStep = RecipeDirection(
                            stepNumber: recipe.directions.count + 1,
                            instruction: ""
                        )
                        recipe.directions.append(newStep)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Brand.herbGreen)
                    }
                }
            }

            if isEditing {
                ForEach(Array(recipe.directions.enumerated()), id: \.element.id) { index, direction in
                    EditableDirectionRow(
                        direction: Binding(
                            get: { recipe.directions[safe: index] ?? direction },
                            set: { if index < recipe.directions.count { recipe.directions[index] = $0 } }
                        ),
                        stepNumber: index + 1
                    ) {
                        recipe.directions.removeAll { $0.id == direction.id }
                        // Renumber remaining steps
                        for i in recipe.directions.indices {
                            recipe.directions[i].stepNumber = i + 1
                        }
                    }
                    if index < recipe.directions.count - 1 {
                        Divider()
                    }
                }
            } else {
                ForEach(recipe.directions) { direction in
                    DirectionStepView(
                        direction: direction,
                        ingredientColorMap: ingredientColors,
                        ingredientCategoryMap: ingredientCategories,
                        recipeTitle: recipe.title,
                        totalSteps: recipe.directions.count
                    )
                }
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

            if let error = nutritionEstimateError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Brand.spiceRed)
            }
        }
    }

    private func estimateNutrition() async {
        nutritionEstimateError = nil
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
            nutritionEstimateError = "Couldn't estimate nutrition. Tap to retry."
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
                    .glassCard(cornerRadius: 8)
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
                        StarRatingView(rating: Int(avg.rounded()), font: .subheadline)
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
                let sortedLog = recipe.cookingLog.sorted(by: { $0.date > $1.date })
                ForEach(Array(sortedLog.enumerated()), id: \.element.id) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.date, style: .date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let rating = entry.rating {
                                StarRatingView(rating: rating)
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
                    if index < sortedLog.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        RecipeTagEditorView(recipe: recipe)
    }

    // MARK: - Dietary Restrictions (Edit Mode)

    private var dietaryRestrictionsEditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dietary Restrictions")
                .font(.title2)
                .fontWeight(.bold)

            WrappingLayout(itemSpacing: 8, rowSpacing: 8) {
                ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                    let isSelected = recipe.dietaryRestrictions.contains(restriction)
                    Button {
                        if isSelected {
                            recipe.dietaryRestrictions.removeAll { $0 == restriction }
                        } else {
                            recipe.dietaryRestrictions.append(restriction)
                        }
                    } label: {
                        Text(restriction.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                                in: .capsule
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func editableInfoItem(title: String, value: Binding<Int>, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(width: 50)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

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

// MARK: - Editable Ingredient Row

struct EditableIngredientRow: View {
    @Bindable var ingredient: Ingredient
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ingredient.category.displayColor.swiftUIColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Ingredient name", text: $ingredient.name)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    TextField("Qty", value: $ingredient.amount.quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .font(.caption)

                    Picker("Unit", selection: $ingredient.amount.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)

                    Picker("Category", selection: $ingredient.category) {
                        ForEach(IngredientCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
            }

            Spacer()

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Editable Direction Row

struct EditableDirectionRow: View {
    @Binding var direction: RecipeDirection
    let stepNumber: Int
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(stepNumber)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: .circle)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Step instruction", text: $direction.instruction, axis: .vertical)
                    .lineLimit(2...6)

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Timer (sec)", value: Binding(
                        get: { direction.timer?.durationSeconds },
                        set: {
                            if let seconds = $0, seconds > 0 {
                                direction.timer = TimerStep(durationSeconds: seconds, label: "Step \(stepNumber)")
                            } else {
                                direction.timer = nil
                            }
                        }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .font(.caption)
                    .frame(width: 80)
                }
            }

            Spacer()

            Button(role: .destructive) { onDelete() } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
