import SwiftUI
import SwiftData

// MARK: - Recipe List View

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var searchText = ""
    @State private var selectedCuisine: Cuisine?
    @State private var selectedDifficulty: RecipeDifficulty?
    @State private var maxTimeFilter: Int?
    @State private var showFavoritesOnly = false
    @State private var selectedDietaryRestrictions: Set<DietaryRestriction> = []
    @State private var selectedTags: Set<String> = []
    @State private var selectedMealType: MealType?
    @State private var hasLoadedProfile = false
    @State private var showingAddRecipe = false
    @State private var showingRecipeGenerator = false
    @State private var showingImport = false
    @State private var showingRecipeAsCode = false
    @State private var showingFilters = false
    @State private var showingTagManagement = false
    @State private var cachedNoWasteMatches: [NoWasteMatchingEngine.MatchResult] = []
    @State private var recipeToDelete: Recipe?
    @Environment(TimerDeepLink.self) private var timerDeepLink
    @State private var isShowingDeepLinkedRecipe = false
    @State private var deepLinkedRecipe: Recipe? = nil
    @State private var deepLinkedStep: Int? = nil

    private var activeFilterCount: Int {
        var count = 0
        if selectedCuisine != nil { count += 1 }
        if selectedDifficulty != nil { count += 1 }
        if maxTimeFilter != nil { count += 1 }
        if showFavoritesOnly { count += 1 }
        if !selectedDietaryRestrictions.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if selectedMealType != nil { count += 1 }
        return count
    }

    private var filteredRecipes: [Recipe] {
        var result = recipes
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) ||
                $0.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
            }
        }
        if let cuisine = selectedCuisine {
            result = result.filter { $0.cuisine == cuisine }
        }
        if let difficulty = selectedDifficulty {
            result = result.filter { $0.difficulty == difficulty }
        }
        if let maxTime = maxTimeFilter {
            result = result.filter { $0.estimatedTotalMinutes <= maxTime }
        }
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite || $0.isAutoFavorite }
        }
        if !selectedDietaryRestrictions.isEmpty {
            result = result.filter { recipe in
                selectedDietaryRestrictions.isSubset(of: Set(recipe.dietaryRestrictions))
            }
        }
        if !selectedTags.isEmpty {
            result = result.filter { recipe in
                !selectedTags.isDisjoint(with: Set(recipe.tags))
            }
        }
        if let mealType = selectedMealType {
            result = result.filter { $0.mealType == mealType }
        }
        if !showFavoritesOnly {
            let favs = result.filter { $0.isFavorite || $0.isAutoFavorite }
            let rest = result.filter { !$0.isFavorite && !$0.isAutoFavorite }
            result = favs + rest
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !recipes.isEmpty {
                    // Recommendations teaser
                    Section {
                        NavigationLink {
                            RecommendationsView()
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Recommended for you")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Brand.cream)
                                    Text("Personalized suggestions based on your cooking history")
                                        .font(.miseMeta)
                                        .foregroundStyle(Brand.muted)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Brand.warmTan)
                            }
                        }
                    }

                    // No Waste quick access
                    if !pantryItems.isEmpty {
                        noWasteTeaser
                    }

                    seasonalSection
                }

                allRecipesSection
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes...")
            .navigationDestination(isPresented: $isShowingDeepLinkedRecipe) {
                if let recipe = deepLinkedRecipe {
                    RecipeDetailView(recipe: recipe, scrollToStep: deepLinkedStep)
                }
            }
            .onChange(of: timerDeepLink.pendingRecipeID) { _, id in
                guard let id else { return }
                deepLinkedRecipe = recipes.first { $0.id == id }
                if deepLinkedRecipe != nil {
                    deepLinkedStep = timerDeepLink.pendingStep
                    isShowingDeepLinkedRecipe = true
                    timerDeepLink.clear()
                }
            }
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button("Create Recipe", systemImage: "plus") {
                            showingAddRecipe = true
                        }
                        Button("Generate with AI", systemImage: "sparkles") {
                            showingRecipeGenerator = true
                        }
                        Button("Import Recipe", systemImage: "arrow.down.doc") {
                            showingImport = true
                        }
                        Button("Recipe as Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                            showingRecipeAsCode = true
                        }
                        Button("Manage Tags", systemImage: "tag") {
                            showingTagManagement = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add recipe")
                }

            }
            .sheet(isPresented: $showingAddRecipe) {
                RecipeEditorView()
            }
            .sheet(isPresented: $showingRecipeGenerator) {
                RecipeGeneratorView()
            }
            .sheet(isPresented: $showingImport) {
                RecipeImportView()
            }
            .sheet(isPresented: $showingRecipeAsCode) {
                RecipeAsCodePreviewView()
            }
            .sheet(isPresented: $showingTagManagement) {
                NavigationStack {
                    TagManagementView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingTagManagement = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingFilters) {
                RecipeFilterSheet(
                    selectedCuisine: $selectedCuisine,
                    selectedDifficulty: $selectedDifficulty,
                    maxTimeFilter: $maxTimeFilter,
                    showFavoritesOnly: $showFavoritesOnly,
                    selectedMealType: $selectedMealType,
                    selectedDietaryRestrictions: $selectedDietaryRestrictions,
                    selectedTags: $selectedTags,
                    availableTags: allTags
                )
                .presentationDetents([.medium])
            }
            .task {
                updateNoWasteMatches()
                hasLoadedProfile = true
            }
            .onChange(of: recipes.count) { updateNoWasteMatches() }
            .onChange(of: pantryItems.count) { updateNoWasteMatches() }
        }
    }

    private var allTags: [String] {
        let tags = Set(recipes.flatMap(\.tags))
        return tags.sorted { $0 < $1 }
    }

    private func updateNoWasteMatches() {
        cachedNoWasteMatches = NoWasteMatchingEngine.matchRecipes(
            recipes: recipes,
            pantryItems: pantryItems,
            maxMissing: 2
        )
    }

    // MARK: - Sections

    @ViewBuilder
    private var noWasteTeaser: some View {
        let topMatches = Array(cachedNoWasteMatches.prefix(3))

        if !topMatches.isEmpty {
            Section {
                ForEach(topMatches) { match in
                    NavigationLink {
                        RecipeDetailView(recipe: match.recipe)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.recipe.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Brand.cream)
                                HStack(spacing: 6) {
                                    Text("\(Int(match.coveragePercent))% covered")
                                        .foregroundStyle(match.missingIngredients.isEmpty ? Brand.herbGreen : Brand.warmTan)
                                    if !match.missingIngredients.isEmpty {
                                        Text("Need \(match.missingIngredients.count) more")
                                            .foregroundStyle(Brand.muted)
                                    }
                                }
                                .font(.miseMeta)
                            }
                            Spacer()
                            Text(match.recipe.formattedDuration)
                                .font(.miseMeta)
                                .foregroundStyle(Brand.muted)
                        }
                    }
                }

                NavigationLink {
                    NoWasteResultsView(recipes: recipes, pantryItems: pantryItems)
                } label: {
                    Text("See all matches")
                        .font(.miseMeta)
                        .foregroundStyle(Brand.warmTan)
                }
            } header: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Brand.herbGreen)
                    Text("Ready to cook")
                }
                .miseSectionHeader()
            }
        }
    }

    @ViewBuilder
    private var seasonalSection: some View {
        let seasonal = filteredRecipes.filter { recipe in
            let ingredientNames = recipe.ingredients.map(\.name)
            return SeasonalAwarenessService.seasonalityScore(ingredientNames: ingredientNames) > 0.5
        }

        if !seasonal.isEmpty {
            Section {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(seasonal.prefix(8)) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                                RecipeCardCompact(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .contentMargins(.vertical, 12, for: .scrollContent)
                .listRowInsets(EdgeInsets())
            } header: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf")
                        .foregroundStyle(Brand.herbGreen)
                    Text("In season")
                }
                .miseSectionHeader()
            }
        }
    }

    @ViewBuilder

    private var allRecipesSection: some View {
        Section {
            if recipes.isEmpty {
                ContentUnavailableView(
                    "No recipes yet",
                    systemImage: "book.pages",
                    description: Text("Add your first recipe to get started.")
                )
            } else if filteredRecipes.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting your search or filters.")
                )
            } else {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeRow(recipe: recipe)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            recipeToDelete = recipe
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("All recipes")
                    .miseSectionHeader()
                Spacer()
                Button {
                    showingFilters = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: activeFilterCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                        Text(activeFilterCount > 0 ? "Filters (\(activeFilterCount))" : "Filters")
                    }
                    .font(.caption)
                    .foregroundStyle(activeFilterCount > 0 ? .primary : .secondary)
                }
            }
        }
        .confirmationDialog(
            "Delete Recipe",
            isPresented: .init(
                get: { recipeToDelete != nil },
                set: { if !$0 { recipeToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let recipe = recipeToDelete {
                    modelContext.delete(recipe)
                    recipeToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(recipeToDelete?.title ?? "")\"? This cannot be undone.")
        }
    }
}

// MARK: - Cuisine Filter Sheet

// MARK: - Tag Chip Grid

struct TagChipGrid: View {
    let availableTags: [String]
    @Binding var selectedTags: Set<String>
    @Binding var tagSearch: String

    struct SearchField: View {
        @Binding var tagSearch: String
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tags...", text: $tagSearch)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !tagSearch.isEmpty {
                    Button { tagSearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var visibleTags: [String] {
        if tagSearch.isEmpty { return availableTags }
        return availableTags.filter { $0.localizedCaseInsensitiveContains(tagSearch) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleTags, id: \.self) { (tag: String) in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        if isSelected { selectedTags.remove(tag) }
                        else { selectedTags.insert(tag) }
                    } label: {
                        Text(tag)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: .capsule)
                            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.4)))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}


// MARK: - Dietary Chip Grid

struct DietaryChipGrid: View {
    @Binding var selectedRestrictions: Set<DietaryRestriction>
    let sortedRestrictions: [DietaryRestriction]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedRestrictions, id: \.self) { (restriction: DietaryRestriction) in
                    let isSelected = selectedRestrictions.contains(restriction)
                    Button {
                        if isSelected { selectedRestrictions.remove(restriction) }
                        else { selectedRestrictions.insert(restriction) }
                    } label: {
                        Text(restriction.displayName)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), in: .capsule)
                            .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.4)))
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct CuisineFilterSheet: View {
    @Binding var selectedCuisine: Cuisine?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // "All Cuisines" row
                Button {
                    selectedCuisine = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("All Cuisines")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedCuisine == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                }

                // One row per cuisine
                ForEach(Cuisine.allCases, id: \.self) { cuisine in
                    Button {
                        selectedCuisine = cuisine
                        dismiss()
                    } label: {
                        HStack {
                            Text(cuisine.rawValue.capitalized)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedCuisine == cuisine {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Cuisine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if selectedCuisine != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Clear") {
                            selectedCuisine = nil
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Brand.cream)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(recipe.formattedDuration)
                    Text("·").opacity(0.5)
                    Image(systemName: "fork.knife")
                    Text(recipe.cuisine.rawValue.capitalized)
                    if recipe.cookCount > 0 {
                        Text("·").opacity(0.5)
                        Image(systemName: "flame")
                        Text("Cooked \(recipe.cookCount)×")
                    }
                }
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)

                if !recipe.variations.isEmpty {
                    Text("\(recipe.variations.count) variation\(recipe.variations.count == 1 ? "" : "s")")
                        .font(.miseMeta)
                        .foregroundStyle(Brand.muted.opacity(0.6))
                }
            }

            Spacer()

            if recipe.isFavorite || recipe.isAutoFavorite {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Brand.spiceRed)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title), \(recipe.formattedDuration), \(recipe.cuisine.rawValue)")
    }
}

