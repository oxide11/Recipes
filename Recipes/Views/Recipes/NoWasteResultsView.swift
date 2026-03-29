import SwiftUI

// MARK: - No Waste Results View

/// Shows recipes matched against the user's pantry, with coverage percentages,
/// missing ingredient counts, and priority for expiring items.
struct NoWasteResultsView: View {
    let recipes: [Recipe]
    let pantryItems: [PantryItem]
    var expiringOnly: Bool = false
    var maxMinutes: Int? = nil

    private var matches: [NoWasteMatchingEngine.MatchResult] {
        if expiringOnly {
            return NoWasteMatchingEngine.recipesForExpiringItems(
                recipes: recipes,
                pantryItems: pantryItems
            )
        } else if let maxMinutes {
            return NoWasteMatchingEngine.lastMinuteRecipes(
                recipes: recipes,
                pantryItems: pantryItems,
                maxMinutes: maxMinutes
            )
        } else {
            return NoWasteMatchingEngine.matchRecipes(
                recipes: recipes,
                pantryItems: pantryItems
            )
        }
    }

    @State private var timeFilter: TimeFilter = .any
    @State private var showFullCoverageOnly = false

    enum TimeFilter: String, CaseIterable {
        case any = "Any Time"
        case fifteen = "15 min"
        case thirty = "30 min"
        case sixty = "60 min"

        var minutes: Int? {
            switch self {
            case .any: return nil
            case .fifteen: return 15
            case .thirty: return 30
            case .sixty: return 60
            }
        }
    }

    private var filteredMatches: [NoWasteMatchingEngine.MatchResult] {
        var results = matches

        if let maxTime = timeFilter.minutes {
            results = results.filter { $0.recipe.estimatedTotalMinutes <= maxTime }
        }

        if showFullCoverageOnly {
            results = results.filter { $0.missingIngredients.isEmpty }
        }

        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Picker("Time", selection: $timeFilter) {
                        ForEach(TimeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Have all ingredients", isOn: $showFullCoverageOnly)
                        .fixedSize()
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            if filteredMatches.isEmpty {
                ContentUnavailableView(
                    "No Matching Recipes",
                    systemImage: "magnifyingglass",
                    description: Text("Try adjusting filters or adding more items to your pantry.")
                )
            } else {
                List(filteredMatches) { match in
                    NavigationLink {
                        RecipeDetailView(recipe: match.recipe)
                    } label: {
                        NoWasteRecipeRow(match: match)
                    }
                }
            }
        }
        .navigationTitle(expiringOnly ? "Use It Up" : "What Can I Make?")
    }
}

// MARK: - No Waste Recipe Row

struct NoWasteRecipeRow: View {
    let match: NoWasteMatchingEngine.MatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.recipe.title)
                    .font(.headline)

                Spacer()

                // Coverage badge
                Text("\(Int(match.coveragePercent))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(coverageColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(coverageColor.opacity(0.1), in: .capsule)
            }

            HStack(spacing: 12) {
                Label(match.recipe.formattedDuration, systemImage: "clock")
                Label(match.recipe.cuisine.rawValue.capitalized, systemImage: "fork.knife")

                if !match.expiringIngredientsUsed.isEmpty {
                    Label("Uses \(match.expiringIngredientsUsed.count) expiring", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Missing ingredients
            if !match.missingIngredients.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "cart.badge.plus")
                        .font(.caption2)
                    Text("Need: \(match.missingIngredients.joined(separator: ", "))")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.red.opacity(0.8))
            }

            // Matched ingredients summary
            let matchedNames = match.matchedIngredients.prefix(5).map(\.recipeName)
            if !matchedNames.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.herbGreen)
                    Text("Have: \(matchedNames.joined(separator: ", "))")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var coverageColor: Color {
        switch match.coveragePercent {
        case 90...100: return Brand.herbGreen
        case 70..<90:  return Brand.warmTan
        case 50..<70:  return Brand.ingredientSeasoning
        default:       return Brand.spiceRed
        }
    }
}
