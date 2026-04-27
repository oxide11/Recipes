import SwiftUI
import SwiftData

// MARK: - Editable Ingredient

/// Lightweight value type for editing an ingredient before saving.
private struct EditableIngredient: Identifiable {
    let id = UUID()
    var name: String = ""
    var category: IngredientCategory = .other
    var quantity: Double = 1
    var unit: MeasurementUnit = .piece
    var isOptional: Bool = false
}

// MARK: - Editable Direction

/// Lightweight value type for editing a direction step before saving.
private struct EditableDirection: Identifiable {
    let id = UUID()
    var instruction: String = ""
    var timerSeconds: Int? = nil
    var ingredients: [DirectionIngredientRef] = []
}

// MARK: - Recipe Editor View

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var cuisine: Cuisine = .other
    @State private var difficulty: RecipeDifficulty = .intermediate
    @State private var mealType: MealType? = nil
    @State private var servings = 4
    @State private var prepTime = 15
    @State private var cookTime = 30

    // Ingredients
    @State private var ingredients: [EditableIngredient] = []

    // Directions
    @State private var directions: [EditableDirection] = []

    // Tags & Dietary
    @State private var tagText = ""
    @State private var tags: [String] = []
    @State private var selectedRestrictions: Set<DietaryRestriction> = []
    @State private var selectedConversion: DirectionIngredientRef?

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                timingSection
                ingredientsSection
                directionsSection
                tagsSection
                dietaryRestrictionsSection
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .disabled(title.isEmpty)
                }
            }


        }
    }

    // MARK: - Basics

    private var basicsSection: some View {
        Section("Basics") {
            TextField("Recipe Title", text: $title)
            TextField("Summary", text: $summary, axis: .vertical)
                .lineLimit(3)

            Picker("Meal Type", selection: $mealType) {
                Text("Unspecified").tag(MealType?.none)
                ForEach(MealType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(MealType?.some(type))
                }
            }

            Picker("Cuisine", selection: $cuisine) {
                ForEach(Cuisine.allCases, id: \.self) { c in
                    Text(c.rawValue.capitalized).tag(c)
                }
            }

            Picker("Difficulty", selection: $difficulty) {
                ForEach(RecipeDifficulty.allCases, id: \.self) { d in
                    Text(d.rawValue.capitalized).tag(d)
                }
            }
        }
    }

    // MARK: - Timing & Servings

    private var timingSection: some View {
        Section("Timing & Servings") {
            Stepper("Servings: \(servings)", value: $servings, in: 1...50)
            Stepper("Prep: \(prepTime) min", value: $prepTime, in: 0...300, step: 5)
            Stepper("Cook: \(cookTime) min", value: $cookTime, in: 0...600, step: 5)
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        Section {
            ForEach($ingredients) { $ingredient in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Ingredient name", text: $ingredient.name)

                    HStack {
                        TextField("Qty", value: $ingredient.quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)

                        Picker("Unit", selection: $ingredient.unit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
                        .labelsHidden()

                        Picker("Category", selection: $ingredient.category) {
                            ForEach(IngredientCategory.allCases, id: \.self) { c in
                                Text(c.rawValue.capitalized).tag(c)
                            }
                        }
                        .labelsHidden()
                    }

                    Toggle("Optional", isOn: $ingredient.isOptional)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                ingredients.remove(atOffsets: offsets)
            }
            .onMove { from, to in
                ingredients.move(fromOffsets: from, toOffset: to)
            }

            Button {
                ingredients.append(EditableIngredient())
            } label: {
                Label("Add Ingredient", systemImage: "plus.circle")
            }
        } header: {
            Text("Ingredients")
        }
    }

    // MARK: - Directions

    private var directionsSection: some View {
        Section {
            ForEach(Array($directions.enumerated()), id: \.element.id) { index, $direction in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text("\(index + 1).")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)

                        TextField("Step instruction", text: $direction.instruction, axis: .vertical)
                            .lineLimit(2...5)
                    }

                    HStack {
                        Text("Timer (seconds)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional", value: $direction.timerSeconds, format: .number)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }

                    // Ingredient chips
                    if !direction.ingredients.isEmpty {
                        WrappingLayout(itemSpacing: 6, rowSpacing: 6) {
                            ForEach(direction.ingredients) { ref in
                                Button {
                                    selectedConversion = ref
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(ref.amount.displayString) \(ref.ingredientName)")
                                            .font(.caption)
                                        Button {
                                            direction.ingredients.removeAll { $0.id == ref.id }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.12), in: .capsule)
                                    .foregroundStyle(.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Add ingredient to step
                    let availableIngredients = ingredients.filter { ing in
                        !ing.name.trimmingCharacters(in: .whitespaces).isEmpty &&
                        !direction.ingredients.contains { $0.ingredientName.lowercased() == ing.name.lowercased() }
                    }
                    if !availableIngredients.isEmpty {
                        Menu {
                            ForEach(availableIngredients) { ing in
                                Button("\(ing.name) (\(IngredientAmount(quantity: ing.quantity, unit: ing.unit).displayString))") {
                                    let ref = DirectionIngredientRef(
                                        ingredientName: ing.name,
                                        amount: IngredientAmount(quantity: ing.quantity, unit: ing.unit)
                                    )
                                    direction.ingredients.append(ref)
                                }
                            }
                        } label: {
                            Label("Add Ingredient", systemImage: "plus.circle")
                                .font(.caption)
                                .foregroundStyle(.accent)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { offsets in
                directions.remove(atOffsets: offsets)
            }
            .onMove { from, to in
                directions.move(fromOffsets: from, toOffset: to)
            }

            Button {
                directions.append(EditableDirection())
            } label: {
                Label("Add Step", systemImage: "plus.circle")
            }
        } header: {
            Text("Directions")
        }
        .popover(item: $selectedConversion) { ref in
            IngredientConversionPopover(ref: ref)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        Section {
            WrappingLayout(itemSpacing: 8, rowSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.1), in: .capsule)
                }
            }

            HStack {
                TextField("Add tag", text: $tagText)
                    .onSubmit { addTag() }
                Button("Add") { addTag() }
                    .disabled(tagText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Tags")
        }
    }

    // MARK: - Dietary Restrictions

    private var dietaryRestrictionsSection: some View {
        Section {
            WrappingLayout(itemSpacing: 8, rowSpacing: 8) {
                ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                    let isSelected = selectedRestrictions.contains(restriction)
                    Button {
                        if isSelected {
                            selectedRestrictions.remove(restriction)
                        } else {
                            selectedRestrictions.insert(restriction)
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
        } header: {
            Text("Dietary Restrictions")
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = tagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        tagText = ""
    }

    private func saveRecipe() {
        let recipeIngredients = ingredients.compactMap { editable -> Ingredient? in
            guard !editable.name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return Ingredient(
                name: editable.name,
                category: editable.category,
                amount: IngredientAmount(quantity: editable.quantity, unit: editable.unit),
                isOptional: editable.isOptional
            )
        }

        let recipeDirections = directions.enumerated().compactMap { index, editable -> RecipeDirection? in
            guard !editable.instruction.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            let timer: TimerStep? = editable.timerSeconds.map {
                TimerStep(durationSeconds: $0, label: "Step \(index + 1)")
            }
            return RecipeDirection(
                stepNumber: index + 1,
                instruction: editable.instruction,
                timer: timer,
                ingredients: editable.ingredients
            )
        }

        let recipe = Recipe(
            title: title,
            summary: summary.isEmpty ? nil : summary,
            cuisine: cuisine,
            difficulty: difficulty,
            servings: servings,
            prepTimeMinutes: prepTime,
            cookTimeMinutes: cookTime,
            ingredients: recipeIngredients,
            directions: recipeDirections,
            mealType: mealType,
            dietaryRestrictions: Array(selectedRestrictions),
            tags: tags
        )
        modelContext.insert(recipe)
        dismiss()
    }
}



