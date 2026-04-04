import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AI Recipe Generator View

struct RecipeGeneratorView: View {
    var initialCuisine: Cuisine? = nil

    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    enum GeneratorMode: String, CaseIterable {
        case photo = "From Photo"
        case pantry = "From Pantry"
        case describe = "Describe It"

        var icon: String {
            switch self {
            case .photo: return "camera.viewfinder"
            case .pantry: return "refrigerator"
            case .describe: return "text.bubble"
            }
        }
    }

    @State private var mode: GeneratorMode = .photo
    @State private var selectedCuisine: Cuisine?
    @State private var selectedMealType: MealType?
    @State private var maxTime: Int?
    @State private var dietaryRestrictions: Set<DietaryRestriction> = []
    @State private var hasLoadedProfile = false
    @State private var isGenerating = false
    @State private var generatedResult: RecipeIngestionResult?
    @State private var showingResult = false
    @State private var streamingText = ""
    @State private var errorMessage: String?
    @State private var showingDietaryRestrictions = false
    @State private var descriptionRecognizer = SpeechRecognizer()

    // Photo mode
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Describe mode
    @State private var descriptionInput = ""

    // Optional pre-fill (e.g. from seasonal ingredient tap)
    var initialIngredient: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                // Mode selector
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(GeneratorMode.allCases, id: \.self) { m in
                            Label(m.rawValue, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) {
                        generatedResult = nil
                        errorMessage = nil
                    }
                }

                // Mode-specific input
                switch mode {
                case .photo:
                    photoSection
                case .pantry:
                    pantrySection
                case .describe:
                    describeSection
                }

