import SwiftUI

// MARK: - Recipe as Code Preview View

/// Full end-to-end Recipe-as-Code experience: edit definition, preview parsed
/// ingredients and outcomes, trigger AI step inference, and review generated recipe.
struct RecipeAsCodePreviewView: View {
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var codeText: String
    @State private var parsedDefinition: RecipeDefinition?
    @State private var inferredSteps: InferredRecipeSteps?
    @State private var parseError: String?
    @State private var isInferring = false
    @State private var inferError: String?

    init(initialCode: String = "") {
        _codeText = State(initialValue: initialCode.isEmpty ? Self.sampleRecipeCode : initialCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorSection
                    parsePreviewSection
                    inferredStepsSection
                    saveSection
                }
                .padding()
            }
            .navigationTitle("Recipe as Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Editor

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Definition")
                    .font(.headline)
                Spacer()
                Button("Parse") {
                    parseDefinition()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }

            TextEditor(text: $codeText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 250)
                .padding(8)
                .glassCard(cornerRadius: 8)

            if let error = parseError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Parse Preview

    @ViewBuilder
    private var parsePreviewSection: some View {
        if let def = parsedDefinition {
            VStack(alignment: .leading, spacing: 12) {
                Text("Parsed Recipe")
                    .font(.headline)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Title", value: def.title)
                        if let servings = def.servings {
                            LabeledContent("Servings", value: "\(servings)")
                        }
                        if let cuisine = def.cuisine {
                            LabeledContent("Cuisine", value: cuisine.capitalized)
                        }
                    }
                }

                // Ingredients
                GroupBox("Ingredients (\(def.ingredients.count))") {
                    ForEach(def.ingredients, id: \.name) { ing in
                        HStack {
                            Circle()
                                .fill(.tint)
                                .frame(width: 6, height: 6)
                            Text(ing.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(ing.amount)
                                .foregroundStyle(.secondary)
                            if let prep = ing.preparation {
                                Text("(\(prep))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .font(.subheadline)
                    }
                }

                // Outcomes
                GroupBox("Desired Outcomes (\(def.outcomes.count))") {
                    ForEach(def.outcomes, id: \.self) { outcome in
                        HStack(alignment: .top) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text(outcome)
                                .font(.subheadline)
                        }
                    }
                }

                // Equipment
                if let equipment = def.equipment, !equipment.isEmpty {
                    GroupBox("Equipment") {
                        ForEach(equipment, id: \.self) { item in
                            Label(item, systemImage: "wrench.and.screwdriver")
                                .font(.subheadline)
                        }
                    }
                }

                // Infer steps button
                Button {
                    Task { await inferSteps(from: def) }
                } label: {
                    HStack {
                        Spacer()
                        if isInferring {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Inferring steps with AI...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Infer Cooking Steps")
                        }
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.glass)
                .disabled(isInferring)

                if let error = inferError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Inferred Steps

    @ViewBuilder
    private var inferredStepsSection: some View {
        if let steps = inferredSteps {
            VStack(alignment: .leading, spacing: 12) {
                Text("Generated Recipe Steps")
                    .font(.headline)

                HStack(spacing: 16) {
                    Label("\(steps.estimatedPrepMinutes) min prep", systemImage: "scissors")
                    Label("\(steps.estimatedCookMinutes) min cook", systemImage: "flame")
                    Label(steps.difficulty.capitalized, systemImage: "chart.bar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(steps.steps, id: \.stepNumber) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.stepNumber)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.tint, in: .circle)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.instruction)
                                .font(.subheadline)

                            if step.durationSeconds > 0 {
                                Label(formatDuration(step.durationSeconds), systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            if !step.ingredientsUsed.isEmpty {
                                Text(step.ingredientsUsed.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Save

    @ViewBuilder
    private var saveSection: some View {
        if let def = parsedDefinition, inferredSteps != nil {
            Button {
                saveRecipe(definition: def)
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Recipe")
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.glass)
            .tint(.green)
        }
    }

    // MARK: - Actions

    private func parseDefinition() {
        parseError = nil
        inferredSteps = nil

        do {
            parsedDefinition = try RecipeDefinitionParser.parse(from: codeText)
        } catch {
            parseError = error.localizedDescription
        }
    }

    private func inferSteps(from definition: RecipeDefinition) async {
        isInferring = true
        inferError = nil

        do {
            let service = aiRouter.foundationModelService
            if await service.isAvailable {
                inferredSteps = try await service.inferSteps(from: definition)
            } else {
                inferError = "On-device AI not available. Cloud fallback will be used in production."
            }
        } catch {
            inferError = error.localizedDescription
        }

        isInferring = false
    }

    private func saveRecipe(definition: RecipeDefinition) {
        let cuisine = Cuisine.allCases.first {
            $0.rawValue.lowercased() == definition.cuisine?.lowercased()
        } ?? .other

        let ingredients = definition.ingredients.map { ing in
            Ingredient(
                name: ing.name,
                category: .other,
                amount: IngredientAmount(quantity: 1, unit: .piece),
                notes: ing.preparation
            )
        }

        let directions = (inferredSteps?.steps ?? []).map { step in
            RecipeDirection(
                stepNumber: step.stepNumber,
                instruction: step.instruction,
                timer: step.durationSeconds > 0 ? TimerStep(durationSeconds: step.durationSeconds, label: "Step \(step.stepNumber)") : nil
            )
        }

        let recipe = Recipe(
            title: definition.title,
            cuisine: cuisine,
            servings: definition.servings ?? 4,
            prepTimeMinutes: inferredSteps?.estimatedPrepMinutes ?? 15,
            cookTimeMinutes: inferredSteps?.estimatedCookMinutes ?? 30,
            ingredients: ingredients,
            directions: directions,
            sourceMarkdown: codeText
        )

        modelContext.insert(recipe)
        dismiss()
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 { return "\(minutes)m \(secs)s" }
        if minutes > 0 { return "\(minutes) min" }
        return "\(secs) sec"
    }

    // MARK: - Sample

    static let sampleRecipeCode = """
    title: "Pasta Aglio e Olio"
    servings: 4
    cuisine: italian

    ingredients:
      - spaghetti: 400g
      - garlic: 6 cloves, thinly sliced
      - olive oil: 0.5 cup
      - red pepper flakes: 1 tsp
      - fresh parsley: 0.25 cup, chopped
      - parmesan: to taste, grated
      - salt: to taste

    outcomes:
      - pasta is perfectly al dente
      - garlic is golden and fragrant, not burnt
      - oil is infused with chili heat
      - parsley is freshly mixed through
      - dish is glossy with emulsified pasta water and oil

    equipment:
      - large pot
      - large skillet
    """
}
