import SwiftUI
import SwiftData

// MARK: - Recipe Editor View

struct RecipeEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var summary = ""
    @State private var cuisine: Cuisine = .other
    @State private var difficulty: RecipeDifficulty = .intermediate
    @State private var servings = 4
    @State private var prepTime = 15
    @State private var cookTime = 30
    @State private var sourceMarkdown = ""
    @State private var showingRecipeAsCode = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Recipe Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(3)

                    Picker("Cuisine", selection: $cuisine) {
                        ForEach(Cuisine.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(RecipeDifficulty.allCases, id: \.self) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                }

                Section("Timing & Servings") {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...50)
                    Stepper("Prep: \(prepTime) min", value: $prepTime, in: 0...300, step: 5)
                    Stepper("Cook: \(cookTime) min", value: $cookTime, in: 0...600, step: 5)
                }

                Section("Recipe as Code") {
                    Button("Import from Recipe Definition") {
                        showingRecipeAsCode = true
                    }

                    if !sourceMarkdown.isEmpty {
                        Text("Source loaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingRecipeAsCode) {
                RecipeAsCodeEditorView(sourceText: $sourceMarkdown)
            }
        }
    }

    private func saveRecipe() {
        let recipe = Recipe(
            title: title,
            summary: summary.isEmpty ? nil : summary,
            cuisine: cuisine,
            difficulty: difficulty,
            servings: servings,
            prepTimeMinutes: prepTime,
            cookTimeMinutes: cookTime,
            sourceMarkdown: sourceMarkdown.isEmpty ? nil : sourceMarkdown
        )
        modelContext.insert(recipe)
        dismiss()
    }
}

// MARK: - Recipe as Code Editor

struct RecipeAsCodeEditorView: View {
    @Binding var sourceText: String
    @Environment(\.dismiss) private var dismiss

    @State private var editorText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Define your recipe declaratively. Specify ingredients and desired outcomes — the app will infer the steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $editorText)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(.quaternary, in: .rect(cornerRadius: 8))
                    .padding(.horizontal)
            }
            .navigationTitle("Recipe as Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        sourceText = editorText
                        dismiss()
                    }
                }
            }
        }
    }
}
