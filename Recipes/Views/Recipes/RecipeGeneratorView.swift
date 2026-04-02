import SwiftUI
import SwiftData
import PhotosUI

// MARK: - AI Recipe Generator View

struct RecipeGeneratorView: View {
    var initialCuisine: Cuisine? = nil

    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
    @State private var isSaving = false
    @State private var generatedText: String?
    @State private var errorMessage: String?

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
                        generatedText = nil
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

                Section("Dietary Restrictions") {
                    ForEach(sortedDietaryRestrictions, id: \.self) { restriction in
                        Toggle(restriction.displayName, isOn: Binding(
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

                if let result = generatedText {
                    Section("Generated Recipe") {
                        Text(result)
                            .font(.body)
                        Button {
                            Task { await saveGenerated(result) }
                        } label: {
                            Label("Save Recipe", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle("Recipe Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if isSaving {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
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
        generatedText = nil
        defer { isGenerating = false }

        do {
            switch mode {
            case .photo:
                generatedText = try await generateFromPhoto()
            case .pantry:
                generatedText = try await generateFromPantry()
            case .describe:
                generatedText = try await generateFromDescription()
            }
        } catch {
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
        return suffix
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    func saveGenerated(_ text: String) async {
        isSaving = true
        defer { isSaving = false }
        let service = RecipeIngestionService(aiRouter: aiRouter)
        if let result = try? await service.ingestFromText(text) {
            let recipe = await service.convertToRecipe(result)
            modelContext.insert(recipe)
            dismiss()
        }
    }
}

// MARK: - Quick Generate View (Dashboard shortcut)

/// Auto-generates a recipe on appear — no form, just a spinner then a formatted result card.
/// Pass `quickMealMode: true` to bias generation toward meals ready in ≤ 30 minutes.
struct QuickGenerateView: View {
    var quickMealMode: Bool = false

    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var pantryItems: [PantryItem]
    @Query private var profiles: [UserProfile]

    @State private var isGenerating = true
    @State private var isSaving = false
    @State private var generatedResult: RecipeIngestionResult?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(quickMealMode ? "Finding something quick for you…" : "Generating a recipe for you…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    recipeCard(result)
                }
            }
            .navigationTitle(quickMealMode ? "Quick Meal" : "Quick Generate")
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

    // MARK: - Formatted Recipe Card

    @ViewBuilder
    private func recipeCard(_ result: RecipeIngestionResult) -> some View {
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
                                .background(Color.secondary.opacity(0.5), in: Circle())
                                .padding(.top, 1)
                            Text(step)
                                .font(.body)
                        }
                    }
                }
            }
            .padding()
        }
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
        if quickMealMode {
            // Quick meal: constrain to pantry so no shopping trip is needed
            if pantryItems.isEmpty {
                description = "Generate a quick, easy meal ready in 30 minutes or less."
            } else {
                let names = pantryItems.prefix(20).map(\.name).joined(separator: ", ")
                description = "Generate a quick meal ready in 30 minutes or less using some or all of these pantry ingredients: \(names)."
            }
        } else {
            // General recipe: not pantry-constrained — shopping is fine
            // Hint at ingredients they've used before as a soft preference, not a requirement
            let usedNames = pantryItems.filter { $0.lastUsed != nil }.prefix(12).map(\.name)
            let stapleHint = usedNames.isEmpty ? "" :
                " Feel free to incorporate ingredients like \(usedNames.joined(separator: ", ")) if they fit naturally, but don't feel constrained to them."
            description = "Surprise me with a delicious recipe.\(stapleHint)"
        }
        if let restrictions = profile?.dietaryRestrictions, !restrictions.isEmpty {
            description += " Dietary needs: \(restrictions.map(\.displayName).joined(separator: ", "))."
        }
        if let cuisines = profile?.preferredCuisines, !cuisines.isEmpty {
            description += " Preferred cuisines: \(cuisines.map(\.rawValue).joined(separator: ", "))."
        }

        do {
            // ingestFromText structures the AI output as a RecipeIngestionResult in one call
            generatedResult = try await service.ingestFromText(description)
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
