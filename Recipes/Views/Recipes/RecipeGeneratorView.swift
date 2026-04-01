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

        isGenerating = false
    }

    private func generateFromPhoto() async throws -> String {
        guard let image = selectedImage,
              let jpegData = image.jpegData(compressionQuality: 0.8) else {
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
}
