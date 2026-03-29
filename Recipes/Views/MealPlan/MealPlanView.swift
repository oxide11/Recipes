import SwiftUI
import SwiftData

// MARK: - View Mode

private enum MealPlanViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
}

// MARK: - Meal Plan View

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealPlan.startDate, order: .reverse) private var mealPlans: [MealPlan]
    @Query private var allPlannedMeals: [PlannedMeal]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var viewMode: MealPlanViewMode = .day
    @State private var showingGenerate = false

    private var calendar: Calendar { .current }

    private var activePlan: MealPlan? {
        let day = calendar.startOfDay(for: selectedDate)
        return mealPlans.first {
            calendar.startOfDay(for: $0.startDate) <= day &&
            calendar.startOfDay(for: $0.endDate) >= day
        }
    }

    /// Silently creates a two-year plan covering the selected date if none exists.
    private func ensurePlan() {
        guard activePlan == nil else { return }
        let year = calendar.component(.year, from: selectedDate)
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end   = calendar.date(from: DateComponents(year: year + 1, month: 12, day: 31))!
        modelContext.insert(MealPlan(name: "My Meals", startDate: start, endDate: end))
    }

    private var weekStart: Date {
        let weekday = calendar.component(.weekday, from: selectedDate)
        let firstWeekday = calendar.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        return calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -daysFromStart, to: selectedDate)!
        )
    }

    private var weekDays: [Date] {
        (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    private var mealsPerDay: [Date: Int] {
        Dictionary(
            grouping: allPlannedMeals,
            by: { calendar.startOfDay(for: $0.date) }
        ).mapValues(\.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekStripView(
                    selectedDate: $selectedDate,
                    weekDays: weekDays,
                    mealsPerDay: mealsPerDay
                )
                .padding(.bottom, 8)

                Picker("View", selection: $viewMode) {
                    ForEach(MealPlanViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)

                Divider()

                if let plan = activePlan {
                    if viewMode == .day {
                        DayMealView(plan: plan, date: selectedDate, allMeals: allPlannedMeals)
                    } else {
                        WeekMealView(allMeals: allPlannedMeals, weekDays: weekDays)
                    }
                }
            }
            .navigationTitle("Meal Plan")
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Generate", systemImage: "sparkles") {
                        showingGenerate = true
                    }
                }
            }
            .sheet(isPresented: $showingGenerate) {
                if let plan = activePlan {
                    GenerateMealPlanSheet(plan: plan)
                }
            }
            .task { ensurePlan() }
            .onChange(of: selectedDate) { ensurePlan() }
        }
    }
}

// MARK: - Week Strip

struct WeekStripView: View {
    @Binding var selectedDate: Date
    let weekDays: [Date]
    let mealsPerDay: [Date: Int]

    private var calendar: Calendar { .current }

