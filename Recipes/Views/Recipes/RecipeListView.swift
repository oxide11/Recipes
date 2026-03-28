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
    @State private var showingAddRecipe = false
    @State private var showingRecipeGenerator = false
    @State private var showingImport = false
    @State private var showingRecipeAsCode = false
    @State private var showingCuisineFilter = false

    private var filteredRecipes: [Recipe] {
        var result = recipes
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }
        if let cuisine = selectedCuisine {
            result = result.filter { $0.cuisine == cuisine }
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
                    .accessibilityLabel("Add recipe")
                }

                ToolbarItem(placement: .topBarLeading) {
                    cuisineFilterMenu
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
            .sheet(isPresented: $showingCuisineFilter) {
                CuisineFilterSheet(selectedCuisine: $selectedCuisine)
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
                Text("Ready to cook")
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
                    LazyHStack(spacing: 12) {
                        ForEach(seasonal.prefix(8)) { recipe in
                            RecipeCardCompact(recipe: recipe)
                        }
                    }
                    .padding(.horizontal)
                }
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
    private var favoritesSection: some View {
        let favorites = filteredRecipes.filter { $0.isFavorite || $0.isAutoFavorite }

        if !favorites.isEmpty {
            Section {
                ForEach(favorites.prefix(5)) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        RecipeRow(recipe: recipe)
                    }
                }
            } header: {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .foregroundStyle(Brand.spiceRed)
                    Text("Favorites")
                }
                .miseSectionHeader()
            }
        }
    }

    private var allRecipesSection: some View {
        Section {
            if filteredRecipes.isEmpty {
                ContentUnavailableView(
                    "No recipes yet",
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
        } header: {
            Text("All recipes")
                .miseSectionHeader()
        }
    }

    private var cuisineFilterMenu: some View {
        Button {
            showingCuisineFilter = true
        } label: {
            Label(
                selectedCuisine?.rawValue.capitalized ?? "Filter",
                systemImage: selectedCuisine != nil
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredRecipes[index])
        }
    }
}

// MARK: - Cuisine Filter Sheet

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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recipe.title)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(-0.2)
                    .foregroundStyle(Brand.cream)

                Spacer()

                if recipe.isFavorite || recipe.isAutoFavorite {
                    Image(systemName: "heart")
                        .foregroundStyle(Brand.spiceRed)
                        .font(.caption)
                }
            }

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
