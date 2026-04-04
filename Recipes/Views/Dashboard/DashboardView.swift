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
    @Binding var selectedTab: AppTab
    @Binding var planAndShopSegment: PlanAndShopSegment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \PantryItem.expirationDate) private var pantryItems: [PantryItem]
    @Query private var plannedMeals: [PlannedMeal]
    @Query(sort: \MealPlan.startDate, order: .reverse) private var mealPlans: [MealPlan]
    @Query private var profiles: [UserProfile]
    /// Fetched directly — avoids flatMapping over the entire recipe graph.
    @Query(sort: \CookingLogEntry.date, order: .reverse) private var cookingLogs: [CookingLogEntry]
    @Query(sort: \RestaurantJournalEntry.dateVisited, order: .reverse) private var journalEntries: [RestaurantJournalEntry]
    /// Scalar-only — relationship access only allowed inside rebuildSuggestion().
    @Query private var recipes: [Recipe]
    @Query private var shoppingItems: [GroceryItem]

    @State private var activeSheet: DashboardSheet? = nil
    @State private var startCookingRecipe: Recipe? = nil
    @State private var cachedTodaysMeals: [PlannedMeal] = []
    @State private var cachedCookingStreak = 0
    @State private var suggestions: [DiscoverSuggestion] = []
    @State private var suggestionIndex: Int = 0
    @State private var suggestionTask: Task<Void, Never>?

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

    private var pantryNeedsAttention: Bool {
        !expiredItems.isEmpty || !expiringItems.isEmpty
    }

    /// Capped at 50 — covers any realistic streak or weekly count.
    private var recentCookingLogs: [CookingLogEntry] { Array(cookingLogs.prefix(50)) }

    private var thisWeekCookCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return recentCookingLogs.filter { $0.date >= weekAgo }.count
    }

    /// Computed once and cached in `cachedCookingStreak` — not called from body.
    private func computeCookingStreak() -> Int {
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

    private var shoppingItemCount: Int {
        shoppingItems.filter { !$0.isPurchased }.count
    }

    private var currentMealType: MealType {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 11 ? .breakfast : (hour < 15 ? .lunch : .dinner)
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        activeSheet = .logVisit
                    } label: {
                        Image(systemName: "fork.knife")
                            .foregroundStyle(Brand.warmTan)
                    }
                    .accessibilityLabel("Log a restaurant visit")

                    Button {
                        activeSheet = .receiptScanner
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .foregroundStyle(Brand.warmTan)
                    }
                    .accessibilityLabel("Scan receipt")
                }
            }
            .navigationDestination(item: $startCookingRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .receiptScanner:
                    ReceiptScannerView()
                case .logVisit:
                    RestaurantJournalView(initialTab: .journal)
                case .addMeal(let mealType):
                    let today = Date()
                    if let plan = mealPlans.first(where: { $0.startDate <= today && $0.endDate >= today }) {
                        AddMealView(plan: plan, preselectMealType: mealType, preselectDate: today)
                    }
                case .discoverGenerator(let hint):
                    QuickGenerateView(mealType: currentMealType, initialDescription: hint)
                }
            }
            .task {
                ensurePlanExists()
                rebuildTodaysMeals()
                cachedCookingStreak = computeCookingStreak()
                await rebuildSuggestions()
            }
            .onChange(of: plannedMeals.count) { rebuildTodaysMeals() }
            .onChange(of: cookingLogs.count)  { cachedCookingStreak = computeCookingStreak() }
            .onChange(of: pantryItems.count) { scheduleSuggestionRebuild() }
            .onChange(of: recipes.count)    { scheduleSuggestionRebuild() }
        }
    }

    @MainActor
    private func ensurePlanExists() {
        let today = Date()
        guard !mealPlans.contains(where: { $0.startDate <= today && $0.endDate >= today }) else { return }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: today)
        guard
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end   = calendar.date(from: DateComponents(year: year + 1, month: 12, day: 31))
        else { return }
        modelContext.insert(MealPlan(name: "My Meals", startDate: start, endDate: end))
    }

    @MainActor
    private func rebuildTodaysMeals() {
        let today = Calendar.current.startOfDay(for: Date())
        cachedTodaysMeals = plannedMeals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    /// Cancel any in-flight rebuild before starting a new one.
    /// Prevents concurrent rebuilds from accumulating intermediate arrays in memory.
    private func scheduleSuggestionRebuild() {
        suggestionTask?.cancel()
        suggestionTask = Task { await rebuildSuggestions() }
    }

    @MainActor
    private func rebuildSuggestions() async {
        let hemisphere = profiles.first?.hemisphere ?? .northern
        let pantryNames = pantryItems.map { $0.name.lowercased() }
        let expiringItems = self.expiringItems
        let expiringNames = expiringItems.map { $0.name.lowercased() }
        let seasonalItems = SeasonalAwarenessService.currentlyInSeason(hemisphere: hemisphere)
            .filter { !$0.availableAllYear }

        var result: [DiscoverSuggestion] = []

        // 1. Library pick — scored
        if !recipes.isEmpty {
            let targetMealType = currentMealType
            let seasonalNames = seasonalItems.map { $0.name.lowercased() }
            var ranked: [(score: Int, recipe: Recipe, reason: String)] = []
            for recipe in recipes {
                var score = 0; var reason = ""
                let ings = recipe.ingredients.map { $0.name.lowercased() }
                for exp in expiringNames {
                    if ings.contains(where: { $0.contains(exp) || exp.contains($0) }) {
                        score += 10
                        if reason.isEmpty {
                            reason = "Uses \(expiringItems.first { $0.name.lowercased() == exp }?.name ?? exp) expiring soon"
                        }
                        break
                    }
                }
                if !pantryNames.isEmpty {
                    let covered = Double(ings.filter { ing in pantryNames.contains(where: { ing.contains($0) || $0.contains(ing) }) }.count)
                    let coverage = covered / Double(max(ings.count, 1))
                    if coverage >= 0.4 { score += Int(coverage * 5); if reason.isEmpty { reason = "You have \(Int(coverage * 100))% of the ingredients" } }
                }
                if recipe.mealType == targetMealType { score += 3 }
                for s in seasonalNames { if ings.contains(where: { $0.contains(s) || s.contains($0) }) { score += 2; if reason.isEmpty { reason = "In season now" }; break } }
                ranked.append((score, recipe, reason.isEmpty ? "From your library" : reason))
            }
            ranked.sort { $0.score != $1.score ? $0.score > $1.score : Bool.random() }
            if let top = ranked.first {
                result.append(DiscoverSuggestion(mode: .libraryPick(reason: top.reason), recipe: top.recipe))
            }
        }

        // 2. Quick meal — randomly show a library recipe or prompt to generate
        let quickRecipes = recipes.filter { $0.estimatedTotalMinutes <= 30 }.shuffled()
        let useQuickLibrary = !quickRecipes.isEmpty && Bool.random()
        result.append(DiscoverSuggestion(
            mode: .quickMeal,
            recipe: useQuickLibrary ? quickRecipes.first : nil,
            generatorHint: "Suggest a satisfying meal that can be made in 30 minutes or less. Keep it simple and realistic."
        ))

        // 3. Snack — randomly show a library recipe or prompt to generate
        let snackRecipes = recipes.filter { $0.mealType == .snack }.shuffled()
        let useSnackLibrary = !snackRecipes.isEmpty && Bool.random()
        result.append(DiscoverSuggestion(
            mode: .snack,
            recipe: useSnackLibrary ? snackRecipes.first : nil,
            generatorHint: "Suggest a fun, creative snack — something a bit more interesting than crackers and cheese, but still easy to throw together."
        ))

        // 4. Seasonal ingredient
        if let item = seasonalItems.randomElement() {
            let fact = DashboardView.seasonalFacts[item.name.lowercased()]
                ?? "\(item.name.capitalized) is at its peak right now."
            let match = recipes.shuffled().first { r in
                r.ingredients.contains { $0.name.localizedCaseInsensitiveContains(item.name) }
            }
            result.append(DiscoverSuggestion(
                mode: .seasonal(ingredient: item.name, fact: fact),
                recipe: match,
                generatorHint: "Make a recipe that features \(item.name.lowercased()), which is currently in season."
            ))
        }

        // 5. Restaurant recreation
        for entry in journalEntries {
            if let dish = entry.dishesOrdered.first(where: { $0.wantToRecreate }) {
                result.append(DiscoverSuggestion(
                    mode: .recreation(dish: dish, restaurant: entry.restaurantName),
                    recipe: nil,
                    generatorHint: "Recreate the dish \"\(dish.displayName)\" that I had at \(entry.restaurantName). Match the flavours and style as closely as possible."
                ))
                break
            }
        }

        // 6. New cuisine — pick one the user hasn't cooked yet
        let usedCuisines = Set(recipes.map { $0.cuisine })
        let candidates = DashboardView.cuisineFacts.filter { !usedCuisines.contains($0.key) }
        if let (cuisine, info) = candidates.randomElement() {
            result.append(DiscoverSuggestion(
                mode: .newCuisine(cuisine: cuisine, dish: info.dish, fact: info.fact),
                recipe: nil,
                generatorHint: "Make a \(info.dish) — a classic \(cuisine.rawValue.capitalized) dish."
            ))
        }

        suggestions = result.filter { $0.recipe != nil || $0.generatorHint != nil }
        suggestionIndex = 0
    }

    private func cycleSuggestion() {
        guard suggestions.count > 1 else { return }
        suggestionIndex = (suggestionIndex + 1) % suggestions.count
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.bottom, 28)

            sectionHeader("Today")
            todaysMealsHeroCard
                .padding(.bottom, 12)
            cookingStatLine
                .padding(.bottom, 24)

            sectionHeader("My Kitchen")
            myKitchenCard
                .padding(.bottom, 24)

            if !suggestions.isEmpty {
                HStack(alignment: .center) {
                    sectionHeader("Discover")
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { cycleSuggestion() }
                    } label: {
                        Image(systemName: "arrow.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(Brand.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next suggestion")
                    .padding(.bottom, 8)
                }
                discoverCard(suggestions[suggestionIndex % suggestions.count])
                    .padding(.bottom, 24)
            }
        }
        .padding()
    }

    // MARK: - iPad Layout (Multi-Column)

    private var iPadLayout: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection

            HStack(alignment: .top, spacing: 20) {
                // Left column — today focus
                VStack(alignment: .leading, spacing: 20) {
                    todaysMealsHeroCard
                    myKitchenCard
                }
                .frame(maxWidth: .infinity)

                // Right column — actions & activity
                VStack(alignment: .leading, spacing: 20) {
                    cookingStatLine
                    if !suggestions.isEmpty {
                        discoverCard(suggestions[suggestionIndex % suggestions.count])
                    }
                    quickRecipesCard
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(Brand.muted)
            .tracking(1)
            .padding(.bottom, 8)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(.title, design: .rounded, weight: .medium))
                .foregroundStyle(Brand.cream)

            if let name = profile?.displayName, !name.isEmpty {
                Text(name)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(Brand.warmTan)
            }

            Text(DashboardView.dateString)
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
        .accessibilityElement(children: .combine)
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

    // MARK: - Today's Meals Hero Card

    private let primaryMealTypes: [MealType] = [.breakfast, .lunch, .dinner]

    private var todaysMealsHeroCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(primaryMealTypes.enumerated()), id: \.element) { index, mealType in
                let meal = todaysMeals.first { $0.mealType == mealType }
                if let meal {
                    mealHeroRow(meal)
                } else {
                    emptyMealRow(mealType)
                }
                if index < primaryMealTypes.count - 1 {
                    Divider()
                        .overlay(Brand.border)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 20)
        // .contain keeps individual meal rows focusable and their buttons activatable via VoiceOver.
        // .combine would swallow all children into one non-interactive element.
        .accessibilityElement(children: .contain)
    }

    private func emptyMealRow(_ mealType: MealType) -> some View {
        return Button { activeSheet = .addMeal(mealType) } label: {
            HStack(spacing: 14) {
                Image(systemName: mealType.systemImageName)
                    .font(.title3)
                    .foregroundStyle(colorForMealType(mealType).opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(colorForMealType(mealType).opacity(0.07), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mealType.displayName)
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted.opacity(0.6))
                    Text("Nothing planned")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Brand.muted)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(Brand.muted.opacity(0.5))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mealType.displayName): nothing planned")
        .accessibilityHint("Tap to add a meal")
    }

    private func mealHeroRow(_ meal: PlannedMeal) -> some View {
        let tappable = meal.recipe != nil && !meal.isCompleted
        let content = HStack(spacing: 14) {
            Image(systemName: meal.mealType.systemImageName)
                .font(.title3)
                .foregroundStyle(colorForMealType(meal.mealType))
                .frame(width: 40, height: 40)
                .background(colorForMealType(meal.mealType).opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.mealType.displayName)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
                Text(meal.recipe?.title ?? "No recipe assigned")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(meal.isCompleted ? Brand.muted : Brand.cream)
                    .lineLimit(2)
                    .strikethrough(meal.isCompleted)
                if let recipe = meal.recipe, !meal.isCompleted {
                    Text(recipe.formattedDuration)
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted)
                }
            }

            Spacer()

            if meal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Brand.herbGreen)
            } else if tappable {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            }
        }

        return Group {
            if tappable, let recipe = meal.recipe {
                Button { startCookingRecipe = recipe } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(meal.mealType.displayName): \(recipe.title)")
                    .accessibilityHint("Tap to start cooking")
            } else {
                content
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(meal.isCompleted
                        ? "\(meal.mealType.displayName): \(meal.recipe?.title ?? "no recipe"), cooked"
                        : "\(meal.mealType.displayName): \(meal.recipe?.title ?? "no recipe assigned")")
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

    // MARK: - Discover Card

    private func discoverCard(_ s: DiscoverSuggestion) -> some View {
        Button {
            if let recipe = s.recipe {
                startCookingRecipe = recipe
            } else {
                let hint = suggestions.indices.contains(suggestionIndex) ? suggestions[suggestionIndex].generatorHint : nil
                activeSheet = .discoverGenerator(hint)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: s.mode.icon)
                    .font(.title2)
                    .foregroundStyle(s.mode.accentColor)
                    .frame(width: 44, height: 44)
                    .background(s.mode.accentColor.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(s.mode.label.uppercased())
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(Brand.muted)
                        .tracking(0.8)

                    Text(s.title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Brand.cream)
                        .lineLimit(2)

                    if let detail = s.detail {
                        Text(detail)
                            .font(.miseMeta)
                            .foregroundStyle(Brand.muted)
                    }
                }

                Spacer()

                Image(systemName: s.recipe != nil ? "chevron.right" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
                    .accessibilityHidden(true)
            }
            .padding()
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(s.mode.label): \(s.title)\(s.detail.map { ". \($0)" } ?? "")")
        .accessibilityHint(s.recipe != nil ? "Tap to open recipe" : "Tap to generate with AI")
    }

    // MARK: - My Kitchen Card (shopping + pantry alerts combined)

    private var myKitchenCard: some View {
        VStack(spacing: 0) {
            // Shopping row — always present, tappable
            Button {
                planAndShopSegment = .shopping
                selectedTab = .planAndShop
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "cart.fill")
                        .font(.title3)
                        .foregroundStyle(DashboardStyle.produce)
                        .frame(width: 36, height: 36)
                        .background(DashboardStyle.produce.opacity(0.15), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shopping List")
                            .font(.miseHeading)
                            .foregroundStyle(Brand.cream)
                        Text(shoppingItemCount == 0
                             ? "Nothing on your list"
                             : "\(shoppingItemCount) \(shoppingItemCount == 1 ? "item" : "items") remaining")
                            .font(.miseMeta)
                            .foregroundStyle(Brand.muted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Brand.muted)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shopping List, \(shoppingItemCount == 0 ? "empty" : "\(shoppingItemCount) items remaining")")
            .accessibilityHint("Tap to open your shopping list")

            // Pantry alerts — only when something needs attention
            if pantryNeedsAttention {
                Divider()
                    .overlay(Brand.border)
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 8) {
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
                .accessibilityHidden(true)

            Text(text)
                .font(.miseBody)
                .foregroundStyle(isUrgent ? color : Brand.cream.opacity(0.8))
                .lineLimit(1)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUrgent ? "Alert: \(text)" : text)
    }

    // MARK: - Cooking Stat Line

    private var cookingStatLine: some View {
        HStack(spacing: 0) {
            if cachedCookingStreak > 1 {
                Label("\(cachedCookingStreak)-day streak", systemImage: "flame.fill")
                    .font(.miseMeta)
                    .foregroundStyle(.orange)
                    .padding(.trailing, 16)
            }

            if thisWeekCookCount > 0 {
                Label("\(thisWeekCookCount) cooked this week", systemImage: "chart.bar.fill")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
            } else if cachedCookingStreak == 0 {
                Label("No cooks logged yet", systemImage: "chart.bar.fill")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted.opacity(0.6))
            }

            Spacer()

            Text("\(recipes.count) \(recipes.count == 1 ? "recipe" : "recipes")")
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Quick Recipes (iPad only)

    private var quickRecipesCard: some View {
        let quickRecipes = recipes.filter { $0.estimatedTotalMinutes <= 30 }

        return VStack(alignment: .leading, spacing: 12) {
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
                    }
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Fact Tables

    static let seasonalFacts: [String: String] = [
        // SPRING
        "asparagus":         "Best picked in spring when the tips are still tight.",
        "artichoke":         "The artichoke is actually a flower bud — left unpicked, it blooms into a stunning purple thistle.",
        "rhubarb":           "Botanically a vegetable, but almost always treated as a fruit.",
        "peas":              "Fresh peas start converting sugar to starch the moment they're picked — freezing stops that clock.",
        "snap peas":         "Unlike shelling peas, the entire snap pea pod is edible — pull the tough string along the seam first.",
        "radish":            "Radishes grow some of the fastest of any vegetable — from seed to table in as little as three weeks.",
        "spinach":           "Baby spinach and mature spinach have different textures and iron bioavailability.",
        "arugula":           "The peppery bite in arugula comes from glucosinolates — the same compounds that give mustard its heat.",
        "fava beans":        "Fava beans are one of the oldest cultivated plants — they've been found in ancient Egyptian tombs.",
        "mint":              "Mint spreads aggressively underground — most gardeners grow it in containers to keep it from taking over.",
        "watercress":        "Watercress ranks among the most nutrient-dense vegetables per gram of any leafy green.",
        "fennel":            "Every part of fennel is edible — the bulb, stalks, fronds, and seeds all have distinct culinary uses.",
        "strawberry":        "Peak sweetness comes from warm days and cool nights.",
        "leek":              "Leeks are harvested when finger-sized but can be left longer for a milder, sweeter flavour.",

        // SUMMER
        "tomato":            "The US Supreme Court ruled it a vegetable in 1893. Botanists still disagree.",
        "cherry tomato":     "Cherry tomatoes are thought to be closer to the wild ancestors of all cultivated tomatoes.",
        "corn":              "Sweetness converts to starch fast — best eaten the same day it's picked.",
        "zucchini":          "Left unpicked, a zucchini can grow to baseball-bat size overnight.",
        "yellow squash":     "Yellow squash and zucchini are essentially the same plant — just different varieties bred for colour.",
        "bell pepper":       "Green, yellow, orange, and red bell peppers are all the same fruit at different stages of ripeness.",
        "jalapeño":          "Most of the heat in a jalapeño is in the white pith, not the seeds.",
        "shishito pepper":   "About one in ten shishito peppers will be surprisingly spicy — the rest are mild.",
        "eggplant":          "Named after the small, white, egg-shaped variety — not the familiar deep-purple kind.",
        "cucumber":          "Cucumbers are 96% water, making them one of the most hydrating foods you can eat.",
        "green bean":        "Called 'string beans' until breeders developed the stringless variety in the 1890s.",
        "okra":              "Okra's slippery texture comes from mucilage — the same quality that makes it a natural gumbo thickener.",
        "tomatillo":         "Despite resembling small green tomatoes, tomatillos are more closely related to gooseberries.",
        "basil":             "Fresh basil bruises and blackens quickly — tear rather than chop it to keep the edges bright.",
        "lemongrass":        "Lemongrass contains citral, the same compound responsible for lemon's scent — but no citrus at all.",
        "peach":             "A ripe peach should smell fragrant at the stem end — that's the truest sign of readiness.",
        "nectarine":         "Nectarines aren't a cross between a peach and a plum — they're a natural genetic variation of peach.",
        "watermelon":        "Watermelon is 92% water and was historically carried by travellers as portable hydration.",
        "cantaloupe":        "The netting on cantaloupe skin forms as the flesh grows faster than the rind — the cracks create the pattern.",
        "blueberry":         "The blue colour comes from anthocyanins — the same antioxidants that give red wine and purple cabbage their hue.",
        "blackberry":        "What looks like a single blackberry is actually a cluster of tiny individual fruits called drupelets.",
        "raspberry":         "When you pick a raspberry, it comes off hollow — the core stays on the plant.",
        "plum":              "The white bloom on a plum's skin is a natural waxy coating that protects the fruit.",
        "fig":               "Figs are inverted flowers — what you're eating is technically the flower.",
        "mango":             "There are over 500 mango varieties, and most of the world's supply comes from India.",
        "lime":              "The most common supermarket lime (Persian) is a seedless hybrid — a genuine botanical accident.",
        "passion fruit":     "A passion fruit is ready when the skin is wrinkled — smooth skin means it's not yet ripe.",

        // AUTUMN
        "pumpkin":           "Smaller pumpkins tend to have sweeter, denser flesh than the large carving varieties.",
        "sweet potato":      "Sweet potatoes and yams are entirely different plants — most 'yams' in North America are sweet potatoes.",
        "butternut squash":  "Butternut squash is botanically a fruit. Its hollow seed cavity is perfect for stuffing.",
        "acorn squash":      "Acorn squash gets its name from its shape — the green skin softens enough to eat after roasting.",
        "delicata squash":   "Delicata squash has thin, edible skin that doesn't need peeling — unusual for a winter squash.",
        "brussels sprout":   "Brussels sprouts become sweeter after a frost — cold converts their starches to sugars.",
        "kale":              "A light frost actually sweetens kale — cold converts starches to sugars right in the leaf.",
        "beet":              "The pigment in red beets, betanin, can temporarily tint urine pink — entirely harmless.",
        "parsnip":           "Parsnips were used as a sweetener in Europe before sugar cane became widely available.",
        "turnip":            "Young turnips have a mild, slightly sweet flavour — the bitterness increases with size and age.",
        "chestnut":          "Unlike most nuts, chestnuts are low in fat and high in starch — they behave more like a grain.",
        "persimmon":         "Astringent varieties (like Hachiya) must be fully ripe before eating — unripe ones are intensely puckering.",
        "apple":             "Over 7,500 apple varieties exist worldwide — most stores carry fewer than ten.",
        "pear":              "Pears ripen from the inside out, so check the neck near the stem rather than the skin.",
        "cranberry":         "Cranberries float — commercial harvesting floods the bogs so the berries rise to the surface.",
        "grape":             "Wine grapes are smaller and more intensely flavoured than table grapes — size isn't quality.",
        "quince":            "Raw quince is too astringent to eat, but heat transforms it — cooking turns the flesh a deep rose.",
        "pomegranate":       "Each pomegranate contains 200 to 1,400 seeds, called arils.",

        // WINTER
        "cauliflower":       "Cauliflower comes in purple, orange, and green varieties — all taste similar but differ in nutrients.",
        "celery root":       "Celeriac is a different cultivar from stalk celery, bred over centuries for its root rather than its stems.",
        "sunchoke":          "Jerusalem artichokes have nothing to do with Jerusalem — the name likely corrupted from the Italian 'girasole' (sunflower).",
        "rutabaga":          "Rutabagas are a natural cross between a turnip and a wild cabbage, developed in Scandinavia around 1600.",
        "radicchio":         "Radicchio's bitterness intensifies in warmth and mellows with cold — it's at its best after a frost.",
        "endive":            "Belgian endive is grown in complete darkness — light exposure turns the leaves green and sharply bitter.",
        "meyer lemon":       "Meyer lemons are a cross between a lemon and a mandarin orange — hence the sweeter, floral juice.",
        "blood orange":      "The red flesh of blood oranges comes from anthocyanins that only develop when nights turn cold.",
        "grapefruit":        "Grapefruit appeared in Barbados around 1750 as a natural hybrid of the pomelo — a relatively new fruit.",
        "navel orange":      "Every navel orange is a clone — all trees descend from a single mutant branch found in Brazil in the 1820s.",
        "clementine":        "Clementines are seedless because they're self-sterile — growers keep other varieties away to prevent pollination.",

        // YEAR-ROUND (used in scoring but rarely shown — kept for completeness)
        "carrot":            "Originally purple and white — the orange variety was selectively bred in the Netherlands.",
        "cherry":            "Cherries contain melatonin, which may help support healthy sleep rhythms.",
    ]

    static let cuisineFacts: [Cuisine: (dish: String, fact: String)] = [
        .japanese:   ("Ramen",          "Japan has over 30 distinct regional ramen styles — Sapporo's rich miso broth shares almost nothing with Tokyo's delicate shoyu."),
        .thai:       ("Pad Thai",       "Pad Thai was popularised in the 1930s as part of a campaign to forge a unified Thai national identity."),
        .indian:     ("Butter Chicken", "Butter chicken was invented by accident in 1950s Delhi — leftover tandoori chicken simmered into a tomato gravy."),
        .mexican:    ("Mole Negro",     "A traditional mole negro can contain over 30 ingredients and takes days to prepare properly."),
        .moroccan:   ("Tagine",         "The conical lid of a tagine creates a convection cycle that continuously bastes the food in its own steam."),
        .korean:     ("Bibimbap",       "Bibimbap means 'mixed rice' — the joy is in the moment you stir everything together at the table."),
        .greek:      ("Spanakopita",    "Skilled pastry makers stretch phyllo dough thin enough to read a newspaper through."),
        .vietnamese: ("Pho",            "A traditional pho broth is simmered for up to 24 hours with charred ginger and toasted spices."),
        .spanish:    ("Paella",         "Authentic Valencian paella is cooked over orange wood — the smoke is considered part of the flavour."),
        .mediterranean: ("Mezze",       "A full mezze spread can include over 30 small dishes, all arriving at once."),
        .italian:    ("Carbonara",      "Authentic carbonara contains no cream — the creaminess comes entirely from egg yolks and starchy pasta water."),
        .french:     ("Bouillabaisse",  "Traditional bouillabaisse must include at least four types of fish, all from the Mediterranean."),
        .ethiopian:  ("Injera",         "Injera is both the plate and the utensil — you tear it and use it to scoop everything else."),
        .brazilian:  ("Feijoada",       "Brazil's national dish — a black bean and pork stew slow-cooked for hours and served with rice, farofa, and orange slices."),
    ]
}

// MARK: - Ingredient Filter (Identifiable wrapper for sheet)

struct IngredientFilter: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Dashboard Sheet

enum DashboardSheet: Identifiable {
    case receiptScanner
    case logVisit
    case addMeal(MealType)
    case discoverGenerator(String?)

    var id: String {
        switch self {
        case .receiptScanner:           return "receiptScanner"
        case .logVisit:                 return "logVisit"
        case .addMeal(let t):           return "addMeal_\(t.rawValue)"
        case .discoverGenerator(let h): return "discover_\(h ?? "none")"
        }
    }
}

// MARK: - Discover Types

enum DiscoverMode {
    case libraryPick(reason: String)
    case quickMeal
    case snack
    case seasonal(ingredient: String, fact: String)
    case recreation(dish: DishEntry, restaurant: String)
    case newCuisine(cuisine: Cuisine, dish: String, fact: String)

    var label: String {
        switch self {
        case .libraryPick:  return "From Your Kitchen"
        case .quickMeal:    return "Quick Meal"
        case .snack:        return "Snack"
        case .seasonal:     return "In Season"
        case .recreation:   return "Recreate This"
        case .newCuisine:   return "Explore"
        }
    }

    var icon: String {
        switch self {
        case .libraryPick:  return "fork.knife.circle.fill"
        case .quickMeal:    return "bolt.fill"
        case .snack:        return "leaf.fill"
        case .seasonal:     return "sun.max.fill"
        case .recreation:   return "sparkles"
        case .newCuisine:   return "globe"
        }
    }

    var accentColor: Color {
        switch self {
        case .libraryPick:  return Brand.warmTan
        case .quickMeal:    return DashboardStyle.grains
        case .snack:        return Brand.herbGreen
        case .seasonal:     return .orange
        case .recreation:   return Brand.warmTan
        case .newCuisine:   return .cyan
        }
    }
}

struct DiscoverSuggestion {
    let mode: DiscoverMode
    let recipe: Recipe?
    var generatorHint: String? = nil

    var title: String {
        switch mode {
        case .libraryPick:                    return recipe?.title ?? ""
        case .quickMeal:                      return recipe?.title ?? "Quick Meal"
        case .snack:                          return recipe?.title ?? "Snack Time"
        case .seasonal(let ing, _):           return recipe?.title ?? "Try \(ing.capitalized)"
        case .recreation(let dish, _):        return dish.displayName
        case .newCuisine(_, let dish, _):     return "Try making \(dish)"
        }
    }

    var detail: String? {
        switch mode {
        case .libraryPick(let reason):            return reason
        case .quickMeal:                          return recipe.map { "Ready in \($0.formattedDuration)" } ?? "Because not every meal needs a three-act structure."
        case .snack:                              return recipe.map { "Ready in \($0.formattedDuration)" } ?? "Something to tide you over — or just because."
        case .seasonal(_, let fact):              return fact
        case .recreation(_, let restaurant):      return "You had this at \(restaurant)"
        case .newCuisine(_, _, let fact):         return fact
        }
    }
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
                            .accessibilityHidden(true)
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
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var allRecipes: [Recipe]
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @State private var showingGenerator = false

    private var recipes: [Recipe] {
        allRecipes.filter { $0.estimatedTotalMinutes <= 30 }
    }

    private var pantryIsEmpty: Bool {
        pantryItems.count < 10
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
                            .accessibilityHidden(true)
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
                        } footer: {
                            if pantryIsEmpty {
                                Label("Add pantry items for personalised suggestions.", systemImage: "cart.badge.plus")
                                    .font(.caption)
                                    .foregroundStyle(Brand.muted)
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
    DashboardView(selectedTab: .constant(.mise), planAndShopSegment: .constant(.mealPlan))
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}

#Preview("Dashboard - iPad") {
    DashboardView(selectedTab: .constant(.mise), planAndShopSegment: .constant(.mealPlan))
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}
