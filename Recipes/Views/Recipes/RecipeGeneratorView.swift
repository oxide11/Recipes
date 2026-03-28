import SwiftUI

// MARK: - AI Recipe Generator View

struct RecipeGeneratorView: View {
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var ingredientInput = ""
    @State private var selectedCuisine: Cuisine?
    @State private var maxTime: Int?
    @State private var dietaryRestrictions: Set<DietaryRestriction> = []
    @State private var isGenerating = false
    @State private var generatedText: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What ingredients do you have?") {
                    TextField("e.g., chicken, rice, garlic, soy sauce", text: $ingredientInput, axis: .vertical)
                        .lineLimit(3)
                }

                Section("Preferences") {
                    Picker("Cuisine", selection: $selectedCuisine) {
                        Text("Any").tag(Cuisine?.none)
                        ForEach(Cuisine.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(Cuisine?.some(c))
                        }
                    }

                    Picker("Max Time", selection: $maxTime) {
                        Text("No limit").tag(Int?.none)
                        Text("15 min").tag(Int?.some(15))
                        Text("30 min").tag(Int?.some(30))
                        Text("45 min").tag(Int?.some(45))
                        Text("60 min").tag(Int?.some(60))
                    }
                }

                Section("Dietary Restrictions") {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        Toggle(restriction.rawValue.capitalized, isOn: Binding(
                            get: { dietaryRestrictions.contains(restriction) },
                            set: { isOn in
                                if isOn { dietaryRestrictions.insert(restriction) }
                                else { dietaryRestrictions.remove(restriction) }
                            }
                        ))
                    }
                }

                Section {
                    Button {
                        Task { await generateRecipe() }
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Recipe")
                            }
                            Spacer()
                        }
                    }
                    .disabled(ingredientInput.isEmpty || isGenerating)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if let result = generatedText {
                    Section("Generated Recipe") {
                        Text(result)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("Recipe Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func generateRecipe() async {
        isGenerating = true
        errorMessage = nil
        generatedText = nil

        let ingredients = ingredientInput
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var prompt = "Generate a detailed recipe using these ingredients: \(ingredients.joined(separator: ", "))."
        if let cuisine = selectedCuisine {
            prompt += " Make it \(cuisine.rawValue) style."
        }
        if let time = maxTime {
            prompt += " It should be ready in \(time) minutes or less."
        }
        if !dietaryRestrictions.isEmpty {
            prompt += " Dietary needs: \(dietaryRestrictions.map(\.rawValue).joined(separator: ", "))."
        }
        prompt += " Include precise measurements, clear steps, and estimated nutrition per serving."

        do {
            let result = try await aiRouter.generateText(
                prompt: prompt,
                taskType: .recipeGeneration
            )
            generatedText = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
