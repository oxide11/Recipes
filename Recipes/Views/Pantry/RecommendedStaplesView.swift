import SwiftUI
import SwiftData

// MARK: - Recommended Staples View

/// Shows pantry staples the user should keep stocked, based on universal
/// essentials and personalized analysis of their recipe collection.
struct RecommendedStaplesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @State private var selectedTab = 0

    private var missingUniversal: [RecommendedStaplesService.Staple] {
        RecommendedStaplesService.missingStaples(pantryItems: pantryItems)
    }

    private var personalized: [RecommendedStaplesService.Staple] {
        RecommendedStaplesService.personalizedStaples(
            recipes: recipes,
            pantryItems: pantryItems
        )
    }

    var body: some View {
        List {
            Picker("View", selection: $selectedTab) {
                Text("Essentials").tag(0)
                Text("For You").tag(1)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if selectedTab == 0 {
                universalSection
            } else {
                personalizedSection
            }
        }
        .navigationTitle("Recommended Staples")
    }

    // MARK: - Universal

    private var universalSection: some View {
        Group {
            let essential = missingUniversal.filter { $0.frequency == .essential }
            let common = missingUniversal.filter { $0.frequency == .common }
            let recommended = missingUniversal.filter { $0.frequency == .recommended }

            if missingUniversal.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Fully Stocked!",
                        systemImage: "checkmark.seal.fill",
                        description: Text("You have all the essential pantry staples.")
                    )
                }
            }

            if !essential.isEmpty {
                stapleSection("Essential", items: essential, color: .red)
            }
            if !common.isEmpty {
                stapleSection("Common", items: common, color: .orange)
            }
            if !recommended.isEmpty {
                stapleSection("Nice to Have", items: recommended, color: .blue)
            }
        }
    }

    // MARK: - Personalized

    private var personalizedSection: some View {
        Group {
            if personalized.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Add More Recipes",
                        systemImage: "book.pages",
                        description: Text("We'll analyze your recipes to suggest ingredients you frequently use but don't have stocked.")
                    )
                }
            } else {
                Section {
                    Text("Based on your \(recipes.count) recipes, these ingredients come up often and aren't in your pantry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(personalized) { staple in
                    stapleRow(staple, color: frequencyColor(staple.frequency))
                }
            }
        }
    }

    // MARK: - Components

    private func stapleSection(_ title: String, items: [RecommendedStaplesService.Staple], color: Color) -> some View {
        Section(title) {
            ForEach(items) { staple in
                stapleRow(staple, color: color)
            }
        }
    }

    private func stapleRow(_ staple: RecommendedStaplesService.Staple, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(staple.name)
                    .fontWeight(.medium)
                Text(staple.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                addToPantry(staple)
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }

    private func addToPantry(_ staple: RecommendedStaplesService.Staple) {
        let item = PantryItem(
            name: staple.name,
            category: staple.category,
            quantity: 1,
            unit: .piece
        )
        modelContext.insert(item)
    }

    private func frequencyColor(_ freq: RecommendedStaplesService.StapleFrequency) -> Color {
        switch freq {
        case .essential:   return .red
        case .common:      return .orange
        case .recommended: return .blue
        }
    }
}