    private func advance(by weeks: Int) {
        selectedDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) ?? selectedDate
    }

    var body: some View {
        HStack(spacing: 0) {
            Button { advance(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
                    .frame(width: 32)
            }

            HStack(spacing: 2) {
                ForEach(weekDays, id: \.self) { day in
                    DayChip(
                        date: day,
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                        mealCount: mealsPerDay[calendar.startOfDay(for: day), default: 0]
                    )
                    .onTapGesture { selectedDate = day }
                }
            }

            Button { advance(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
                    .frame(width: 32)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

// MARK: - Day Chip

struct DayChip: View {
    let date: Date
    let isSelected: Bool
    let mealCount: Int

    private var calendar: Calendar { .current }

    private var dayLetter: String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    private var dayNumber: String {
        "\(calendar.component(.day, from: date))"
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayLetter)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? Brand.warmTan : Brand.muted)

            Text(dayNumber)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Brand.cream)
                .frame(width: 30, height: 30)
                .background(isSelected ? Brand.warmTan : Color.clear, in: Circle())

            Circle()
                .fill(mealCount > 0 ? Brand.herbGreen : Color.clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Meal View

struct DayMealView: View {
    @Query private var pantryItems: [PantryItem]

    let plan: MealPlan
    let date: Date
    let allMeals: [PlannedMeal]

    @State private var preselectMealType: MealType = .breakfast
    @State private var showingAddMeal = false

    private let primaryMealTypes: [MealType] = [.breakfast, .lunch, .dinner]

    private func meals(for type: MealType) -> [PlannedMeal] {
        allMeals.filter {
            $0.mealType == type && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(primaryMealTypes, id: \.self) { mealType in
                    MealSlotSection(
                        mealType: mealType,
                        meals: meals(for: mealType),
                        pantryItems: pantryItems,
                        plan: plan,
                        date: date,
                        onAdd: {
                            preselectMealType = mealType
                            showingAddMeal = true
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showingAddMeal) {
            AddMealView(plan: plan, preselectMealType: preselectMealType, preselectDate: date)
        }
    }
}

// MARK: - Meal Slot Section

struct MealSlotSection: View {
    @Environment(\.modelContext) private var modelContext

    let mealType: MealType
    let meals: [PlannedMeal]
    let pantryItems: [PantryItem]
    let plan: MealPlan
    let date: Date
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: mealType.systemImageName)
                    .font(.caption)
                    .foregroundStyle(Brand.warmTan)
                Text(mealType.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Brand.warmTan)
                    .tracking(0.6)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Brand.muted)
                }
            }

            // Content
            if meals.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus").font(.caption)
                        Text("Add recipe").font(.system(size: 13))
                    }
                    .foregroundStyle(Brand.muted.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Brand.muted.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(meals) { meal in
                    MealCard(meal: meal, pantryItems: pantryItems)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(meal)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Meal Card

struct MealCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryList.dateCreated, order: .reverse) private var groceryLists: [GroceryList]

    let meal: PlannedMeal
    let pantryItems: [PantryItem]

    @State private var addedToCart = false

    private var pantryNames: Set<String> {
        Set(pantryItems.map { $0.name.lowercased() })
    }

    private var coverage: (covered: Int, total: Int) {
        guard let recipe = meal.recipe else { return (0, 0) }
        let total = recipe.ingredients.count
        let covered = recipe.ingredients.filter { pantryNames.contains($0.name.lowercased()) }.count
        return (covered, total)
    }

    private var missingIngredients: [Ingredient] {
        meal.recipe?.ingredients.filter { !pantryNames.contains($0.name.lowercased()) } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(meal.recipe?.title ?? "Unassigned")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Brand.cream)

                Spacer()

                if let recipe = meal.recipe {
                    Text(recipe.formattedDuration)
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                }
            }

            if let _ = meal.recipe {
                let (covered, total) = coverage
                if total > 0 {
                    if covered == total {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                            Text("All ingredients in pantry")
                                .font(.miseMeta)
                        }
                        .foregroundStyle(Brand.herbGreen)
                    } else {
                        Button {
                            addMissingToShopping()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: addedToCart ? "checkmark.circle.fill" : "cart.badge.plus")
                                    .font(.system(size: 11))
                                Text(addedToCart
                                     ? "Added to shopping list"
                                     : "Add \(missingIngredients.count) missing to shopping list")
                                    .font(.miseMeta)
                            }
                            .foregroundStyle(addedToCart ? Brand.herbGreen : Brand.warmTan)
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.success, trigger: addedToCart)
                    }
                }
            }
        }
        .padding(10)
        .background(Brand.muted.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func addMissingToShopping() {
        guard !missingIngredients.isEmpty else { return }

        let list: GroceryList
        if let existing = groceryLists.first {
            list = existing
        } else {
            list = GroceryList(name: "Shopping List")
            modelContext.insert(list)
        }

        let existingNames = Set(list.items.map { $0.name.lowercased() })
        for ingredient in missingIngredients {
            guard !existingNames.contains(ingredient.name.lowercased()) else { continue }
            let item = GroceryItem(
                name: ingredient.name,
                quantity: ingredient.amount.quantity,
                unit: ingredient.amount.unit,
                storeSection: storeSection(for: ingredient.category)
            )
            modelContext.insert(item)
            list.items.append(item)
        }

        withAnimation { addedToCart = true }
    }

    private func storeSection(for category: IngredientCategory) -> StoreSection {
        switch category {
        case .protein:                return .meat
        case .vegetable, .fruit:      return .produce
        case .grain, .legume, .nut:   return .dryGoods
        case .dairy:                  return .dairy
        case .spice, .herb:           return .spices
        case .condiment, .sweetener:  return .condiments
        case .oil, .liquid:           return .condiments
        case .other:                  return .other
        }
    }
}

