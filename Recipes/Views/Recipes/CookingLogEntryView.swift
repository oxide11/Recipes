import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Cooking Log Entry View

struct CookingLogEntryView: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]

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

    init(recipe: Recipe) {
        self.recipe = recipe
        _servingsCooked = State(initialValue: recipe.servings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                            }
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }
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
                    let hasPhoto = photoData != nil
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if hasPhoto {
                            Label("Photo attached", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Add a photo", systemImage: "camera")
                        }
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

        let entry = CookingLogEntry(
            prepTimeMinutes: Int(prepMinutes),
            cookTimeMinutes: Int(cookMinutes),
            rating: rating,
            notes: notes.isEmpty ? nil : notes,
            substitutionsMade: substitutions
        )
        entry.photo = photo
        recipe.cookingLog.append(entry)

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