                // Shared preferences
                Section("Preferences") {
                    if mode == .describe {
                        Picker("Meal Type", selection: $selectedMealType) {
                            Text("Any").tag(MealType?.none)
                            ForEach(MealType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(MealType?.some(type))
                            }
                        }
                    }

                    if mode != .photo {
                        Picker("Cuisine", selection: $selectedCuisine) {
                            Text("Any").tag(Cuisine?.none)
                            ForEach(Cuisine.allCases, id: \.self) { c in
                                Text(c.rawValue.capitalized).tag(Cuisine?.some(c))
                            }
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

                Section {
                    DisclosureGroup(isExpanded: $showingDietaryRestrictions) {
                        ForEach(sortedDietaryRestrictions, id: \.self) { restriction in
                            Toggle(restriction.displayName, isOn: Binding(
                                get: { dietaryRestrictions.contains(restriction) },
                                set: { isOn in
                                    if isOn { dietaryRestrictions.insert(restriction) }
                                    else { dietaryRestrictions.remove(restriction) }
                                }
                            ))
                        }
                    } label: {
                        HStack {
                            Text("Dietary Restrictions")
                            Spacer()
                            if !dietaryRestrictions.isEmpty {
                                Text("\(dietaryRestrictions.count) selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        Task { await generate() }
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
                    .disabled(isGenerateDisabled || isGenerating)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
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
            .sheet(isPresented: $showingResult) {
                if isGenerating {
                    NavigationStack {
                        StreamingRecipePreview(json: streamingText)
                            .navigationTitle("Generating…")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { showingResult = false }
                                }
                            }
                    }
                } else if let result = generatedResult {
                    GeneratedRecipePreviewSheet(result: result) {
                        showingResult = false
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let ingredient = initialIngredient {
                    mode = .describe
                    descriptionInput = "Generate a recipe that features \(ingredient.lowercased()) as a key ingredient."
                }
                if let cuisine = initialCuisine {
                    selectedCuisine = cuisine
                    mode = .describe
                }
                guard !hasLoadedProfile, let profile else { return }
                dietaryRestrictions = Set(profile.dietaryRestrictions)
                hasLoadedProfile = true
            }
            .onChange(of: selectedPhotoItem) {
                Task { await loadSelectedPhoto() }
            }
            .onChange(of: descriptionRecognizer.isListening) { _, isListening in
                guard !isListening else { return }
                let text = descriptionRecognizer.transcript.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                descriptionInput = descriptionInput.isEmpty ? text : descriptionInput + " " + text
            }
        }
    }

    // MARK: - Mode Sections

    @ViewBuilder
    private var photoSection: some View {
        Section {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(.rect(cornerRadius: 10))
                    .frame(maxWidth: .infinity)
            }
            PhotoPickerButton(selection: $selectedPhotoItem, hasPhoto: selectedImage != nil) { uiImage in
                selectedImage = uiImage
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Text("Pick a photo of a dish and the AI will identify it and generate a recipe to recreate it at home.")
        }
    }

    @ViewBuilder
    private var pantrySection: some View {
        Section {
            if pantryItems.isEmpty {
                Text("No pantry items yet. Add some ingredients to your pantry first.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                Text("\(pantryItems.count) pantry items will be used to suggest a recipe.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                let names = pantryItems.prefix(8).map(\.name).joined(separator: ", ")
                let overflow = pantryItems.count > 8 ? " +\(pantryItems.count - 8) more" : ""
                Text(names + overflow)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        } footer: {
            Text("The AI will suggest a recipe you can make with what you already have.")
        }
    }

    @ViewBuilder
    private var describeSection: some View {
        Section("What are you looking for?") {
            TextField("e.g., a cozy Italian dinner, quick weeknight pasta, something with chicken...", text: $descriptionInput, axis: .vertical)
                .lineLimit(3)

            if descriptionRecognizer.isListening {
                HStack(spacing: 10) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(Brand.herbGreen)
                        .symbolEffect(.pulse)
                    Text(descriptionRecognizer.transcript.isEmpty ? "Listening…" : descriptionRecognizer.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Done") { descriptionRecognizer.stop() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                Button {
                    Task { await descriptionRecognizer.start() }
                } label: {
                    Label("Speak your request", systemImage: "mic")
                        .font(.subheadline)
                        .foregroundStyle(Brand.herbGreen)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Generate

    private var sortedDietaryRestrictions: [DietaryRestriction] {
        DietaryRestriction.allCases.sorted {
            let aSelected = dietaryRestrictions.contains($0)
            let bSelected = dietaryRestrictions.contains($1)
            if aSelected != bSelected { return aSelected }
            return $0.rawValue < $1.rawValue
        }
    }

    private var isGenerateDisabled: Bool {
        switch mode {
        case .photo: return selectedImage == nil
        case .pantry: return pantryItems.isEmpty
        case .describe: return descriptionInput.isEmpty
        }
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        generatedResult = nil
        streamingText = ""
        showingResult = true
        defer { isGenerating = false }

        do {
            let text: String
            switch mode {
            case .photo:    text = try await generateFromPhoto()
            case .pantry:   text = try await generateFromPantry()
            case .describe: text = try await generateFromDescription()
            }
            let service = RecipeIngestionService(aiRouter: aiRouter)
            do {
                generatedResult = try await service.ingestFromTextStreaming(text, isGeneration: true) { chunk in
                    streamingText += chunk
                }
            } catch {
                showingResult = false
                errorMessage = "Couldn't parse the recipe. Try generating again."
            }
        } catch {
            showingResult = false
            errorMessage = error.localizedDescription
        }
    }

    private func generateFromPhoto() async throws -> String {
        guard let image = selectedImage,
              let jpegData = RecipeIngestionService.compressedForAI(image) else {
            throw AIServiceError.emptyResponse
        }
        let base64 = jpegData.base64EncodedString()
        var prompt = "This is a photo of a dish. Identify the dish and generate a complete recipe to recreate it at home. Include the dish name, all ingredients with precise measurements, and clear step-by-step cooking instructions."
        prompt += preferencesSuffix
        return try await aiRouter.analyzeImage(imageBase64: base64, prompt: prompt)
    }

    private func generateFromPantry() async throws -> String {
        let names = pantryItems.map(\.name).joined(separator: ", ")
        var prompt = "Generate a recipe using some or all of these ingredients I have in my pantry: \(names)."
        prompt += preferencesSuffix
        prompt += " Include precise measurements, clear steps, and estimated nutrition per serving."
        return try await aiRouter.generateText(prompt: prompt, taskType: .recipeGeneration)
    }

    private func generateFromDescription() async throws -> String {
        var prompt = "Generate a detailed recipe for: \(descriptionInput)."
        prompt += preferencesSuffix
        prompt += " Include precise measurements, clear steps, and estimated nutrition per serving."
        return try await aiRouter.generateText(prompt: prompt, taskType: .recipeGeneration)
    }

    private var preferencesSuffix: String {
        var suffix = ""
        if let mealType = selectedMealType { suffix += " This is for \(mealType.displayName.lowercased())." }
        if let cuisine = selectedCuisine { suffix += " Make it \(cuisine.rawValue) style." }
        if let time = maxTime { suffix += " Ready in \(time) minutes or less." }
        if !dietaryRestrictions.isEmpty {
            suffix += " Dietary needs: \(dietaryRestrictions.map(\.displayName).joined(separator: ", "))."
        }
        suffix += skillConstraint(for: profile?.skillLevel ?? .intermediate)
        suffix += ingredientDeduplicationInstruction
        return suffix
    }

    private func skillConstraint(for skill: RecipeDifficulty) -> String {
        recipeSkillConstraint(for: skill)
    }

    private var ingredientDeduplicationInstruction: String {
        " Important: if an ingredient is used in different amounts at different stages, list it ONCE in the ingredients list with the total amount needed. Mention the split in the directions (e.g. 'divide the oil: use 2 tbsp now and reserve 1 tbsp for finishing'). Treat these as the same ingredient and use only one name: olive oil / extra-virgin olive oil / EVOO; salt / kosher salt / sea salt / table salt; butter / unsalted butter; onion / onions; flour / all-purpose flour."
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }

}

// MARK: - Quick Generate View (Dashboard shortcut)

/// Auto-generates a recipe on appear — no form, just a spinner then a formatted result card.
/// Pass `quickMealMode: true` to bias generation toward meals ready in ≤ 30 minutes.
struct QuickGenerateView: View {
    var quickMealMode: Bool = false
    /// When set, constrains generation to a specific meal type (breakfast, lunch, dinner, etc.).
    var mealType: MealType? = nil
    /// When set, auto-generates a recipe for this specific cuisine (used by "Expand Your Horizons").
    var cuisineHint: String? = nil
    /// When set, overrides the generated description entirely (used for dish recreations, etc.).
    var initialDescription: String? = nil

    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query(sort: \Recipe.title) private var existingRecipes: [Recipe]
    @Query private var profiles: [UserProfile]

    @State private var isGenerating = true
    @State private var isSaving = false
    @State private var generatedResult: RecipeIngestionResult?
    @State private var errorMessage: String?
    @State private var streamingText = ""

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    StreamingRecipePreview(json: streamingText, cuisineHint: cuisineHint, quickMealMode: quickMealMode, pantryIsEmpty: pantryItems.count < 10)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Try Again") { Task { await generate() } }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = generatedResult {
                    RecipeIngestionResultCard(result: result)
                }
            }
            .navigationTitle(cuisineHint.map { "\($0.capitalized) Recipe" } ?? (quickMealMode ? "Quick Meal" : "Quick Generate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
                if let result = generatedResult {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button("Save") { Task { await save(result) } }
                        }
                    }
                }
            }
        }
        .task { await generate() }
    }


    // MARK: - Generation

    private func generate() async {
        isGenerating = true
        generatedResult = nil
        errorMessage = nil
        defer { isGenerating = false }

        let service = RecipeIngestionService(aiRouter: aiRouter)
        let profile = profiles.first

        var description: String
        if let override = initialDescription {
            description = override
        } else if let cuisine = cuisineHint {
            // Cuisine-specific auto-generate: pick a well-known dish from that cuisine
            let staples = pantryItems.filter(\.isStaple).map(\.name)
            var parts: [String] = ["Surprise me with a classic, delicious \(cuisine) recipe — something iconic and worth trying for the first time."]
            if !staples.isEmpty { parts.append("I always have the basics: \(staples.joined(separator: ", ")).") }
            parts.append("Keep it simple and approachable — 10 ingredients or fewer. Shopping for other ingredients is fine.")
            description = parts.joined(separator: " ")
        } else if quickMealMode {
            // Quick meal: use pantry + staples — no shopping trip needed
            let staples = pantryItems.filter(\.isStaple).map(\.name)
            let onHand  = pantryItems.filter { !$0.isStaple }.prefix(20).map(\.name)
            if onHand.isEmpty && staples.isEmpty {
                description = "Generate a quick, easy meal ready in 30 minutes or less."
            } else {
                var parts: [String] = []
                if !onHand.isEmpty  { parts.append("I currently have: \(onHand.joined(separator: ", "))") }
                if !staples.isEmpty { parts.append("I almost always keep: \(staples.joined(separator: ", "))") }
                description = "Generate a quick meal ready in 30 minutes or less. \(parts.joined(separator: ". ")). Use these ingredients where possible — no shopping trip."
            }
        } else {
            // General recipe: don't mention pantry at all. Even "staples" can include
            // highly specific ingredients (jalapeños, chipotle, masa harina) that bias
            // the AI toward one cuisine. Let the AI choose freely what fits the dish.
            description = "Surprise me with a simple, delicious home-cooked recipe. Aim for 10 ingredients or fewer — everyday cooking, not restaurant food."
        }
        // Dietary restrictions are a hard requirement — always included.
        if let restrictions = profile?.dietaryRestrictions, !restrictions.isEmpty {
            description += " Dietary needs: \(restrictions.map(\.displayName).joined(separator: ", "))."
        }

        // When the user asked for something specific (initialDescription set, or a named
        // cuisine), keep the prompt tight — variety signals, skill constraints, and cuisine
        // nudges just muddle a specific request. "Just make honey butter" should produce
        // honey butter, not a chef's elevated interpretation of it.
        let isSpecificRequest = initialDescription != nil || cuisineHint != nil
        if !isSpecificRequest {
            // Cooking goal shapes open-ended generation — not applied to specific requests
            // where the user has already said exactly what they want.
            let goal = profile?.cookingGoal ?? .greatFood
            if !goal.promptContext.isEmpty {
                description += " \(goal.promptContext)"
            }

            if let mt = mealType {
                description += " This recipe must be appropriate for \(mt.displayName.lowercased()) — use typical \(mt.displayName.lowercased()) ingredients and portion sizes."
            }
            if let cuisines = profile?.preferredCuisines, !cuisines.isEmpty {
                description += " Feel free to draw from my favourite cuisines (\(cuisines.map(\.rawValue).joined(separator: ", "))) but variety is welcome."
            }
            if !existingRecipes.isEmpty {
                let topCuisines = Dictionary(grouping: existingRecipes, by: \.cuisine)
                    .sorted { $0.value.count > $1.value.count }
                    .prefix(3)
                    .map { $0.key.rawValue }
                let cuisineStr = topCuisines.isEmpty ? "" : " My most-cooked cuisines are \(topCuisines.joined(separator: ", "))."
                description += " I already have \(existingRecipes.count) recipes saved — please suggest something fresh.\(cuisineStr)"
            }
            let skill = profile?.skillLevel ?? .intermediate
            description += recipeSkillConstraint(for: skill)
        }

        // Note: ingredient deduplication instructions are baked into buildGenerationPrompt
        // so they don't clutter the user's request string.

        streamingText = ""
        do {
            generatedResult = try await service.ingestFromTextStreaming(description, isGeneration: true) { chunk in
                streamingText += chunk
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ result: RecipeIngestionResult) async {
        isSaving = true
        defer { isSaving = false }
        let service = RecipeIngestionService(aiRouter: aiRouter)
        let recipe = await service.convertToRecipe(result)
        modelContext.insert(recipe)
        dismiss()
    }
}

// MARK: - Generated Recipe Preview Sheet

/// Full-screen preview shown after generation. Parses the result into a
/// structured card so the user can review before committing to save.
struct GeneratedRecipePreviewSheet: View {
    let result: RecipeIngestionResult
    /// Called after a successful save so the parent can dismiss itself.
    var onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.dismiss) private var dismiss

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                RecipeIngestionResultCard(result: result)
                    .padding()
            }
            .navigationTitle("Recipe Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let service = RecipeIngestionService(aiRouter: aiRouter)
        let recipe = await service.convertToRecipe(result)
        modelContext.insert(recipe)
        onSave()
    }
}

// MARK: - Recipe Ingestion Result Card

/// Shared formatted preview card used by both GeneratedRecipePreviewSheet
// MARK: - Streaming Recipe Preview

/// Shown while AI generation is in progress. Parses readable fields from the
/// partial JSON stream so the user sees the recipe taking shape, not raw code.
struct StreamingRecipePreview: View {
    let json: String
    var cuisineHint: String? = nil
    var quickMealMode: Bool = false
    var pantryIsEmpty: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var title: String? {
        guard let keyEnd = json.range(of: "\"title\"")?.upperBound else { return nil }
        let after = json[keyEnd...].drop(while: { ": \"".contains($0) })
        guard let quoteEnd = after.firstIndex(of: "\"") else { return nil }
        let t = String(after[..<quoteEnd])
        return t.isEmpty ? nil : t
    }
    private var hasIngredients: Bool { json.contains("\"ingredients\"") }
    private var hasDirections:   Bool { json.contains("\"directions\"") }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Sparkle icon
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Brand.herbGreen)
                .symbolEffect(.pulse)
                .accessibilityHidden(true)

            // Title fades in as soon as it's extracted
            Group {
                if let title {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text(cuisineHint.map { "Finding a great \($0) recipe…" }
                         ?? (quickMealMode
                             ? (pantryIsEmpty ? "Finding something quick to make…" : "Finding something quick with what you have…")
                             : "Generating a recipe…"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.easeOut(duration: 0.3), value: title)
            .padding(.horizontal, 32)

            // Progress steps
            VStack(alignment: .leading, spacing: 12) {
                streamingStep("Recipe name",  done: title != nil)
                streamingStep("Ingredients",  done: hasIngredients)
                streamingStep("Directions",   done: hasDirections)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func streamingStep(_ label: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Brand.herbGreen)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            } else {
                ProgressView()
                    .scaleEffect(0.75)
                    .frame(width: 18, height: 18)
            }
            Text(label)
                .foregroundStyle(done ? .primary : .secondary)
                .font(.subheadline)
        }
        .animation(.easeOut(duration: 0.25), value: done)
    }
}

/// Shared formatted recipe card used by GeneratedRecipePreviewSheet
/// and QuickGenerateView.
struct RecipeIngestionResultCard: View {
    let result: RecipeIngestionResult

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {

            // Title + metadata
            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.title2.weight(.bold))

                HStack(spacing: 14) {
                    if let prep = result.prepTimeMinutes {
                        Label("\(prep) min prep", systemImage: "scissors")
                    }
                    if let cook = result.cookTimeMinutes {
                        Label("\(cook) min cook", systemImage: "flame")
                    }
                    if let servings = result.servings {
                        Label("\(servings) servings", systemImage: "person.2")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let cuisine = result.cuisine {
                    Text(cuisine.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }

            Divider()

            // Ingredients
            VStack(alignment: .leading, spacing: 10) {
                Text("Ingredients")
                    .font(.headline)

                ForEach(result.ingredients, id: \.name) { ing in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 5, height: 5)
                            .padding(.top, 8)
                        Group {
                            if let prep = ing.preparation, !prep.isEmpty {
                                Text("\(ing.amount) **\(ing.name)**, \(prep)")
                            } else {
                                Text("\(ing.amount) **\(ing.name)**")
                            }
                        }
                        .font(.body)
                    }
                }
            }

            Divider()

            // Directions
            VStack(alignment: .leading, spacing: 16) {
                Text("Directions")
                    .font(.headline)

                ForEach(Array(result.directions.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Brand.herbGreen.opacity(0.7), in: Circle())
                            .padding(.top, 1)
                        Text(step)
                            .font(.body)
                    }
                }
            }
        }
        .padding()
        } // ScrollView
    }
}

// MARK: - Shared helpers

private func recipeSkillConstraint(for skill: RecipeDifficulty) -> String {
    switch skill {
    case .beginner:
        return " Keep it simple: max 8 ingredients, no more than 6 steps, basic techniques only (sauté, roast, boil). No mise en place or multi-component sauces."
    case .intermediate:
        return " Keep it approachable: max 12 ingredients, no more than 10 steps, standard home-cook techniques. No professional equipment required."
    case .advanced:
        return " This cook enjoys a challenge: up to 16 ingredients and more involved techniques are fine."
    case .expert:
        return " This is an experienced cook comfortable with complex techniques, long processes, and professional-level recipes."
    }
}