// MARK: - Compact Card

struct RecipeCardCompact: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                let firstPhoto = recipe.photos.first
                    ?? recipe.cookingLog.sorted { $0.date > $1.date }.first?.photo
                if let photo = firstPhoto,
                   let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 130, height: 86)
                        .clipShape(.rect(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.clear)
                        .frame(width: 130, height: 86)
                        .glassEffect(.regular, in: .rect(cornerRadius: 10))
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "fork.knife")
                                    .font(.title3)
                                    .foregroundStyle(Brand.warmTan.opacity(0.7))
                                if recipe.cookCount > 0 {
                                    Text("\(recipe.cookCount)×")
                                        .font(.miseMeta)
                                        .foregroundStyle(Brand.muted)
                                }
                            }
                        }
                }
            }

            Text(recipe.title)
                .font(.system(size: 12, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Brand.cream)
                .lineLimit(2)

            Text(recipe.formattedDuration)
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)
        }
        .frame(width: 130)
        .padding(.bottom, 4)
    }
}

// MARK: - Recipe Filter Sheet

struct RecipeFilterSheet: View {
    @Binding var selectedCuisine: Cuisine?
    @Binding var selectedDifficulty: RecipeDifficulty?
    @Binding var maxTimeFilter: Int?
    @Binding var showFavoritesOnly: Bool
    @Binding var selectedMealType: MealType?
    @Binding var selectedDietaryRestrictions: Set<DietaryRestriction>
    @Binding var selectedTags: Set<String>
    let availableTags: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var tagChipSearch = ""