// MARK: - Week Meal View

struct WeekMealView: View {
    let allMeals: [PlannedMeal]
    let weekDays: [Date]

    private func meals(for day: Date) -> [PlannedMeal] {
        allMeals
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    var body: some View {
        List {
            ForEach(weekDays, id: \.self) { day in
                let dayMeals = meals(for: day)
                Section {
                    if dayMeals.isEmpty {
                        Text("No meals planned")
                            .font(.miseMeta)
                            .foregroundStyle(Brand.muted)
                    } else {
                        ForEach(dayMeals) { meal in
                            HStack(spacing: 10) {
                                Image(systemName: meal.mealType.systemImageName)
                                    .font(.caption)
                                    .foregroundStyle(Brand.warmTan)
                                    .frame(width: 16)
                                Text(meal.recipe?.title ?? "Unassigned")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Brand.cream)
                                Spacer()
                                if meal.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Brand.herbGreen)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                } header: {
                    Text(day, format: .dateTime.weekday(.wide).month().day())
                        .miseSectionHeader()
                }
            }
        }
    }
}

// MARK: - Generate Meal Plan Sheet

struct GenerateMealPlanSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query private var pantryItems: [PantryItem]

    let plan: MealPlan

    @State private var rangeStart: Date
    @State private var rangeEnd: Date
    @State private var includeBreakfast = false
    @State private var includeLunch = true
    @State private var includeDinner = true
    @State private var prioritisePantry = true
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(plan: MealPlan) {
        self.plan = plan
        let today = Calendar.current.startOfDay(for: Date())
        _rangeStart = State(initialValue: max(plan.startDate, today))
        _rangeEnd = State(initialValue: min(
            plan.endDate,
            Calendar.current.date(byAdding: .day, value: 6, to: today) ?? plan.endDate
        ))
    }

    private var selectedMealTypes: [MealType] {
        [
            includeBreakfast ? MealType.breakfast : nil,
            includeLunch ? MealType.lunch : nil,
            includeDinner ? MealType.dinner : nil
        ].compactMap { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("From", selection: $rangeStart,
                               in: plan.startDate...plan.endDate,
                               displayedComponents: .date)
                    DatePicker("To", selection: $rangeEnd,
                               in: rangeStart...plan.endDate,
                               displayedComponents: .date)
                }

                Section("Meal Types") {
                    Toggle("Breakfast", isOn: $includeBreakfast)
                    Toggle("Lunch", isOn: $includeLunch)
                    Toggle("Dinner", isOn: $includeDinner)
                }

                Section {
                    Toggle("Prioritise pantry ingredients", isOn: $prioritisePantry)
                } footer: {
                    Text("The AI will prefer recipes that use what you already have in your pantry.")
                }

                if prioritisePantry && !pantryItems.isEmpty {
                    Section("Pantry (\(pantryItems.count) items)") {
                        Text(
                            pantryItems.prefix(10).map(\.name).joined(separator: ", ")
                            + (pantryItems.count > 10 ? ", …" : "")
                        )
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.miseMeta)
                    }
                }
            }
            .navigationTitle("Generate Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isGenerating {
                        ProgressView().tint(Brand.warmTan)
                    } else {
                        Button("Generate") {
                            Task { await generate() }
                        }
                        .disabled(selectedMealTypes.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Generation

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        let prompt = buildPrompt()
        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .mealPlanGeneration)
            let suggestions = try parseSuggestions(from: response)
            applyMeals(suggestions)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buildPrompt() -> String {
        let cal = Calendar.current
        var dates: [String] = []
        var cursor = rangeStart
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        while cursor <= rangeEnd {
            dates.append(isoFormatter.string(from: cursor))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? rangeEnd.addingTimeInterval(1)
        }

        let mealTypeList = selectedMealTypes.map(\.rawValue).joined(separator: ", ")

        let recipeLines = recipes.map { r in
            "\(r.title)\(r.isFavorite || r.isAutoFavorite ? " [favorite]" : "") — \(r.cuisine.rawValue), \(r.formattedDuration), cooked \(r.cookCount)×"
        }.joined(separator: "\n- ")

        let pantrySection = prioritisePantry && !pantryItems.isEmpty
            ? "Pantry items available (prefer recipes that use these): \(pantryItems.map(\.name).joined(separator: ", "))."
            : ""

        return """
        You are a meal planning assistant. Assign meals to the following dates.

        Dates: \(dates.joined(separator: ", "))
        Meal types to fill per day: \(mealTypeList)
        \(pantrySection)

        Available recipes:
        - \(recipeLines)

        Rules:
        - Only use recipes from the list above. Use exact titles.
        - Vary recipes across consecutive days — do not repeat the same recipe back-to-back.
        - Prefer [favorite] recipes where appropriate.
        - Match meal type to the recipe suitability (e.g. don't assign a heavy dinner to breakfast).

        Return ONLY a JSON array with no markdown fences and no commentary:
        [{"date":"YYYY-MM-DD","mealType":"breakfast|lunch|dinner","recipeTitle":"Exact Title From List"}]
        """
    }

    private struct MealSuggestion: Decodable {
        let date: String
        let mealType: String
        let recipeTitle: String
    }

    private func parseSuggestions(from raw: String) throws -> [MealSuggestion] {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = cleaned.data(using: .utf8) else { throw AIServiceError.invalidResponse }
        return try JSONDecoder().decode([MealSuggestion].self, from: data)
    }

    private func applyMeals(_ suggestions: [MealSuggestion]) {
        let recipeMap = Dictionary(
            uniqueKeysWithValues: recipes.map { ($0.title.lowercased(), $0) }
        )
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        for suggestion in suggestions {
            guard
                let date = isoFormatter.date(from: suggestion.date),
                let mealType = MealType(rawValue: suggestion.mealType.lowercased()),
                let recipe = recipeMap[suggestion.recipeTitle.lowercased()]
            else { continue }

            let normalised = Calendar.current.startOfDay(for: date)

            let alreadyExists = plan.meals.contains {
                Calendar.current.isDate($0.date, inSameDayAs: normalised) && $0.mealType == mealType
            }
            guard !alreadyExists else { continue }

            let meal = PlannedMeal(mealType: mealType, date: normalised, recipe: recipe)
            modelContext.insert(meal)
            plan.meals.append(meal)
        }
    }
}

// MARK: - Add Meal View

struct AddMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    let plan: MealPlan

