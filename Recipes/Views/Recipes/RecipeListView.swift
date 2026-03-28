import SwiftUI
import SwiftData

// MARK: - Recipe List View

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]

    @State private var searchText = ""
    @State private var selectedCuisine: Cuisine?
    @State private var selectedDifficulty: RecipeDifficulty?
    @State private var maxTimeFilter: Int?
    @State private var showFavoritesOnly = false
    @State private var showingAddRecipe = false
    @State private var showingRecipeGenerator = false
    @State private var showingImport = false
    @State private var showingRecipeAsCode = false
    @State private var showingFilters = false

    private var activeFilterCount: Int {
        var count = 0
        if selectedCuisine != nil { count += 1 }
        if selectedDifficulty != nil { count += 1 }
        if maxTimeFilter != nil { count += 1 }
        if showFavoritesOnly { count += 1 }
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
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if !recipes.isEmpty {
                    // Tags quick access
                    Section {
                        NavigationLink {
                            TagManagementView()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Tags & Collections")
                                        .fontWeight(.medium)
                                    Text("Organize recipes with custom tags")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "tag")
                                    .foregroundStyle(.teal)
                            }
                        }
                    }

                    // Recommendations teaser
                    Section {
                        NavigationLink {
                            RecommendationsView()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Recommended For You")
                                        .fontWeight(.medium)
                                    Text("Personalized suggestions based on your cooking history")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.purple)
                            }
                        }
                    }

                    // No Waste quick access
                    if !pantryItems.isEmpty {
                        noWasteTeaser
                    }

                    seasonalSection
                    favoritesSection
                }

                allRecipesSection
            }
            .navigationTitle("Recipes")
            .searchable(text: $searchText, prompt: "Search recipes...")
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
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingFilters = true
                    } label: {
                        Label("Filters", systemImage: activeFilterCount > 0
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .badge(activeFilterCount)
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
            .sheet(isPresented: $showingFilters) {
                RecipeFilterSheet(
                    selectedCuisine: $selectedCuisine,
                    selectedDifficulty: $selectedDifficulty,
                    maxTimeFilter: $maxTimeFilter,
                    showFavoritesOnly: $showFavoritesOnly
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var noWasteTeaser: some View {
        let matches = NoWasteMatchingEngine.matchRecipes(
            recipes: recipes,
            pantryItems: pantryItems,
            maxMissing: 2
        )
        let topMatches = Array(matches.prefix(3))

        if !topMatches.isEmpty {
            Section("Ready to Cook") {
                ForEach(topMatches) { match in
                    NavigationLink {
                        RecipeDetailView(recipe: match.recipe)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.recipe.title)
                                    .fontWeight(.medium)
                                HStack(spacing: 6) {
                                    Text("\(Int(match.coveragePercent))% covered")
                                        .foregroundStyle(match.missingIngredients.isEmpty ? .green : .orange)
                                    if !match.missingIngredients.isEmpty {
                                        Text("Need \(match.missingIngredients.count) more")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(match.recipe.estimatedTotalMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    NoWasteResultsView(recipes: recipes, pantryItems: pantryItems)
                } label: {
                    Text("See All Matches")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
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
            Section("In Season") {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(seasonal.prefix(8)) { recipe in
                            RecipeCardCompact(recipe: recipe)
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
            }
        }
    }

    @ViewBuilder
    private var favoritesSection: some View {
        let favorites = filteredRecipes.filter { $0.isFavorite || $0.isAutoFavorite }

        if !favorites.isEmpty {
            Section("Favorites") {
                ForEach(favorites.prefix(5)) { recipe in
                    NavigationLink(value: recipe) {
                        RecipeRow(recipe: recipe)
                    }
                }
            }
        }
    }

    private var allRecipesSection: some View {
        Section("All Recipes") {
            if filteredRecipes.isEmpty {
                ContentUnavailableView(
                    "No Recipes Yet",
                    systemImage: "book.pages",
                    description: Text("Add your first recipe to get started.")
                )
            } else {
                ForEach(filteredRecipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeRow(recipe: recipe)
                    }
                }
                .onDelete(perform: deleteRecipes)
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRecipes[index])
        }
    }
}

// MARK: - Recipe Row

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.title)
                    .font(.headline)

                Spacer()

                if recipe.isFavorite || recipe.isAutoFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            HStack(spacing: 8) {
                Label("\(recipe.estimatedTotalMinutes) min", systemImage: "clock")
                Label(recipe.cuisine.rawValue.capitalized, systemImage: "fork.knife")
                if recipe.cookCount > 0 {
                    Label("Cooked \(recipe.cookCount)x", systemImage: "flame")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !recipe.variations.isEmpty {
                Text("\(recipe.variations.count) variation\(recipe.variations.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title), \(recipe.estimatedTotalMinutes) minutes, \(recipe.cuisine.rawValue)")
    }
}

// MARK: - Compact Card

struct RecipeCardCompact: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .frame(width: 120, height: 80)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

            Text(recipe.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)

            Text("\(recipe.estimatedTotalMinutes) min")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
    }
}

// MARK: - Recipe Filter Sheet

struct RecipeFilterSheet: View {
    @Binding var selectedCuisine: Cuisine?
    @Binding var selectedDifficulty: RecipeDifficulty?
    @Binding var maxTimeFilter: Int?
    @Binding var showFavoritesOnly: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
                    .pickerStyle(.segmented)
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
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("Favorites Only", isOn: $showFavoritesOnly)
                }

                Section {
                    Button("Clear All Filters") {
                        selectedCuisine = nil
                        selectedDifficulty = nil
                        maxTimeFilter = nil
                        showFavoritesOnly = false
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.glass, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
