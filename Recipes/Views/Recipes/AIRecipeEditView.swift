import SwiftUI
import SwiftData

// MARK: - AI Recipe Edit View

/// A sheet that lets the user describe a change (or pick a quick suggestion) and
/// applies it to the recipe via AI.  Shows a diff preview before committing.
struct AIRecipeEditView: View {
    let recipe: Recipe
    /// Called when the user taps "Apply Changes" — passes the AI result back.
    let onApply: (RecipeIngestionResult) -> Void

    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.dismiss) private var dismiss

    @State private var instruction = ""
    @State private var isGenerating = false
    @State private var result: RecipeIngestionResult?
    @State private var errorMessage: String?
    @State private var service: RecipeIngestionService?
    @FocusState private var fieldFocused: Bool

    // MARK: - Suggestions

    private let suggestions: [Suggestion] = [
        .init(label: "Maple syrup for sugar",  icon: "leaf",              text: "Replace all sugar with maple syrup, adjusting amounts appropriately"),
        .init(label: "Make it gluten-free",    icon: "allergens",         text: "Make this recipe gluten-free, substituting any wheat-based ingredients"),
        .init(label: "Make it dairy-free",     icon: "cup.and.saucer",    text: "Replace all dairy ingredients with dairy-free alternatives"),
        .init(label: "Make it vegan",          icon: "hare",              text: "Make this recipe fully vegan, replacing meat, dairy, and eggs"),
        .init(label: "Healthier version",      icon: "heart",             text: "Make this recipe healthier by reducing fat, sugar, and calories where possible"),
        .init(label: "Cut sugar in half",      icon: "scissors",          text: "Reduce all added sugar quantities by half"),
        .init(label: "Double the recipe",      icon: "arrow.up.left.and.arrow.down.right", text: "Double all ingredient quantities for twice as many servings"),
        .init(label: "Halve the recipe",       icon: "arrow.down.right.and.arrow.up.left", text: "Halve all ingredient quantities for half as many servings"),
        .init(label: "Add more protein",       icon: "dumbbell",          text: "Increase protein content by adding or increasing high-protein ingredients"),
        .init(label: "Lower calorie",          icon: "flame",             text: "Reduce calories where possible without sacrificing flavour"),
    ]

    private struct Suggestion: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let text: String
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                suggestionsSection
                instructionSection

                if result == nil {
                    generateSection
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                if let result {
                    diffSection(result)
                    applySection
                }
            }
            .navigationTitle("AI Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { fieldFocused = false }
                }
            }
            .onAppear {
                service = RecipeIngestionService(aiRouter: aiRouter)
            }
        }
    }

    // MARK: - Sections

    private var suggestionsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions) { suggestion in
                        let isSelected = instruction == suggestion.text
                        Button {
                            instruction = suggestion.text
                            fieldFocused = false
                        } label: {
                            Label(suggestion.label, systemImage: suggestion.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(.tint.opacity(0.18))
                                        : AnyShapeStyle(.fill.tertiary),
                                    in: .capsule
                                )
                                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                .overlay(Capsule().strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Quick Edits")
        } footer: {
            Text("Tap a suggestion or describe your own change below.")
        }
    }

    private var instructionSection: some View {
        Section("Your Request") {
            TextField(
                "e.g. Use oat milk instead of regular milk",
                text: $instruction,
                axis: .vertical
            )
            .lineLimit(2...5)
            .focused($fieldFocused)
            .onChange(of: instruction) {
                // Clear previous result when user edits the prompt
                if result != nil { result = nil; errorMessage = nil }
            }
        }
    }

    private var generateSection: some View {
        Section {
            Button {
                Task { await generate() }
            } label: {
                HStack {
                    Spacer()
                    if isGenerating {
                        ProgressView().padding(.trailing, 8)
                        Text("Updating recipe…")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Apply with AI")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(instruction.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
        }
    }

    private var applySection: some View {
        Section {
            Button {
                if let result { onApply(result); dismiss() }
            } label: {
                HStack {
                    Spacer()
                    Text("Apply Changes")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .tint(.green)

            Button("Try Again") {
                result = nil
                errorMessage = nil
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Diff Preview

    @ViewBuilder
    private func diffSection(_ result: RecipeIngestionResult) -> some View {
        let changes = ingredientDiff(old: recipe.ingredients, new: result.ingredients)
        let changed = changes.filter { $0.kind != .unchanged }
        let titleChanged = recipe.title.lowercased() != result.title.lowercased()
        let newTitle = result.title
        let oldSteps = recipe.directions.count
        let newSteps = result.directions.count

        Section {
            if titleChanged {
                changeRow(icon: "pencil.circle.fill", color: .orange,
                          title: "Title updated", detail: newTitle)
            }

            if changed.isEmpty && !titleChanged && oldSteps == newSteps {
                Label("Directions may be updated; ingredients unchanged.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(changed) { change in
                    changeRow(icon: change.kind.icon, color: change.kind.color,
                              title: change.name, detail: change.detail)
                }
            }

            if oldSteps != newSteps {
                changeRow(icon: "list.number", color: .orange,
                          title: "Steps changed", detail: "\(oldSteps) → \(newSteps) steps")
            }
        } header: {
            Text("Preview of Changes")
        } footer: {
            Text("Review the changes above before applying them to your recipe.")
        }
    }

    @ViewBuilder
    private func changeRow(icon: String, color: Color, title: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Diff Logic

    private struct IngredientChange: Identifiable {
        let id = UUID()
        enum Kind {
            case added, removed, modified, unchanged
            var icon: String {
                switch self {
                case .added:     return "plus.circle.fill"
                case .removed:   return "minus.circle.fill"
                case .modified:  return "arrow.triangle.2.circlepath.circle.fill"
                case .unchanged: return "circle"
                }
            }
            var color: Color {
                switch self {
                case .added:     return .green
                case .removed:   return .red
                case .modified:  return .orange
                case .unchanged: return .secondary
                }
            }
        }
        let kind: Kind
        let name: String
        let detail: String?
    }

    private func ingredientDiff(
        old: [Ingredient],
        new: [RecipeIngestionResult.ParsedIngredient]
    ) -> [IngredientChange] {
        var result: [IngredientChange] = []
        let oldMap = Dictionary(grouping: old, by: { $0.name.lowercased() })
            .compactMapValues(\.first)
        let newMap = Dictionary(grouping: new, by: { $0.name.lowercased() })
            .compactMapValues(\.first)

        for ing in old {
            let key = ing.name.lowercased()
            if let newIng = newMap[key] {
                let oldAmt = ing.amount.displayString
                if newIng.amount.trimmingCharacters(in: .whitespaces) != oldAmt {
                    result.append(.init(kind: .modified, name: ing.name,
                                        detail: "\(oldAmt) → \(newIng.amount)"))
                } else {
                    result.append(.init(kind: .unchanged, name: ing.name, detail: nil))
                }
            } else {
                result.append(.init(kind: .removed, name: ing.name, detail: nil))
            }
        }

        for newIng in new where oldMap[newIng.name.lowercased()] == nil {
            result.append(.init(kind: .added, name: newIng.name, detail: newIng.amount))
        }

        return result
    }

    // MARK: - Generate

    private func generate() async {
        guard let service else { return }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        do {
            result = try await service.editRecipe(recipe, instruction: instruction)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
