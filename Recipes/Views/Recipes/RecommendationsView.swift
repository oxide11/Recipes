import SwiftUI
import SwiftData

// MARK: - Recommendations View

/// Personalized recipe recommendations powered by cooking history analysis,
/// pantry state, seasonal awareness, and AI blind-spot detection.
struct RecommendationsView: View {
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var recommendations: [RecommendationAgent.Recommendation] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var loadFailed = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView("Analyzing your cooking history...")
                        .padding(.top, 40)
                } else if recommendations.isEmpty && hasLoaded {
                    if loadFailed {
                        ContentUnavailableView {
                            Label("Couldn't Load Suggestions", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text("Check your connection and pull down to try again.")
                        } actions: {
                            Button("Try Again") {
                                Task { await loadRecommendations() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if recipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes Yet",
                            systemImage: "book.closed",
                            description: Text("Add some recipes and start cooking to unlock personalised suggestions.")
                        )
                    } else {
                        ContentUnavailableView(
                            "No Recommendations Yet",
                            systemImage: "sparkles",
                            description: Text("Cook a few recipes and add items to your pantry to get personalised suggestions. Pull down to refresh.")
                        )
                    }
                } else {
                    // Group by category
                    ForEach(groupedRecommendations, id: \.0) { category, recs in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(categoryTitle(category), systemImage: categoryIcon(category))
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(recs) { rec in
                                RecommendationCard(recommendation: rec)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("For You")
        .toolbarBackground(.automatic, for: .navigationBar)
        .task {
            guard !hasLoaded else { return }
            await loadRecommendations()
        }
        .refreshable {
            await loadRecommendations()
        }
    }

    private var groupedRecommendations: [(RecommendationAgent.RecommendationCategory, [RecommendationAgent.Recommendation])] {
        let grouped = Dictionary(grouping: recommendations, by: \.category)
        let order: [RecommendationAgent.RecommendationCategory] = [
            .noWaste, .quickMeal, .tryAgain, .seasonal, .blindSpot, .newRecipe, .nutritional
        ]
        return order.compactMap { cat in
            guard let recs = grouped[cat], !recs.isEmpty else { return nil }
            return (cat, recs)
        }
    }

    private func loadRecommendations() async {
        isLoading = true
        loadFailed = false
        let agent = RecommendationAgent(aiRouter: aiRouter)
        let result = await agent.generateRecommendations(
            recipes: recipes,
            pantryItems: pantryItems,
            profile: profile
        )
        // If we have recipes but still got nothing, assume an AI failure
        if result.isEmpty && !recipes.isEmpty {
            loadFailed = true
        }
        recommendations = result
        isLoading = false
        hasLoaded = true
    }

    private func categoryTitle(_ cat: RecommendationAgent.RecommendationCategory) -> String {
        switch cat {
        case .tryAgain:    return "Cook Again"
        case .blindSpot:   return "Expand Your Horizons"
        case .seasonal:    return "Seasonal Picks"
        case .noWaste:     return "Use It Up"
        case .nutritional: return "Nutritional Goals"
        case .quickMeal:   return "Quick Meals"
        case .newRecipe:   return "New Ideas"
        }
    }

    private func categoryIcon(_ cat: RecommendationAgent.RecommendationCategory) -> String {
        switch cat {
        case .tryAgain:    return "arrow.counterclockwise"
        case .blindSpot:   return "binoculars"
        case .seasonal:    return "leaf"
        case .noWaste:     return "exclamationmark.triangle"
        case .nutritional: return "heart"
        case .quickMeal:   return "bolt"
        case .newRecipe:   return "sparkles"
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: RecommendationAgent.Recommendation
    @State private var showingGenerator = false

    private var cuisineMatch: Cuisine? {
        guard let suggestion = recommendation.cuisineSuggestion else { return nil }
        return Cuisine.allCases.first {
            $0.rawValue.lowercased() == suggestion.lowercased()
        }
    }

    /// For blind spots, auto-generate with a cuisine hint. For everything else, open the generator form.
    private var isBlindSpot: Bool { recommendation.category == .blindSpot }

    var body: some View {
        Button {
            showingGenerator = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: isBlindSpot ? "sparkles" : "chevron.right")
                        .font(isBlindSpot ? .subheadline : .caption)
                        .foregroundStyle(isBlindSpot ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let cuisine = recommendation.cuisineSuggestion {
                    Text(cuisine.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.1), in: .capsule)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingGenerator) {
            if isBlindSpot {
                QuickGenerateView(cuisineHint: recommendation.cuisineSuggestion ?? cuisineMatch?.rawValue)
            } else {
                RecipeGeneratorView(initialCuisine: cuisineMatch)
            }
        }
    }
}
