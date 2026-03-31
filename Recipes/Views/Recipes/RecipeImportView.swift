import SwiftUI
import PhotosUI
import UIKit

// MARK: - Recipe Import View

/// Unified recipe import interface supporting URL, text, photo, and Recipe-as-Code.
struct RecipeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: ImportSource = .url
    @State private var urlString = ""
    @State private var pastedText = ""
    @State private var recipeCodeText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoDialog = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var cameraImage: UIImage?

    @State private var ingestionService: RecipeIngestionService?
    @State private var result: RecipeIngestionResult?
    @State private var errorMessage: String?
    @State private var isProcessing = false
    @State private var showingPreview = false

    enum ImportSource: String, CaseIterable, Hashable {
        case url = "URL"
        case text = "Text"
        case photo = "Photo"
        case code = "Code"
    }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Import Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onAppear { ingestionService = RecipeIngestionService(aiRouter: aiRouter) }
        }
    }

    private var formContent: some View {
        Form {
            Picker("Source", selection: $selectedTab) {
                ForEach(ImportSource.allCases, id: \.self) { (source: ImportSource) in
                    Text(source.rawValue).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            sourceInputSection
            Section { importButton }
            errorSection
            if let result { importPreviewSection(result) }
        }
        .confirmationDialog("Add Photo", isPresented: $showingPhotoDialog) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingPhotoLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(image: $cameraImage).ignoresSafeArea()
        }
        .onChange(of: cameraImage) {
            if let img = cameraImage {
                photoData = img.jpegData(compressionQuality: 0.8)
                cameraImage = nil
            }
        }
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }

    // MARK: - Input Sections

    @ViewBuilder
    private var sourceInputSection: some View {
        switch selectedTab {
        case .url:   urlInputSection
        case .text:  textInputSection
        case .photo: photoInputSection
        case .code:  recipeCodeSection
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                }
                .foregroundStyle(.red)
            }
        }
    }

    private var urlInputSection: some View {
        Section("Recipe URL") {
            TextField("https://example.com/recipe/...", text: $urlString)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Text("Supports most recipe websites. We'll extract the recipe automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var textInputSection: some View {
        Section("Paste Recipe Text") {
            TextEditor(text: $pastedText)
                .frame(minHeight: 200)

            Text("Paste recipe text from any source — cookbook, email, message, or markdown.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var photoInputSection: some View {
        let hasPhoto = photoData != nil
        return Section("Recipe Photo") {
            Button {
                showingPhotoDialog = true
            } label: {
                if hasPhoto {
                    Label("Photo Selected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                }
            }

            Text("Take a photo of a recipe card, cookbook page, or screenshot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var recipeCodeSection: some View {
        Section("Recipe as Code") {
            TextEditor(text: $recipeCodeText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)

            Text("""
                Define ingredients and outcomes — AI infers the steps.
                Example:
                  title: "Pasta Aglio e Olio"
                  ingredients:
                    - spaghetti: 400g
                    - garlic: 6 cloves, sliced
                  outcomes:
                    - pasta is al dente
                    - garlic is golden
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Preview

    private func importPreviewSection(_ result: RecipeIngestionResult) -> some View {
        Section("Preview") {
            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let servings = result.servings {
                        Label("\(servings) servings", systemImage: "person.2")
                    }
                    if let prep = result.prepTimeMinutes {
                        Label("\(prep) min prep", systemImage: "scissors")
                    }
                    if let cook = result.cookTimeMinutes {
                        Label("\(cook) min cook", systemImage: "flame")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text("\(result.ingredients.count) ingredients, \(result.directions.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let cuisine = result.cuisine {
                    Text("Cuisine: \(cuisine.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Save to Recipes") {
                saveImportedRecipe(result)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var importButton: some View {
        Button {
            Task { await performImport() }
        } label: {
            HStack {
                Spacer()
                if isProcessing {
                    ProgressView().padding(.trailing, 8)
                    Text(ingestionService?.progress ?? "Processing...")
                } else {
                    Image(systemName: "arrow.down.doc")
                    Text("Import Recipe")
                }
                Spacer()
            }
        }
        .disabled(!canImport || isProcessing)
    }

    private var canImport: Bool {
        switch selectedTab {
        case .url:   return !urlString.isEmpty
        case .text:  return !pastedText.isEmpty
        case .photo: return photoData != nil
        case .code:  return !recipeCodeText.isEmpty
        }
    }

    private func performImport() async {
        guard let service = ingestionService else { return }

        isProcessing = true
        errorMessage = nil
        result = nil

        do {
            switch selectedTab {
            case .url:
                guard let url = URL(string: urlString) else {
                    errorMessage = "Invalid URL."
                    isProcessing = false
                    return
                }
                result = try await service.ingestFromURL(url)

            case .text:
                result = try await service.ingestFromText(pastedText)

            case .photo:
                guard let data = photoData else { return }
                result = try await service.ingestFromImage(data)

            case .code:
                result = try await service.ingestFromRecipeCode(recipeCodeText)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func saveImportedRecipe(_ result: RecipeIngestionResult) {
        guard let service = ingestionService else { return }
        let recipe = service.convertToRecipe(result)
        modelContext.insert(recipe)
        dismiss()
    }
}
