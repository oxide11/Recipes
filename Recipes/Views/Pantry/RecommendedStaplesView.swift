import SwiftUI
import SwiftData

// MARK: - Recommended Staples View

/// Shows pantry staples the user should keep stocked, based on universal
/// essentials and personalized analysis of their recipe collection.
struct RecommendedStaplesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query(sort: \GroceryList.dateCreated, order: .reverse) private var groceryLists: [GroceryList]
    @Query private var profiles: [UserProfile]
    @State private var addedStaples: Set<String> = []

    @State private var selectedTab = 0

    private var dietaryRestrictions: Set<DietaryRestriction> {
        Set(profiles.first?.dietaryRestrictions ?? [])
    }

    private var missingUniversal: [RecommendedStaplesService.Staple] {
        RecommendedStaplesService.missingStaples(
            pantryItems: pantryItems,
            dietaryRestrictions: dietaryRestrictions
        )
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
                addToShoppingList(staple)
            } label: {
                if addedStaples.contains(staple.name) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.herbGreen)
                } else {
                    Image(systemName: "cart.badge.plus")
                        .foregroundStyle(Brand.warmTan)
                }
            }
            .disabled(addedStaples.contains(staple.name))
        }
    }

    private func addToShoppingList(_ staple: RecommendedStaplesService.Staple) {
        // Find or create an active grocery list
        let list: GroceryList
        if let existing = groceryLists.first {
            list = existing
        } else {
            list = GroceryList(name: "Shopping List")
            modelContext.insert(list)
        }

        // Avoid duplicates already on the list
        guard !list.items.contains(where: { $0.name.lowercased() == staple.name.lowercased() }) else {
            addedStaples.insert(staple.name)
            return
        }

        let item = GroceryItem(
            name: staple.name,
            quantity: 1,
            unit: .piece,
            storeSection: staple.category.storeSection,
            isStaple: true
        )
        item.notes = staple.reason
        list.items.append(item)
        modelContext.insert(item)
        addedStaples.insert(staple.name)
    }

    private func frequencyColor(_ freq: RecommendedStaplesService.StapleFrequency) -> Color {
        switch freq {
        case .essential:   return .red
        case .common:      return .orange
        case .recommended: return .blue
        }
    }
}
