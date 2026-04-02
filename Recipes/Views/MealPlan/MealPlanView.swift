import SwiftUI
import SwiftData
import AVFoundation

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
    @Query private var profiles: [UserProfile]

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var viewMode: MealPlanViewMode = .day
    @State private var showingGenerate = false
    @State private var didInitViewMode = false
    @State private var swipeForward = true

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
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end   = calendar.date(from: DateComponents(year: year + 1, month: 12, day: 31))
        else { return }
        modelContext.insert(MealPlan(name: "My Meals", startDate: start, endDate: end))
    }

    private var weekStart: Date {
        let weekday = calendar.component(.weekday, from: selectedDate)
        let firstWeekday = calendar.firstWeekday
        let daysFromStart = (weekday - firstWeekday + 7) % 7
        return calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -daysFromStart, to: selectedDate) ?? selectedDate
        )
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
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
                        ZStack {
                            DayMealView(plan: plan, date: selectedDate, allMeals: allPlannedMeals)
                                .id(selectedDate)
                                .transition(.asymmetric(
                                    insertion: .move(edge: swipeForward ? .trailing : .leading),
                                    removal:   .move(edge: swipeForward ? .leading  : .trailing)
                                ))
                        }
                        .gesture(
                            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                    if value.translation.width < -40 {
                                        swipeForward = true
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                                        }
                                    } else if value.translation.width > 40 {
                                        swipeForward = false
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                                        }
                                    }
                                }
                        )
                    } else {
                        WeekMealView(allMeals: allPlannedMeals, weekDays: weekDays) { forward in
                            swipeForward = forward
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedDate = calendar.date(byAdding: .weekOfYear, value: forward ? 1 : -1, to: selectedDate) ?? selectedDate
                            }
                        }
                        .id(weekStart)
                        .transition(.asymmetric(
                            insertion: .move(edge: swipeForward ? .trailing : .leading),
                            removal:   .move(edge: swipeForward ? .leading  : .trailing)
                        ))
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
            .task {
                ensurePlan()
                if !didInitViewMode, let profile = profiles.first {
                    viewMode = profile.defaultMealPrepMode == .weekly ? .week : .day
                    didInitViewMode = true
                }
            }
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
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -30 { advance(by: 1) }
                    else if value.translation.width > 30 { advance(by: -1) }
                }
        )
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
    @Query private var profiles: [UserProfile]

    let plan: MealPlan
    let date: Date
    let allMeals: [PlannedMeal]

    @State private var preselectMealType: MealType = .breakfast
    @State private var showingAddMeal = false
    @State private var showingMealPrep = false
    @State private var showingMultiCook = false

    private let primaryMealTypes: [MealType] = [.breakfast, .lunch, .dinner]

    private var isWeeklyMode: Bool {
        profiles.first?.defaultMealPrepMode == .weekly
    }

    private var weekdayIndex: Int {
        Calendar.current.component(.weekday, from: date)
    }

    private func meals(for type: MealType) -> [PlannedMeal] {
        allMeals.filter {
            $0.mealType == type && Calendar.current.isDate($0.date, inSameDayAs: date)
        }
    }

    /// All meals for this day that have a linked recipe.
    private var mealsWithRecipes: [PlannedMeal] {
        allMeals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.recipe != nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Weekly mode contextual banners
                if isWeeklyMode {
                    if weekdayIndex == 7 { // Saturday
                        HStack(spacing: 8) {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(Brand.warmTan)
                            Text("Shop today — stock up for the week!")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Brand.cream)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Brand.warmTan.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    } else if weekdayIndex == 1 { // Sunday
                        HStack(spacing: 8) {
                            Image(systemName: "frying.pan.fill")
                                .foregroundStyle(Brand.herbGreen)
                            Text("Prep day — cook for the week ahead!")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Brand.cream)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Brand.herbGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Meal Prep & Cook All — hidden for now

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
        .scrollBounceBehavior(.basedOnSize)
        .sheet(isPresented: $showingAddMeal) {
            AddMealView(plan: plan, preselectMealType: preselectMealType, preselectDate: date)
        }
        .sheet(isPresented: $showingMealPrep) {
            MealPrepView(meals: mealsWithRecipes, date: date)
        }
        .fullScreenCover(isPresented: $showingMultiCook) {
            MultiRecipeCookingView(meals: mealsWithRecipes)
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

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(meal.recipe?.title ?? "Unassigned")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Brand.cream)

            if meal.isAISuggested {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10))
                    .foregroundStyle(Brand.warmTan)
                    .help("AI-suggested recipe — saved to your library")
            }

            Spacer()

            if let recipe = meal.recipe {
                HStack(spacing: 4) {
                    Text(recipe.formattedDuration)
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                    if meal.recipe != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Brand.muted.opacity(0.5))
                    }
                }
            }
        }
    }

    private var pantryNames: Set<String> {
        Set(pantryItems.map { $0.name.lowercased() })
    }

    private var groceryNames: Set<String> {
        Set(groceryLists.flatMap(\.items).map { $0.name.lowercased() })
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

    private var trulyMissingIngredients: [Ingredient] {
        missingIngredients.filter { !groceryNames.contains($0.name.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row — tappable when a recipe exists
            Group {
                if let recipe = meal.recipe {
                    NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                        titleRow
                    }
                    .buttonStyle(.plain)
                } else {
                    titleRow
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
                    } else if trulyMissingIngredients.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "cart.badge.checkmark")
                                .font(.system(size: 10))
                            Text("All on shopping list")
                                .font(.miseMeta)
                        }
                        .foregroundStyle(Brand.warmTan)
                    } else {
                        Button {
                            addMissingToShopping()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: addedToCart ? "checkmark.circle.fill" : "cart.badge.plus")
                                    .font(.system(size: 11))
                                Text(addedToCart
                                     ? "Added to shopping list"
                                     : "Add \(trulyMissingIngredients.count) missing to shopping list")
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
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(meal)
            } label: {
                Label("Remove from Plan", systemImage: "trash")
            }
        }
    }

    private func addMissingToShopping() {
        guard !trulyMissingIngredients.isEmpty else { return }

        let list: GroceryList
        if let existing = groceryLists.first {
            list = existing
        } else {
            list = GroceryList(name: "Shopping List")
            modelContext.insert(list)
        }

        let existingNames = Set(list.items.map { $0.name.lowercased() })
        for ingredient in trulyMissingIngredients {
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
    let onWeekSwipe: (Bool) -> Void  // true = forward, false = back

    @State private var showingPrepList = false

    private var weekMealsWithRecipes: [PlannedMeal] {
        weekDays.flatMap { day in
            allMeals.filter {
                Calendar.current.isDate($0.date, inSameDayAs: day) && $0.recipe != nil
            }
        }
    }

    private func meals(for day: Date) -> [PlannedMeal] {
        allMeals
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    let dayMeals = meals(for: day)

                    Text(day, format: .dateTime.weekday(.wide).month().day())
                        .miseSectionHeader()
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        if dayMeals.isEmpty {
                            Text("No meals planned")
                                .font(.miseMeta)
                                .foregroundStyle(Brand.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if !weekMealsWithRecipes.isEmpty {
                Button {
                    showingPrepList = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "frying.pan.fill")
                        Text("Week Prep List")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Brand.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Brand.warmTan, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                    if value.translation.width < -30 {
                        onWeekSwipe(true)
                    } else if value.translation.width > 30 {
                        onWeekSwipe(false)
                    }
                }
        )
        .sheet(isPresented: $showingPrepList) {
            MealPrepView(
                meals: weekMealsWithRecipes,
                date: weekDays.first ?? .now,
                weekEndDate: weekDays.last
            )
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
    @Query private var profiles: [UserProfile]

    let plan: MealPlan

    @State private var rangeStart: Date
    @State private var rangeEnd: Date
    @State private var includeBreakfast = false
    @State private var includeLunch = true
    @State private var includeDinner = true
    @State private var prioritisePantry = true
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
                    Button("Generate") {
                        Task { await generate() }
                    }
                    .disabled(selectedMealTypes.isEmpty)
                }
            }
        }
    }

    // MARK: - Generation

    private func generate() async {
        errorMessage = nil

        // Capture everything we need before the view dismisses
        let prompt = buildPrompt()
        let recipeSnapshot = Array(recipes)

        // Dismiss immediately so the user isn't blocked on a long AI call
        dismiss()

        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .mealPlanGeneration)
            let suggestions = try parseSuggestions(from: response)
            await applyMeals(suggestions, recipeSnapshot: recipeSnapshot)
        } catch {
            // Generation failed after dismiss — user can retry via the Generate button
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

        let allowedMealTypes = Set(selectedMealTypes)
        let nonMealTypes: Set<MealType> = [.dessert, .snack, .appetizer, .side]
        let filteredRecipes = recipes.filter { r in
            guard let mt = r.mealType else { return true }  // no type set — include
            if nonMealTypes.contains(mt) { return false }   // never a standalone meal
            return allowedMealTypes.contains(mt)
        }
        let recipeLines = filteredRecipes.map { r in
            let typeTag = r.mealType.map { " [\($0.rawValue)]" } ?? ""
            return "\(r.title)\(r.isFavorite || r.isAutoFavorite ? " [favorite]" : "")\(typeTag) — \(r.cuisine.rawValue), \(r.formattedDuration), cooked \(r.cookCount)×"
        }.joined(separator: "\n- ")

        let pantrySection = prioritisePantry && !pantryItems.isEmpty
            ? "Pantry items available (prefer recipes that use these): \(pantryItems.map(\.name).joined(separator: ", "))."
            : ""

        let totalSlots = dates.count * selectedMealTypes.count
        let novelCount = filteredRecipes.count < totalSlots ? max(totalSlots - filteredRecipes.count, 2) : 2

        let dietaryNote = (profiles.first?.dietaryRestrictions ?? []).isEmpty ? "" :
            " Dietary needs: \((profiles.first!.dietaryRestrictions).map(\.displayName).joined(separator: ", "))."

        return """
        You are a meal planning assistant. Assign meals to the following dates.

        Dates: \(dates.joined(separator: ", "))
        Meal types to fill per day: \(mealTypeList)
        \(pantrySection)

        Saved recipes (\(filteredRecipes.count) total):
        - \(recipeLines.isEmpty ? "(none)" : recipeLines)

        Rules:
        - Prefer saved recipes. Use exact titles for saved recipes.
        - Vary recipes — do not repeat the same recipe on consecutive days.
        - Prefer [favorite] recipes where appropriate.
        - Recipes tagged [breakfast], [lunch], or [dinner] must only be assigned to that meal type.
        - Match meal type to recipe suitability (e.g. don't assign a heavy dinner to breakfast).
        - Include exactly \(novelCount) novel meal suggestion\(novelCount == 1 ? "" : "s") not from the saved list, spread across the plan for variety and discovery.\(dietaryNote) For novel meals set "isNew": true and provide a one-sentence "description". For saved meals omit both fields.

        Return ONLY a JSON array with no markdown fences and no commentary:
        [{"date":"YYYY-MM-DD","mealType":"breakfast|lunch|dinner","recipeTitle":"Title","isNew":false}]
        """
    }

    private struct MealSuggestion: Decodable {
        let date: String
        let mealType: String
        let recipeTitle: String
        let isNew: Bool?
        let description: String?
    }

    private func parseSuggestions(from raw: String) throws -> [MealSuggestion] {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown fences if present
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        // Extract JSON array even when wrapped in explanatory prose
        if let start = cleaned.firstIndex(of: "["),
           let end   = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[start...end])
        }
        guard let data = cleaned.data(using: .utf8) else { throw AIServiceError.invalidResponse }
        return try JSONDecoder().decode([MealSuggestion].self, from: data)
    }

    private func applyMeals(_ suggestions: [MealSuggestion], recipeSnapshot: [Recipe]) async {
        let recipeMap = Dictionary(
            uniqueKeysWithValues: recipeSnapshot.map { ($0.title.lowercased(), $0) }
        )
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let ingestionService = RecipeIngestionService(aiRouter: aiRouter)

        for suggestion in suggestions {
            guard
                let date = isoFormatter.date(from: suggestion.date),
                let mealType = MealType(rawValue: suggestion.mealType.lowercased())
            else { continue }

            let normalised = Calendar.current.startOfDay(for: date)
            let alreadyExists = plan.meals.contains {
                Calendar.current.isDate($0.date, inSameDayAs: normalised) && $0.mealType == mealType
            }
            guard !alreadyExists else { continue }

            // Find or generate the recipe
            let recipe: Recipe?
            if suggestion.isNew == true, let description = suggestion.description {
                let prompt = "Generate a complete recipe for: \(description). Include title, ingredients with measurements, and step-by-step instructions."
                do {
                    let text = try await aiRouter.generateText(prompt: prompt, taskType: .recipeGeneration)
                    let result = try await ingestionService.ingestFromText(text)
                    let generated = await ingestionService.convertToRecipe(result)
                    modelContext.insert(generated)
                    recipe = generated
                } catch {
                    recipe = nil
                }
            } else {
                recipe = recipeMap[suggestion.recipeTitle.lowercased()]
            }

            guard let recipe else { continue }
            let meal = PlannedMeal(
                mealType: mealType,
                date: normalised,
                recipe: recipe,
                isAISuggested: suggestion.isNew == true
            )
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
    @State private var showingGenerator = false
    @State private var lastRecipeCount = 0

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
                    Button {
                        lastRecipeCount = recipes.count
                        showingGenerator = true
                    } label: {
                        Label("Generate a Recipe", systemImage: "sparkles")
                            .foregroundStyle(Brand.warmTan)
                    }

                    if recipes.isEmpty {
                        Text("No recipes yet — generate one above or add some in the Recipes tab.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
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
            .sheet(isPresented: $showingGenerator) {
                QuickGenerateView()
            }
            .onChange(of: recipes.count) { _, newCount in
                // Auto-select the most recently created recipe (recipes is sorted by title, not date)
                if newCount > lastRecipeCount,
                   let newest = recipes.max(by: { $0.dateCreated < $1.dateCreated }) {
                    selectedRecipe = newest
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
                    .disabled(selectedRecipe == nil)
                }
            }
        }
    }
}

// MARK: - Multi-Recipe Cooking View

/// Full-screen cooking experience for multiple recipes with interleaved, optimized steps.
struct MultiRecipeCookingView: View {
    let meals: [PlannedMeal]
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var plan: MultiRecipeCookingPlan?
    @State private var isLoading = true
    @State private var currentStepIndex = 0
    @State private var stepEndDates: [Int: Date] = [:]
    @State private var stepPausedSeconds: [Int: Int] = [:]
    @State private var stepIsPaused: Set<Int> = []
    @State private var stepTimerTasks: [Int: Task<Void, Never>] = [:]
    @State private var stepLiveActivities: [Int: CookingTimerLiveActivityManager] = [:]
    @State private var checkedIngredients: [Int: Set<String>] = [:]
    @State private var isVoiceEnabled = true
    @State private var lastSpokenRecipeIndex: Int? = nil
    private let synthesizer = AVSpeechSynthesizer()

    /// Accent colors for distinguishing recipes — up to 5.
    private let recipeColors: [Color] = [
        Brand.warmTan,
        Brand.herbGreen,
        Brand.ingredientDairy,
        Brand.ingredientSeasoning,
        Brand.spiceRed
    ]

    private var currentStep: MultiCookingStep? {
        guard let plan, currentStepIndex < plan.steps.count else { return nil }
        return plan.steps[currentStepIndex]
    }

    private var progress: Double {
        guard let plan, !plan.steps.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(plan.steps.count)
    }

    private func colorForRecipe(_ index: Int) -> Color {
        recipeColors[index % recipeColors.count]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let step = currentStep {
                progressBar
                stepContent(step)
                controlBar
            } else {
                completionView
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard !isLoading else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 { advanceStep() }
                    else if value.translation.width > 40 { goBack() }
                }
        )
        .background(.black)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            generatePlan()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            synthesizer.stopSpeaking(at: .immediate)
            stepTimerTasks.values.forEach { $0.cancel() }
            Task { for m in stepLiveActivities.values { await m.end() } }
        }
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityAction(named: "Next Step") { advanceStep() }
        .accessibilityAction(named: "Previous Step") { goBack() }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(Brand.warmTan)

            Text("Optimizing cooking steps…")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(Array(meals.enumerated()), id: \.offset) { idx, meal in
                    if let recipe = meal.recipe {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colorForRecipe(idx))
                                .frame(width: 10, height: 10)
                            Text(recipe.title)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }

            Spacer()

            Button("Cancel") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 32)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            HStack {
                if let step = currentStep {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForRecipe(step.recipeIndex))
                            .frame(width: 8, height: 8)
                        Text(step.recipeTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let plan {
                    Text("Step \(currentStepIndex + 1) of \(plan.steps.count)")
                        .font(.caption)
                }
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal)

            ProgressView(value: progress)
                .tint(currentStep.map { colorForRecipe($0.recipeIndex) } ?? .green)

            // Persistent banner for all active timers
            let activeSteps = stepEndDates.keys.sorted().filter { !stepIsPaused.contains($0) }
                + stepIsPaused.sorted().filter { stepEndDates[$0] == nil }
            ForEach(activeSteps, id: \.self) { stepIdx in
                HStack(spacing: 8) {
                    Image(systemName: stepIsPaused.contains(stepIdx) ? "pause.circle" : "timer")
                    Text("Step \(stepIdx + 1):")
                    if stepIsPaused.contains(stepIdx), let secs = stepPausedSeconds[stepIdx] {
                        Text(formatTime(secs))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                    } else if let end = stepEndDates[stepIdx] {
                        Text(end, style: .timer)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.orange)
                    }
                    Spacer()
                    if stepIsPaused.contains(stepIdx) {
                        Button("Resume") { resumeTimer(stepIndex: stepIdx) }
                            .font(.caption).foregroundStyle(.orange)
                    } else {
                        Button("Pause") { pauseTimer(stepIndex: stepIdx) }
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button("Stop") { stopTimer(for: stepIdx) }
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.2), in: .rect(cornerRadius: 8))
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Step Content

    private func stepContent(_ step: MultiCookingStep) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recipe badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(colorForRecipe(step.recipeIndex))
                        .frame(width: 12, height: 12)
                    Text(step.recipeTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorForRecipe(step.recipeIndex))
                    Text("· Step \(step.originalStepNumber)")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Parallel note
                if let note = step.parallelNote {
                    Text(note)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Instruction — large text
                Text(step.instruction)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Ingredient chips — tap to check off
                if !step.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingredients for this step")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 24)

                        WrappingLayout(itemSpacing: 8, rowSpacing: 8) {
                            ForEach(step.ingredients, id: \.ingredientName) { ref in
                                let accentColor = colorForRecipe(step.recipeIndex)
                                let isChecked = checkedIngredients[currentStepIndex]?.contains(ref.ingredientName) ?? false
                                Button {
                                    var checked = checkedIngredients[currentStepIndex] ?? []
                                    if isChecked { checked.remove(ref.ingredientName) }
                                    else { checked.insert(ref.ingredientName) }
                                    checkedIngredients[currentStepIndex] = checked
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text("\(ref.amount.displayString) \(ref.ingredientName.lowercased())")
                                            .font(.subheadline)
                                            .strikethrough(isChecked)
                                    }
                                    .foregroundStyle(isChecked ? .white.opacity(0.35) : accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isChecked ? .white.opacity(0.06) : accentColor.opacity(0.15), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .sensoryFeedback(.selection, trigger: isChecked)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Timer
                if let timer = step.timer {
                    timerView(timer, accentColor: colorForRecipe(step.recipeIndex))
                }

                // Safe temperature
                if let temp = step.safeTemperature {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(.title2)
                        Text("\(temp.protein): \(Int(temp.minimumFahrenheit))°F / \(Int(temp.minimumCelsius))°C")
                            .font(.title3)
                    }
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.15), in: .rect(cornerRadius: 12))
                }
            }
            .padding(.vertical, 28)
        }
    }

    // MARK: - Timer

    private func timerView(_ timer: TimerStep, accentColor: Color) -> some View {
        let endDate = stepEndDates[currentStepIndex]
        let isPaused = stepIsPaused.contains(currentStepIndex)
        let pausedSecs = stepPausedSeconds[currentStepIndex]
        let isActive = endDate != nil || isPaused

        return VStack(spacing: 12) {
            if isActive {
                Group {
                    if isPaused, let secs = pausedSecs {
                        Text(formatTime(secs))
                    } else if let end = endDate {
                        Text(end, style: .timer)
                    }
                }
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPaused ? Color.secondary : accentColor)

                HStack(spacing: 12) {
                    Button(isPaused ? "Resume" : "Pause") {
                        if isPaused { resumeTimer(stepIndex: currentStepIndex) }
                        else { pauseTimer(stepIndex: currentStepIndex) }
                    }
                    .font(.title3)
                    .buttonStyle(.glass)
                    .tint(accentColor)

                    Button("Stop Timer") { stopTimer(for: currentStepIndex) }
                        .font(.title3)
                        .buttonStyle(.glass)
                }
            } else {
                VStack(spacing: 8) {
                    Text(timer.displayDuration)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)

                    Button {
                        startTimer(seconds: timer.durationSeconds, stepIndex: currentStepIndex)
                    } label: {
                        Label("Start Timer", systemImage: "timer")
                    }
                    .font(.title3)
                    .buttonStyle(.glass)
                    .tint(accentColor)
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.1), in: .rect(cornerRadius: 16))
        .sensoryFeedback(.impact, trigger: isActive)
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(Brand.herbGreen)

            Text("All Done!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            if let plan {
                if plan.savedMinutesVsSequential > 0 {
                    Text("You saved ~\(plan.savedMinutesVsSequential) min by cooking together!")
                        .font(.title3)
                        .foregroundStyle(Brand.herbGreen)
                }

                Text("\(plan.steps.count) steps across \(plan.recipeTitles.count) recipes completed.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                // Recipe summary
                VStack(spacing: 8) {
                    ForEach(Array(plan.recipeTitles.enumerated()), id: \.offset) { idx, title in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(colorForRecipe(idx))
                            Text(title)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.top, 8)
            }

            Button("Finish") { dismiss() }
                .font(.title3)
                .buttonStyle(.bordered)
                .tint(Brand.herbGreen)
                .padding(.top)

            Spacer()
        }
        .sensoryFeedback(.success, trigger: currentStepIndex)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            Button { goBack() } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 48))
            }
            .disabled(currentStepIndex == 0)
            .opacity(currentStepIndex == 0 ? 0.3 : 1)
            .accessibilityLabel("Previous step")

            Button {
                isVoiceEnabled.toggle()
                if !isVoiceEnabled { synthesizer.stopSpeaking(at: .immediate) }
            } label: {
                Image(systemName: isVoiceEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 32))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isVoiceEnabled ? "Disable voice" : "Enable voice")

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
            }
            .accessibilityLabel("Exit cooking mode")

            Button { advanceStep() } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 48))
            }
            .disabled(plan.map { currentStepIndex >= $0.steps.count } ?? true)
            .opacity(plan.map { currentStepIndex >= $0.steps.count } ?? true ? 0.3 : 1)
            .accessibilityLabel("Next step")
        }
        .foregroundStyle(.white)
        .padding()
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func generatePlan() {
        Task {
            // Use the basic (non-AI) plan generation to avoid requiring the AI router
            let generated = MultiRecipeCookingService.generateBasicPlan(from: meals)
            withAnimation {
                plan = generated
                isLoading = false
            }
            if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        }
    }

    private func advanceStep() {
        guard let plan else { return }
        synthesizer.stopSpeaking(at: .immediate)
        stopTimer(for: currentStepIndex)

        if currentStepIndex < plan.steps.count - 1 {
            currentStepIndex += 1
            if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        } else {
            currentStepIndex = plan.steps.count // show completion
        }
    }

    private func goBack() {
        guard currentStepIndex > 0 else { return }
        synthesizer.stopSpeaking(at: .immediate)
        stopTimer(for: currentStepIndex)
        currentStepIndex -= 1
        if isVoiceEnabled, let step = currentStep {
            speakStep(step)
        }
    }

    private func speakStep(_ step: MultiCookingStep) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        let stepPosition = currentStepIndex + 1
        let recipeChanged = lastSpokenRecipeIndex != step.recipeIndex
        lastSpokenRecipeIndex = step.recipeIndex

        var text = recipeChanged
            ? "\(step.recipeTitle). Step \(stepPosition). \(step.instruction)"
            : "Step \(stepPosition). \(step.instruction)"
        if let timer = step.timer {
            text += ". Timer: \(timer.displayDuration)."
        }
        if let temp = step.safeTemperature {
            text += ". Cook \(temp.protein) to \(Int(temp.minimumFahrenheit)) degrees Fahrenheit."
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func startTimer(seconds: Int, stepIndex: Int) {
        let endDate = Date().addingTimeInterval(Double(seconds))
        stepEndDates[stepIndex] = endDate
        stepIsPaused.remove(stepIndex)

        let manager = CookingTimerLiveActivityManager()
        stepLiveActivities[stepIndex] = manager
        manager.start(
            recipeTitle: plan?.recipeTitles.first ?? "Cooking",
            recipeID: meals.first?.recipe?.id ?? UUID(),
            stepNumber: stepIndex + 1,
            stepInstruction: plan?.steps[stepIndex].instruction ?? "",
            durationSeconds: seconds,
            totalSteps: plan?.steps.count ?? 1
        )

        scheduleMealPlanCompletion(stepIndex: stepIndex, endDate: endDate)
    }

    private func pauseTimer(stepIndex: Int) {
        guard let end = stepEndDates[stepIndex] else { return }
        stepPausedSeconds[stepIndex] = max(0, Int(end.timeIntervalSinceNow))
        stepIsPaused.insert(stepIndex)
        stepEndDates.removeValue(forKey: stepIndex)
        stepTimerTasks[stepIndex]?.cancel()
        let remaining = stepPausedSeconds[stepIndex] ?? 0
        Task { await stepLiveActivities[stepIndex]?.pause(remainingSeconds: remaining) }
    }

    private func resumeTimer(stepIndex: Int) {
        guard let secs = stepPausedSeconds[stepIndex] else { return }
        stepIsPaused.remove(stepIndex)
        let endDate = Date().addingTimeInterval(Double(secs))
        stepEndDates[stepIndex] = endDate
        Task { await stepLiveActivities[stepIndex]?.resume(remainingSeconds: secs) }
        scheduleMealPlanCompletion(stepIndex: stepIndex, endDate: endDate)
    }

    private func scheduleMealPlanCompletion(stepIndex: Int, endDate: Date) {
        stepTimerTasks[stepIndex]?.cancel()
        stepTimerTasks[stepIndex] = Task {
            let interval = endDate.timeIntervalSinceNow
            guard interval > 0 else { return }
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, !stepIsPaused.contains(stepIndex) else { return }
            stepEndDates.removeValue(forKey: stepIndex)
            stepPausedSeconds.removeValue(forKey: stepIndex)
            stepTimerTasks.removeValue(forKey: stepIndex)
            await stepLiveActivities[stepIndex]?.end()
            stepLiveActivities.removeValue(forKey: stepIndex)
            advanceStep()
        }
    }

    private func stopTimer(for stepIndex: Int) {
        stepTimerTasks[stepIndex]?.cancel()
        stepTimerTasks.removeValue(forKey: stepIndex)
        stepEndDates.removeValue(forKey: stepIndex)
        stepPausedSeconds.removeValue(forKey: stepIndex)
        stepIsPaused.remove(stepIndex)
        Task {
            await stepLiveActivities[stepIndex]?.end()
            stepLiveActivities.removeValue(forKey: stepIndex)
        }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
