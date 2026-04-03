import SwiftUI

/// A sheet that lets the user describe a natural-language edit to apply to a recipe via AI.
struct AIRecipeEditView: View {
    let recipe: Recipe
    var onApply: (RecipeIngestionResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var instruction = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(recipe.title)
                        .font(.headline)
                } header: {
                    Text("Recipe")
                }

                Section {
                    TextField("e.g., make it gluten-free", text: $instruction, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("What would you like to change?")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("AI Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        Task { await applyEdit() }
                    }
                    .disabled(instruction.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Applying changes…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func applyEdit() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            let service = RecipeIngestionService(aiRouter: aiRouter)
            let result = try await service.editRecipe(recipe, instruction: instruction)
            onApply(result)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
