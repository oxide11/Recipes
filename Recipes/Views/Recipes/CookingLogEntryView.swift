import SwiftUI

// MARK: - Cooking Log Entry View

struct CookingLogEntryView: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var rating = 3
    @State private var prepMinutes = ""
    @State private var cookMinutes = ""
    @State private var notes = ""
    @State private var substitutions: [String] = []
    @State private var newSubstitution = ""

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
                        }
                    }
                }

                Section("Time") {
                    TextField("Prep time (minutes)", text: $prepMinutes)
                        .keyboardType(.numberPad)
                    TextField("Cook time (minutes)", text: $cookMinutes)
                        .keyboardType(.numberPad)
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
        }
    }

    private func saveEntry() {
        let entry = CookingLogEntry(
            prepTimeMinutes: Int(prepMinutes),
            cookTimeMinutes: Int(cookMinutes),
            rating: rating,
            notes: notes.isEmpty ? nil : notes,
            substitutionsMade: substitutions
        )
        recipe.cookingLog.append(entry)
        dismiss()
    }
}
