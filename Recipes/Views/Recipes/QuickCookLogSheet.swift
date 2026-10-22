import SwiftUI
import SwiftData

// MARK: - Quick Cook Log Sheet

/// Lightweight post-cook logging — just a star rating and a save.
/// "Add details" presents the full CookingLogEntryView for notes,
/// photos, substitutions, and times without creating a duplicate entry.
struct QuickCookLogSheet: View {
    let recipe: Recipe
    var logDate: Date = .now
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var pantryItems: [PantryItem]

    @State private var rating: Int = 0
    @State private var showingFullLog = false
    @State private var showingPantryCleanup = false
    @State private var consumedItemIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 36) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    Image(systemName: "frying.pan")
                        .font(.system(size: 48))
                        .foregroundStyle(Brand.spiceRed)
                        .accessibilityHidden(true)

                    Text("Cooked!")
                        .font(.title.weight(.bold))

                    Text(recipe.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Star rating
                VStack(spacing: 10) {
                    Text("How did it go?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                // Tap the same star again to clear
                                rating = rating == star ? 0 : star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundStyle(star <= rating ? Brand.warmTan : .secondary)
                            }
                            .buttonStyle(.plain)
                            .sensoryFeedback(.selection, trigger: rating)
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }

                    Text(rating == 0 ? "Tap to rate (optional)" : ratingLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .animation(.easeInOut(duration: 0.15), value: rating)
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        saveQuickLog()
                        // Only interrupt a quick log when something actually ran out.
                        if consumedItemIDs.isEmpty {
                            dismiss()
                        } else {
                            showingPantryCleanup = true
                        }
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.herbGreen)

                    // Opens full CookingLogEntryView; onDismiss closes this sheet too
                    Button {
                        showingFullLog = true
                    } label: {
                        Text("Add notes, photo or substitutions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // Full log dismisses this sheet when done — no duplicate entry created
        .sheet(isPresented: $showingFullLog, onDismiss: { dismiss() }) {
            CookingLogEntryView(recipe: recipe, logDate: logDate)
        }
        .sheet(isPresented: $showingPantryCleanup, onDismiss: { dismiss() }) {
            PostCookPantrySheet(
                recipe: recipe,
                pantryItems: Array(pantryItems),
                preselected: consumedItemIDs,
                quantitiesDeducted: true
            ) {}
        }
    }

    // MARK: - Helpers

    private var ratingLabel: String {
        switch rating {
        case 1: return "Needs work"
        case 2: return "It was okay"
        case 3: return "Pretty good"
        case 4: return "Really good"
        case 5: return "Absolutely loved it"
        default: return ""
        }
    }

    private func saveQuickLog() {
        let entry = CookingLogEntry(date: logDate, rating: rating > 0 ? rating : nil)
        modelContext.insert(entry)
        recipe.cookingLog.append(entry)
        profiles.first?.recordCook(ofRecipeWithDifficulty: recipe.difficulty)

        if profiles.first?.autoDeductPantry ?? true {
            let consumed = PantryDeductionService.deductAfterCooking(
                recipe: recipe,
                servingsCooked: recipe.servings,
                pantryItems: Array(pantryItems)
            )
            // Items that ran out are offered for removal, never deleted unasked.
            consumedItemIDs = Set(consumed.map(\.id))
        }
    }
}
