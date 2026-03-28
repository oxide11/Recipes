import SwiftUI
import SwiftData

// MARK: - Meal Plan View

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealPlan.startDate, order: .reverse) private var mealPlans: [MealPlan]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var showingCreatePlan = false
    @State private var showingAIGenerator = false
    @State private var showingRecipePicker = false
    @State private var addingMealType: MealType = .dinner
    @State private var selectedDate = Date()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack {
                // Week date picker
                DatePicker(
                    "Week of",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                if let activePlan = activeMealPlan {
                    mealPlanDetail(activePlan)
                } else {
                    ContentUnavailableView(
                        "No Meal Plan",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a meal plan for this week.")
                    )
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 12) {
                        Button("Create Meal Plan") {
                            showingCreatePlan = true
                        }
                        .buttonStyle(.glass)

                        if !recipes.isEmpty {
                            Button {
                                showingAIGenerator = true
                            } label: {
                                Label("AI Generate", systemImage: "sparkles")
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Meal Plan")
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button("Create Manually", systemImage: "plus") {
                            showingCreatePlan = true
                        }
                        if !recipes.isEmpty {
                            Button("Generate with AI", systemImage: "sparkles") {
                                showingAIGenerator = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateMealPlanView()
            }
            .sheet(isPresented: $showingAIGenerator) {
                AIMealPlanGeneratorView(
                    recipes: recipes,
                    pantryItems: pantryItems,
                    profile: profile
                )
            }
            .sheet(isPresented: $showingRecipePicker) {
                MealRecipePickerView(
                    recipes: recipes,
                    mealType: addingMealType,
                    date: selectedDate
                ) { recipe, servings in
                    if let plan = activeMealPlan {
                        let meal = PlannedMeal(
                            mealType: addingMealType,
                            date: selectedDate,
                            recipe: recipe,
                            servings: servings
                        )
                        plan.meals.append(meal)
                    }
                }
            }
        }
    }

    private var activeMealPlan: MealPlan? {
        mealPlans.first { plan in
            plan.startDate <= selectedDate && plan.endDate >= selectedDate
        }
    }

    private func mealPlanDetail(_ plan: MealPlan) -> some View {
        List {
            Section("Overview") {
                LabeledContent("Total Prep Time", value: "\(plan.totalPrepTimeMinutes) min")
                if let budget = plan.budgetTarget {
                    LabeledContent("Budget", value: budget, format: .currency(code: "USD"))
                }
                if let cal = plan.calorieTarget {
                    LabeledContent("Daily Calories", value: "\(cal)")
                }

                // Generate shopping list button
                Button {
                    generateShoppingList(from: plan)
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Generate Shopping List")
                                .fontWeight(.medium)
                            Text("Creates a list from all planned meals, minus pantry stock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cart.badge.plus")
                            .foregroundStyle(.green)
                    }
                }
                .sensoryFeedback(.success, trigger: plan.meals.count)
            }

            ForEach(MealType.allCases, id: \.self) { mealType in
                let meals = plan.meals.filter { $0.mealType == mealType }
                Section(mealType.rawValue.capitalized) {
                    if !meals.isEmpty {
                        ForEach(meals) { meal in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(meal.recipe?.title ?? "Unassigned")
                                        .fontWeight(.medium)
                                    HStack(spacing: 8) {
                                        Text(meal.date, style: .date)
                                        if let notes = meal.notes {
                                            Text(notes)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if meal.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    plan.meals.removeAll { $0.id == meal.id }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    // Add meal button
                    Button {
                        addingMealType = mealType
                        showingRecipePicker = true
                    } label: {
                        Label("Add \(mealType.rawValue.capitalized)", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func generateShoppingList(from plan: MealPlan) {
        let list = ShoppingListGenerator.generateList(
            from: plan,
            pantryItems: pantryItems
        )
        modelContext.insert(list)
    }
}

// MARK: - AI Meal Plan Generator View

struct AIMealPlanGeneratorView: View {
    let recipes: [Recipe]
    let pantryItems: [PantryItem]
    let profile: UserProfile?

    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.dismiss) private var dismiss

    @State private var days = 7
    @State private var includedMeals: Set<MealType> = [.breakfast, .lunch, .dinner]
    @State private var isGenerating = false
    @State private var generatedPlan: GeneratedMealPlan?
    @State private var errorMessage: String?

    private let generator = MealPlanGenerator()

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Duration") {
                    Stepper("Days: \(days)", value: $days, in: 1...14)
                }

                Section("Meals to Include") {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Toggle(mealType.rawValue.capitalized, isOn: Binding(
                            get: { includedMeals.contains(mealType) },
                            set: { isOn in
                                if isOn { includedMeals.insert(mealType) }
                                else { includedMeals.remove(mealType) }
                            }
                        ))
                    }
                }

                Section {
                    Button {
                        Task { await generatePlan() }
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating plan...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Meal Plan")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isGenerating || recipes.isEmpty || includedMeals.isEmpty)
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let plan = generatedPlan {
                    generatedPlanPreview(plan)
                }
            }
            .navigationTitle("AI Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func generatedPlanPreview(_ plan: GeneratedMealPlan) -> some View {
        Group {
            Section("Generated Plan") {
                Text(plan.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(plan.days, id: \.dayNumber) { day in
                Section("Day \(day.dayNumber)") {
                    ForEach(day.meals, id: \.recipeTitle) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(meal.mealType.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text("\(meal.servings) servings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(meal.recipeTitle)
                                .fontWeight(.medium)
                            if !meal.reasoning.isEmpty {
                                Text(meal.reasoning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    savePlan(plan)
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Meal Plan")
                        Spacer()
                    }
                }
                .buttonStyle(.glass)
                .tint(.green)
            }
        }
    }

    private func generatePlan() async {
        isGenerating = true
        errorMessage = nil
        generatedPlan = nil

        let mealsArray = Array(includedMeals).sorted { $0.rawValue < $1.rawValue }

        do {
            generatedPlan = try await generator.generatePlan(
                recipes: recipes,
                pantryItems: pantryItems,
                profile: profile,
                startDate: .now,
                days: days,
                mealsPerDay: mealsArray
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    private func savePlan(_ plan: GeneratedMealPlan) {
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now

        let mealPlan = MealPlan(
            name: "AI Plan — \(days) days",
            startDate: .now,
            endDate: endDate,
            calorieTarget: profile?.dailyCalorieTarget
        )

        let meals = generator.convertToPlannedMeals(
            plan: plan,
            recipes: recipes,
            startDate: .now
        )
        mealPlan.meals = meals

        modelContext.insert(mealPlan)
        dismiss()
    }
}

// MARK: - Meal Recipe Picker

struct MealRecipePickerView: View {
    let recipes: [Recipe]
    let mealType: MealType
    let date: Date
    let onSelect: (Recipe, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var servings = 2

    private var filteredRecipes: [Recipe] {
        if searchText.isEmpty { return recipes }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                }

                ForEach(filteredRecipes) { recipe in
                    Button {
                        onSelect(recipe, servings)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 8) {
                                    Label("\(recipe.estimatedTotalMinutes) min", systemImage: "clock")
                                    Label(recipe.cuisine.rawValue.capitalized, systemImage: "fork.knife")
                                    Label(recipe.difficulty.rawValue.capitalized, systemImage: "chart.bar")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .navigationTitle("Pick \(mealType.rawValue.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Create Meal Plan View

struct CreateMealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 86400)
    @State private var budgetTarget = ""
    @State private var calorieTarget = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plan Name", text: $name)
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)

                Section("Goals (Optional)") {
                    TextField("Weekly Budget ($)", text: $budgetTarget)
                        .keyboardType(.decimalPad)
                    TextField("Daily Calorie Target", text: $calorieTarget)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let plan = MealPlan(
                            name: name.isEmpty ? "Meal Plan" : name,
                            startDate: startDate,
                            endDate: endDate,
                            budgetTarget: Double(budgetTarget),
                            calorieTarget: Int(calorieTarget)
                        )
                        modelContext.insert(plan)
                        dismiss()
                    }
                }
            }
        }
    }
}
