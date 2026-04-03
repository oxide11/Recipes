import SwiftUI
import SwiftData

// MARK: - Dashboard Design Tokens

private enum DashboardStyle {
    static let obsidian = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let cardBackground = Color(white: 0.12)
    static let produce = Color(hex: "2ECC71")
    static let meat = Color(hex: "E74C3C")
    static let grains = Color(hex: "F5B041")

    static let aiGlow = AngularGradient(
        colors: [.cyan, .purple, .orange, .green, .cyan],
        center: .center
    )
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \PantryItem.expirationDate) private var pantryItems: [PantryItem]
    @Query private var plannedMeals: [PlannedMeal]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query private var receipts: [GroceryReceipt]
    @Query private var profiles: [UserProfile]

    @State private var showingReceiptScanner = false
    @State private var showingQuickMeals = false
    @State private var showingShoppingList = false
    @State private var showingWantToTry = false
    @State private var selectedSeasonalIngredient: IngredientFilter? = nil
    @State private var cachedRecentLogs: [CookingLogEntry] = []
    @State private var cachedTodaysMeals: [PlannedMeal] = []
    @State private var cachedQuickRecipes: [Recipe] = []

    // MARK: - Computed Data

    private var profile: UserProfile? { profiles.first }

    private var todaysMeals: [PlannedMeal] { cachedTodaysMeals }

    private var completedTodayCount: Int {
        cachedTodaysMeals.filter(\.isCompleted).count
    }

    private var expiringItems: [PantryItem] {
        pantryItems.filter { $0.isExpiringSoon && !$0.isExpired }
    }

    private var expiredItems: [PantryItem] {
        pantryItems.filter(\.isExpired)
    }

    private var recentCookingLogs: [CookingLogEntry] { cachedRecentLogs }

    private var thisWeekCookCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return recentCookingLogs.filter { $0.date >= weekAgo }.count
    }

    private var cookingStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let logDates = Set(recentCookingLogs.map { calendar.startOfDay(for: $0.date) })

        var streak = 0
        var checkDate = today
        while logDates.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }
        return streak
    }

    private var weeklySpend: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return receipts.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.totalAmount }
    }

    private var weeklyBudget: Double? {
        profile?.weeklyGroceryBudget
    }

    private var favoriteRecipes: [Recipe] {
        recipes.filter { $0.isFavorite || $0.isAutoFavorite }
    }

    private var quickRecipes: [Recipe] { cachedQuickRecipes }

    private var hemisphere: Hemisphere {
        profile?.hemisphere ?? .northern
    }

    private var seasonalIngredients: [String] {
        SeasonalAwarenessService.currentlyInSeason(hemisphere: hemisphere)
            .filter { !$0.availableAllYear }
            .prefix(6)
            .map(\.name)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                if sizeClass == .regular {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
            .background(Brand.midnight)
            .navigationTitle("Mise")
            .sheet(isPresented: $showingReceiptScanner) {
                ReceiptScannerView()
            }
            .sheet(isPresented: $showingQuickMeals) {
                QuickMealsView(recipes: quickRecipes)
            }
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListView()
            }
            .sheet(isPresented: $showingWantToTry) {
                RestaurantJournalView(initialTab: .wantToTry)
            }
            .sheet(item: $selectedSeasonalIngredient) { filter in
                SeasonalRecipesView(ingredient: filter.name, recipes: recipes)
            }
            .onAppear { rebuildCaches() }
            .onChange(of: recipes.count) { rebuildCaches() }
            .onChange(of: plannedMeals.count) { rebuildTodaysMeals() }
        }
    }

    private func rebuildCaches() {
        rebuildTodaysMeals()
        cachedRecentLogs = recipes.flatMap(\.cookingLog).sorted { $0.date > $1.date }
        cachedQuickRecipes = recipes.filter { $0.estimatedTotalMinutes <= 30 }
            .sorted { $0.cookCount > $1.cookCount }
    }

    private func rebuildTodaysMeals() {
        let today = Calendar.current.startOfDay(for: Date())
        cachedTodaysMeals = plannedMeals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            quickActionsRow
            pantryHealthCard
            todaysMealsSection
            cookingActivityCard
            budgetCard
            if !seasonalIngredients.isEmpty {
                seasonalSpotlight
            }
        }
        .padding()
    }

    // MARK: - iPad Layout (Multi-Column)

    private var iPadLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            quickActionsRow

            HStack(alignment: .top, spacing: 20) {
                // Left column
                VStack(alignment: .leading, spacing: 20) {
                    pantryHealthCard
                    todaysMealsSection
                    if !seasonalIngredients.isEmpty {
                        seasonalSpotlight
                    }
                }
                .frame(maxWidth: .infinity)

                // Right column
                VStack(alignment: .leading, spacing: 20) {
                    cookingActivityCard
                    budgetCard
                    quickRecipesCard
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.miseDisplay)
                .foregroundStyle(Brand.cream)

            if let name = profile?.displayName, !name.isEmpty {
                Text(name)
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Brand.warmTan)
            }

            Text(DashboardView.dateString)
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default:      return "Good Night"
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

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            quickActionButton(icon: "timer", label: "Quick Meal", color: DashboardStyle.grains) {
                showingQuickMeals = true
            }
            quickActionButton(icon: "camera.fill", label: "Scan Receipt", color: Brand.warmTan) {
                showingReceiptScanner = true
            }
            quickActionButton(icon: "cart", label: "Shopping List", color: DashboardStyle.produce) {
                showingShoppingList = true
            }
            quickActionButton(icon: "fork.knife.circle", label: "Want to Try", color: Brand.spiceRed) {
                showingWantToTry = true
            }
        }
    }

    private func quickActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.15), in: Circle())

                Text(label)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            }
            .frame(width: 80)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pantry Health

    private var pantryHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(Brand.warmTan)
                Text("Pantry")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
                Spacer()
                Text("\(pantryItems.count) items")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            }

            if !expiredItems.isEmpty {
                pantryAlertRow(
                    icon: "exclamationmark.triangle.fill",
                    color: Brand.spiceRed,
                    text: "\(expiredItems.count) expired — \(expiredItems.prefix(2).map(\.name).joined(separator: ", "))",
                    isUrgent: true
                )
            }

            if !expiringItems.isEmpty {
                pantryAlertRow(
                    icon: "clock.badge.exclamationmark",
                    color: DashboardStyle.grains,
                    text: "\(expiringItems.count) expiring soon — \(expiringItems.prefix(2).map(\.name).joined(separator: ", "))",
                    isUrgent: false
                )
            }

            if expiredItems.isEmpty && expiringItems.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DashboardStyle.produce)
                    Text("All items fresh")
                        .font(.miseBody)
                        .foregroundStyle(Brand.muted)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    private func pantryAlertRow(icon: String, color: Color, text: String, isUrgent: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)

            Text(text)
                .font(.miseBody)
                .foregroundStyle(isUrgent ? color : Brand.cream.opacity(0.8))
                .lineLimit(1)

            Spacer()
        }
    }

    // MARK: - Today's Meals

    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(Brand.warmTan)
                Text("Today's Meals")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
                Spacer()
                if !todaysMeals.isEmpty {
                    Text("\(completedTodayCount)/\(todaysMeals.count) done")
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                }
            }

            if todaysMeals.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(Brand.muted)
                    Text("No meals planned — tap Plan to get started")
                        .font(.miseBody)
                        .foregroundStyle(Brand.muted)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(todaysMeals, id: \.id) { meal in
                    mealRow(meal)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: meal.mealType.systemImageName)
                .font(.title3)
                .foregroundStyle(colorForMealType(meal.mealType))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealType.displayName)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
                Text(meal.recipe?.title ?? "No recipe assigned")
                    .font(.miseBody.weight(.medium))
                    .foregroundStyle(Brand.cream)
                    .lineLimit(1)
            }

            Spacer()

            if meal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DashboardStyle.produce)
            } else if let recipe = meal.recipe {
                Text(recipe.formattedDuration)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            }
        }
    }

    private func colorForMealType(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch:     return DashboardStyle.produce
        case .dinner:    return DashboardStyle.meat
        case .snack:     return DashboardStyle.grains
        default:         return Brand.warmTan
        }
    }

    // MARK: - Cooking Activity

    private var cookingActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Cooking Activity")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
            }

            HStack(spacing: 0) {
                activityStat(
                    value: "\(thisWeekCookCount)",
                    label: "This Week",
                    icon: "chart.bar.fill"
                )

                activityStat(
                    value: cookingStreak > 0 ? "\(cookingStreak)d" : "—",
                    label: "Streak",
                    icon: "flame.fill"
                )

                activityStat(
                    value: "\(recipes.count)",
                    label: "Recipes",
                    icon: "book.closed.fill"
                )

                activityStat(
                    value: "\(favoriteRecipes.count)",
                    label: "Favorites",
                    icon: "heart.fill"
                )
            }

            if let lastCook = recentCookingLogs.first,
               let recipe = recipes.first(where: { $0.cookingLog.contains(where: { $0.id == lastCook.id }) }) {
                Divider().overlay(Brand.border)
                HStack(spacing: 8) {
                    Text("Last cooked:")
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                    Text(recipe.title)
                        .font(.miseMeta.weight(.medium))
                        .foregroundStyle(Brand.cream)
                        .lineLimit(1)
                    Spacer()
                    if let rating = lastCook.rating {
                        StarRatingView(rating: rating, font: .caption2)
                    }
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    private func activityStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.cream)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Brand.muted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Budget

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(DashboardStyle.produce)
                Text("Weekly Budget")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$\(Int(weeklySpend))")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Brand.cream)

                if let budget = weeklyBudget, budget > 0 {
                    Text("/ $\(Int(budget))")
                        .font(.miseBody)
                        .foregroundStyle(Brand.muted)
                }

                Spacer()

                Text("past 7 days")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            }

            if let budget = weeklyBudget, budget > 0 {
                let fraction = min(weeklySpend / budget, 1.0)
                let barColor: Color = fraction > 0.9 ? Brand.spiceRed : (fraction > 0.7 ? DashboardStyle.grains : DashboardStyle.produce)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Brand.border)
                            .frame(height: 6)

                        Capsule()
                            .fill(barColor)
                            .frame(width: geo.size.width * fraction, height: 6)
                    }
                }
                .frame(height: 6)

                Text(fraction >= 1.0
                    ? "Budget reached"
                    : "$\(Int(budget - weeklySpend)) remaining")
                    .font(.miseMeta)
                    .foregroundStyle(fraction > 0.9 ? Brand.spiceRed : Brand.muted)
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Seasonal Spotlight

    private var seasonalSpotlight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Brand.herbGreen)
                Text("In Season Now")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
            }

            FlowLayout(spacing: 8) {
                ForEach(seasonalIngredients, id: \.self) { ingredient in
                    Button {
                        selectedSeasonalIngredient = IngredientFilter(name: ingredient)
                    } label: {
                        Text(ingredient.capitalized)
                            .font(.miseMeta.weight(.medium))
                            .foregroundStyle(Brand.cream)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Brand.herbGreen.opacity(0.25), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Tap an ingredient to find something to make")
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Quick Recipes (iPad)

    private var quickRecipesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(DashboardStyle.grains)
                Text("Quick Meals")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
                Spacer()
                Text("≤ 30 min")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            }

            if quickRecipes.isEmpty {
                Text("No quick recipes yet")
                    .font(.miseBody)
                    .foregroundStyle(Brand.muted)
                    .padding(.vertical, 4)
            } else {
                ForEach(quickRecipes.prefix(4), id: \.id) { recipe in
                    HStack(spacing: 10) {
                        Text(recipe.title)
                            .font(.miseBody)
                            .foregroundStyle(Brand.cream)
                            .lineLimit(1)
                        Spacer()
                        Text(recipe.formattedDuration)
                            .font(.miseMeta)
                            .foregroundStyle(Brand.muted)
                        if let rating = recipe.averageRating {
                            StarRatingView(rating: Int(rating.rounded()), font: .caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Ingredient Filter (Identifiable wrapper for sheet)

struct IngredientFilter: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Seasonal Recipes View

struct SeasonalRecipesView: View {
    let ingredient: String
    let recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @State private var showingGenerator = false

    private var matchingRecipes: [Recipe] {
        recipes.filter { recipe in
            recipe.ingredients.contains { $0.name.localizedCaseInsensitiveContains(ingredient) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matchingRecipes.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "leaf")
                            .font(.system(size: 48))
                            .foregroundStyle(Brand.herbGreen)
                        Text("No recipes with \(ingredient.capitalized)")
                            .font(.miseHeading)
                            .foregroundStyle(Brand.cream)
                        Text("\(ingredient.capitalized) is at its best right now — let's make something delicious with it.")
                            .font(.miseBody)
                            .foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button {
                            showingGenerator = true
                        } label: {
                            Label("Let's Cook With It", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(Brand.midnight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Brand.herbGreen, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        Section {
                            Button {
                                showingGenerator = true
                            } label: {
                                Label("Generate a \(ingredient.capitalized) Recipe", systemImage: "sparkles")
                                    .foregroundStyle(Brand.herbGreen)
                            }
                            .listRowBackground(Brand.herbGreen.opacity(0.1))
                        }

                        Section("Your Recipes") {
                            ForEach(matchingRecipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recipe.title)
                                            .font(.miseBody.weight(.medium))
                                            .foregroundStyle(Brand.cream)
                                        Text(recipe.formattedDuration)
                                            .font(.miseMeta)
                                            .foregroundStyle(Brand.muted)
                                    }
                                }
                                .listRowBackground(Brand.surface)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Brand.midnight)
            .navigationTitle("\(ingredient.capitalized) Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Brand.warmTan)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                RecipeGeneratorView(initialIngredient: ingredient)
            }
        }
    }
}

// MARK: - Quick Meals View

struct QuickMealsView: View {
    let recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @State private var showingGenerator = false

    private var pantryIsEmpty: Bool {
        pantryItems.filter { !$0.isStaple }.isEmpty && pantryItems.filter(\.isStaple).isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    // Empty state — lead with generate
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "timer")
                            .font(.system(size: 48))
                            .foregroundStyle(Brand.warmTan)
                        Text("No Quick Recipes Yet")
                            .font(.miseHeading)
                            .foregroundStyle(Brand.cream)
                        Text("Recipes under 30 minutes will appear here once you add some — or let AI suggest one now.")
                            .font(.miseBody)
                            .foregroundStyle(Brand.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        if pantryIsEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "cart.badge.plus")
                                    .foregroundStyle(Brand.warmTan)
                                Text("Add pantry items to get suggestions based on what you have on hand.")
                                    .font(.caption)
                                    .foregroundStyle(Brand.muted)
                            }
                            .padding(.horizontal, 40)
                        }
                        Button {
                            showingGenerator = true
                        } label: {
                            Label("Generate a Quick Meal", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(Brand.midnight)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Brand.warmTan, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        // Generate button at the top of the list
                        Section {
                            Button {
                                showingGenerator = true
                            } label: {
                                Label("Generate a Quick Meal", systemImage: "sparkles")
                                    .foregroundStyle(Brand.warmTan)
                            }
                            .listRowBackground(Brand.warmTan.opacity(0.1))

                            if pantryIsEmpty {
                                Label("Add pantry items for personalised suggestions.", systemImage: "cart.badge.plus")
                                    .font(.caption)
                                    .foregroundStyle(Brand.muted)
                                    .listRowBackground(Color.clear)
                            }
                        }

                        Section {
                            ForEach(recipes) { recipe in
                                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recipe.title)
                                                .font(.miseBody.weight(.medium))
                                                .foregroundStyle(Brand.cream)
                                            Text(recipe.cuisine.rawValue.capitalized)
                                                .font(.miseMeta)
                                                .foregroundStyle(Brand.muted)
                                        }
                                        Spacer()
                                        Text(recipe.formattedDuration)
                                            .font(.miseMeta)
                                            .foregroundStyle(Brand.warmTan)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Brand.warmTan.opacity(0.15), in: Capsule())
                                    }
                                }
                                .listRowBackground(Brand.surface)
                            }
                        } header: {
                            Text("Your Quick Recipes")
                                .foregroundStyle(Brand.muted)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Brand.midnight)
            .navigationTitle("Quick Meals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Brand.warmTan)
                }
            }
            .sheet(isPresented: $showingGenerator) {
                QuickGenerateView(quickMealMode: true)
            }
        }
    }
}

// MARK: - Flow Layout (for seasonal tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, CGSize(width: maxWidth, height: y + rowHeight))
    }
}

// MARK: - Previews

#Preview("Dashboard - iPhone") {
    DashboardView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}

#Preview("Dashboard - iPad") {
    DashboardView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}