    @State private var selectedMealType: MealType
    @State private var selectedDate: Date
    @State private var selectedRecipe: Recipe? = nil
    @State private var servings = 1

    init(plan: MealPlan, preselectMealType: MealType = .dinner, preselectDate: Date? = nil) {
        self.plan = plan
        _selectedMealType = State(initialValue: preselectMealType)
        _selectedDate = State(initialValue: preselectDate ?? plan.startDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    Picker("Type", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $selectedDate,
                               in: plan.startDate...plan.endDate,
                               displayedComponents: .date)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                }

                Section("Recipe") {
                    if recipes.isEmpty {
                        Text("No recipes yet — add some in the Recipes tab.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recipes) { recipe in
                            Button {
                                selectedRecipe = (selectedRecipe?.id == recipe.id) ? nil : recipe
                            } label: {
                                HStack {
                                    Text(recipe.title)
                                    Spacer()
                                    if selectedRecipe?.id == recipe.id {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let meal = PlannedMeal(
                            mealType: selectedMealType,
                            date: Calendar.current.startOfDay(for: selectedDate),
                            recipe: selectedRecipe,
                            servings: servings
                        )
                        modelContext.insert(meal)
                        plan.meals.append(meal)
                        dismiss()
                    }
                }
            }
        }
    }
}
