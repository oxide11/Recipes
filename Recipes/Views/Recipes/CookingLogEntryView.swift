import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Cooking Log Entry View

struct CookingLogEntryView: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var rating = 3
    @State private var prepMinutes = ""
    @State private var cookMinutes = ""
    @State private var notes = ""
    @State private var substitutions: [String] = []
    @State private var newSubstitution = ""
    @State private var deductFromPantry = true
    @State private var servingsCooked: Int
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var deductedItems: [PantryItem] = []
    @State private var showingDeductionResult = false
    @State private var didSave = false

    private var actualTotalMinutes: Int? {
        let prep = Int(prepMinutes) ?? 0
        let cook = Int(cookMinutes) ?? 0
        let total = prep + cook
        return total > 0 ? total : nil
    }

    init(recipe: Recipe) {
        self.recipe = recipe
        _servingsCooked = State(initialValue: recipe.servings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    StarRatingView(rating: rating, font: .title2) { rating = $0 }
                        .sensoryFeedback(.selection, trigger: rating)
                }

                Section("Servings & Time") {
                    Stepper("Servings cooked: \(servingsCooked)", value: $servingsCooked, in: 1...50)
                    TextField("Prep time (minutes)", text: $prepMinutes)
                        .keyboardType(.numberPad)
                    TextField("Cook time (minutes)", text: $cookMinutes)
                        .keyboardType(.numberPad)
                }

                Section {
                    Toggle("Deduct ingredients from pantry", isOn: $deductFromPantry)
                } header: {
                    Text("Pantry")
                } footer: {
                    Text("Automatically reduces pantry quantities for ingredients used in this recipe.")
                }

                Section("Photo") {
                    PhotoPickerButton(selection: $selectedPhoto, hasPhoto: photoData != nil) { uiImage in
                        photoData = uiImage.jpegData(compressionQuality: 0.8)
                    }
                }

                Section("Substitutions Made") {
                    ForEach(substitutions, id: \.self) { sub in
                        Text(sub)
                    }
                    HStack {
                        TextField("e.g., used oat milk instead of dairy", text: $newSubstitution)
                        Button("Add") {
                            guard !newSubstitution.isEmpty else { return }
                            substitutions.append(newSubstitution)
                            newSubstitution = ""
                        }
                    }
                }

                // Time comparison
                if let actualTotal = actualTotalMinutes, actualTotal > 0 {
                    Section("Time Comparison") {
                        let estimated = recipe.estimatedTotalMinutes
                        let diff = estimated - actualTotal
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Estimated")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(estimated) min")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Actual")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(actualTotal) min")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(diff > 0 ? "Saved" : diff < 0 ? "Over" : "On time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(abs(diff)) min")
                                    .fontWeight(.bold)
                                    .foregroundStyle(diff > 0 ? Brand.herbGreen : diff < 0 ? Brand.spiceRed : Brand.muted)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("How did it turn out?", text: $notes, axis: .vertical)
                        .lineLimit(4)
                }
            }
            .navigationTitle("Log Cooking Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                }
            }
            .task(id: selectedPhoto) {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
            .onAppear {
                if let profile = profiles.first {
                    deductFromPantry = profile.autoDeductPantry
                }
            }
            .sensoryFeedback(.success, trigger: didSave)
            .alert("Pantry Updated", isPresented: $showingDeductionResult) {
                Button("OK") { dismiss() }
            } message: {
                if deductedItems.isEmpty {
                    Text("Ingredients deducted from your pantry.")
                } else {
                    Text("\(deductedItems.count) item\(deductedItems.count == 1 ? "" : "s") fully used up and can be restocked.")
                }
            }
        }
    }

    private func saveEntry() {
        // Create photo if attached
        var photo: RecipePhoto?
        if let data = photoData {
            photo = RecipePhoto(imageData: data)
        }

        // Compute time saved vs recipe estimate
        let timeSaved: Int?
        if let actual = actualTotalMinutes {
            timeSaved = recipe.estimatedTotalMinutes - actual
        } else {
            timeSaved = nil
        }

        let entry = CookingLogEntry(
            prepTimeMinutes: Int(prepMinutes),
            cookTimeMinutes: Int(cookMinutes),
            rating: rating,
            notes: notes.isEmpty ? nil : notes,
            substitutionsMade: substitutions,
            timeSavedMinutes: timeSaved
        )
        entry.photo = photo
        recipe.cookingLog.append(entry)
        didSave = true

        // Deduct from pantry
        if deductFromPantry {
            deductedItems = PantryDeductionService.deductAfterCooking(
                recipe: recipe,
                servingsCooked: servingsCooked,
                pantryItems: pantryItems
            )
            showingDeductionResult = true
        } else {
            dismiss()
        }
    }
}