    private var sortedRestrictions: [DietaryRestriction] {
        DietaryRestriction.allCases.sorted {
            let aSelected = selectedDietaryRestrictions.contains($0)
            let bSelected = selectedDietaryRestrictions.contains($1)
            if aSelected != bSelected { return aSelected }
            return $0.rawValue < $1.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Favorites Only", isOn: $showFavoritesOnly)
                }

                Section("Meal Type") {
                    Picker("Meal Type", selection: $selectedMealType) {
                        Text("Any").tag(MealType?.none)
                        ForEach(MealType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(MealType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Cuisine") {
                    Picker("Cuisine", selection: $selectedCuisine) {
                        Text("All Cuisines").tag(Cuisine?.none)
                        ForEach(Cuisine.allCases, id: \.self) { cuisine in
                            Text(cuisine.rawValue.capitalized).tag(Cuisine?.some(cuisine))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Difficulty") {
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        Text("Any Difficulty").tag(RecipeDifficulty?.none)
                        ForEach(RecipeDifficulty.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(RecipeDifficulty?.some(level))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Max Total Time") {
                    Picker("Time", selection: $maxTimeFilter) {
                        Text("No Limit").tag(Int?.none)
                        Text("15 min").tag(Int?.some(15))
                        Text("30 min").tag(Int?.some(30))
                        Text("45 min").tag(Int?.some(45))
                        Text("60 min").tag(Int?.some(60))
                        Text("90 min").tag(Int?.some(90))
                    }
                    .pickerStyle(.menu)
                }

                if !availableTags.isEmpty {
                    Section("Tags") {
                        if availableTags.count > 10 {
                            TagChipGrid.SearchField(tagSearch: $tagChipSearch)
                        }
                        TagChipGrid(availableTags: availableTags, selectedTags: $selectedTags, tagSearch: $tagChipSearch)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                Section("Dietary Restrictions") {
                    DietaryChipGrid(
                        selectedRestrictions: $selectedDietaryRestrictions,
                        sortedRestrictions: sortedRestrictions
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section {
                    Button("Clear All Filters") {
                        selectedCuisine = nil
                        selectedDifficulty = nil
                        maxTimeFilter = nil
                        showFavoritesOnly = false
                        selectedMealType = nil
                        selectedDietaryRestrictions = []
                        selectedTags = []
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
