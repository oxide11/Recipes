import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Cooking Log Entry View

struct CookingLogEntryView: View {
    let recipe: Recipe
    private var existingEntry: CookingLogEntry?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var logDate: Date
    @State private var rating = 3
    @State private var prepMinutes = ""
    @State private var cookMinutes = ""
    @State private var notes = ""
    @State private var substitutions: [String] = []
    @State private var newSubstitution = ""
    @State private var servingsCooked: Int
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?           // newly picked, not yet saved to disk
    @State private var existingPhotoFilename: String?  // filename of existing photo when editing
    @State private var showingPantryCleanup = false
    @State private var didSave = false

    private var isEditing: Bool { existingEntry != nil }

    private var actualTotalMinutes: Int? {
        let prep = Int(prepMinutes) ?? 0
        let cook = Int(cookMinutes) ?? 0
        let total = prep + cook
        return total > 0 ? total : nil
    }

    /// Create a new log entry, optionally pre-setting the date (e.g. from a meal plan slot).
    init(recipe: Recipe, logDate: Date = .now) {
        self.recipe = recipe
        self.existingEntry = nil
        _logDate = State(initialValue: logDate)
        _servingsCooked = State(initialValue: recipe.servings)
    }

    /// Edit an existing log entry — all fields are pre-populated.
    init(recipe: Recipe, entry: CookingLogEntry) {
        self.recipe = recipe
        self.existingEntry = entry
        _logDate = State(initialValue: entry.date)
        _rating = State(initialValue: entry.rating ?? 3)
        _prepMinutes = State(initialValue: entry.prepTimeMinutes.map(String.init) ?? "")
        _cookMinutes = State(initialValue: entry.cookTimeMinutes.map(String.init) ?? "")
        _notes = State(initialValue: entry.notes ?? "")
        _substitutions = State(initialValue: entry.substitutionsMade)
        _servingsCooked = State(initialValue: recipe.servings)
        _existingPhotoFilename = State(initialValue: entry.photo?.imageFilename)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rating") {
                    StarRatingView(rating: rating, font: .title2) { rating = $0 }
                        .sensoryFeedback(.selection, trigger: rating)
                }

                Section("Date Cooked") {
                    DatePicker("Date", selection: $logDate, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                }

                Section("Servings & Time") {
                    Stepper("Servings cooked: \(servingsCooked)", value: $servingsCooked, in: 1...50)
                    TextField("Prep time (minutes)", text: $prepMinutes)
                        .keyboardType(.numberPad)
                    TextField("Cook time (minutes)", text: $cookMinutes)
                        .keyboardType(.numberPad)
                }

                Section("Photo") {
                    PhotoPickerButton(
                        selection: $selectedPhoto,
                        hasPhoto: existingPhotoFilename != nil || photoData != nil
                    ) { uiImage in
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
            .navigationTitle(isEditing ? "Edit Log Entry" : "Log Cooking Session")
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
            .sensoryFeedback(.success, trigger: didSave)
            .sheet(isPresented: $showingPantryCleanup) {
                PostCookPantrySheet(recipe: recipe, pantryItems: Array(pantryItems)) {
                    dismiss()
                }
            }
        }
    }

    private func saveEntry() {
        let timeSaved: Int? = actualTotalMinutes.map { recipe.estimatedTotalMinutes - $0 }

        if let entry = existingEntry {
            // Update in place — no new entry, no pantry cleanup
            entry.date = logDate
            entry.rating = rating
            entry.prepTimeMinutes = Int(prepMinutes)
            entry.cookTimeMinutes = Int(cookMinutes)
            entry.notes = notes.isEmpty ? nil : notes
            entry.substitutionsMade = substitutions
            entry.timeSavedMinutes = timeSaved
            if let data = photoData, entry.photo == nil {
                let id = UUID()
                if let filename = try? PhotoStorageService.save(data, id: id) {
                    let photo = RecipePhoto(id: id, imageFilename: filename)
                    modelContext.insert(photo)
                    entry.photo = photo
                }
            }
            didSave = true
            dismiss()
        } else {
            // Create new entry
            var photo: RecipePhoto?
            if let data = photoData {
                let id = UUID()
                if let filename = try? PhotoStorageService.save(data, id: id) {
                    photo = RecipePhoto(id: id, imageFilename: filename)
                    modelContext.insert(photo!)
                }
            }

            let entry = CookingLogEntry(
                date: logDate,
                prepTimeMinutes: Int(prepMinutes),
                cookTimeMinutes: Int(cookMinutes),
                rating: rating,
                notes: notes.isEmpty ? nil : notes,
                substitutionsMade: substitutions,
                timeSavedMinutes: timeSaved
            )
            entry.photo = photo
            modelContext.insert(entry)
            recipe.cookingLog.append(entry)
            didSave = true

            // Pantry cleanup only on new entries
            let recipeIngredientNames = Set(recipe.ingredients.map { $0.name.lowercased() })
            let hasMatches = pantryItems.contains { recipeIngredientNames.contains($0.name.lowercased()) }
            if hasMatches {
                showingPantryCleanup = true
            } else {
                dismiss()
            }
        }
    }
}

// MARK: - Post-Cook Pantry Cleanup Sheet

struct PostCookPantrySheet: View {
    let recipe: Recipe
    let pantryItems: [PantryItem]
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Pantry items whose name matches a recipe ingredient
    private var matchedItems: [PantryItem] {
        let names = Set(recipe.ingredients.map { $0.name.lowercased() })
        return pantryItems.filter { names.contains($0.name.lowercased()) }
    }

    @State private var usedUp: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Group {
                if matchedItems.isEmpty {
                    ContentUnavailableView(
                        "No pantry matches",
                        systemImage: "refrigerator",
                        description: Text("None of the ingredients in this recipe were found in your pantry.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(matchedItems) { item in
                                Button {
                                    if usedUp.contains(item.id) {
                                        usedUp.remove(item.id)
                                    } else {
                                        usedUp.insert(item.id)
                                    }
                                } label: {
                                    HStack {
                                        Text(item.name)
                                            .foregroundStyle(usedUp.contains(item.id) ? .secondary : .primary)
                                            .strikethrough(usedUp.contains(item.id))
                                        Spacer()
                                        if usedUp.contains(item.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Brand.spiceRed)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Tap anything you used up")
                        } footer: {
                            Text("Selected items will be removed from your pantry.")
                        }
                    }
                }
            }
            .navigationTitle("Update Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        for item in matchedItems where usedUp.contains(item.id) {
                            modelContext.delete(item)
                        }
                        dismiss()
                        onDone()
                    }
                }
            }
        }
    }
}
