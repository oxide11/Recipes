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
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var cameraImage: UIImage?
    @State private var showingBrowser = false
    @State private var showingFullPhoto = false
    @AppStorage("savedRecipeURLs") private var savedURLsData: Data = Data()

    @State private var ingestionService: RecipeIngestionService?
    @State private var result: RecipeIngestionResult?
    @State private var selectedDietaryTags: Set<DietaryRestriction> = []
    @State private var linkIngredientsToSteps = true
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

            if result == nil {
                sourceInputSection
                Section { importButton }
            } else if selectedTab == .url, !urlString.isEmpty {
                // Keep a compact bookmark row visible after preview so the site can still be saved
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        Text(urlString)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            saveURL(urlString)
                        } label: {
                            Image(systemName: savedURLs.contains(urlString) ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(Brand.warmTan)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Source")
                }
            }
            errorSection
            if let result { importPreviewSection(result) }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(image: $cameraImage).ignoresSafeArea()
        }
        .onChange(of: cameraImage) {
            if let img = cameraImage {
                photoData = img.jpegData(compressionQuality: 0.5)
                cameraImage = nil
            }
        }
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Always convert to JPEG — library photos may be HEIC
                    photoData = image.jpegData(compressionQuality: 0.5)
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

    private var savedURLs: [String] {
        (try? JSONDecoder().decode([String].self, from: savedURLsData)) ?? []
    }

    private func saveURL(_ url: String) {
        guard !url.isEmpty, !savedURLs.contains(url) else { return }
        var urls = savedURLs
        urls.insert(url, at: 0)
        savedURLsData = (try? JSONEncoder().encode(Array(urls.prefix(20)))) ?? Data()
    }

    private func deleteURL(_ url: String) {
        var urls = savedURLs
        urls.removeAll { $0 == url }
        savedURLsData = (try? JSONEncoder().encode(urls)) ?? Data()
    }

    private var urlInputSection: some View {
        Group {
            Section {
                HStack {
                    TextField("https://", text: $urlString)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.subheadline)

                    Button {
                        saveURL(urlString)
                    } label: {
                        Image(systemName: savedURLs.contains(urlString) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(urlString.isEmpty ? Color.secondary.opacity(0.4) : Brand.warmTan)
                    }
                    .buttonStyle(.plain)
                    .disabled(urlString.isEmpty)
                }

                Button {
                    showingBrowser = true
                } label: {
                    Label("Browse for a Recipe", systemImage: "globe")
                }
                .sheet(isPresented: $showingBrowser) {
                    RecipeBrowserView { importedURL in
                        urlString = importedURL
                        selectedTab = .url
                        Task { await performImport(urlOverride: importedURL) }
                    }
                }
            } footer: {
                Text("Paste a URL, browse the web, or tap a saved site below.")
                    .font(.caption)
            }

            if !savedURLs.isEmpty {
                Section("Saved") {
                    ForEach(savedURLs, id: \.self) { url in
                        Button {
                            urlString = url
                            Task { await performImport(urlOverride: url) }
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .font(.caption)
                                    .foregroundStyle(Brand.warmTan)
                                Text(url)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteURL(url)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
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
        Section("Recipe Photo") {
            if let photoData, let image = UIImage(data: photoData) {
                Button {
                    showingFullPhoto = true
                } label: {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(3)
                                    .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
                                    .foregroundStyle(.white)
                                    .padding(3)
                            }
                        Text("Tap to view full size")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            self.photoData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingFullPhoto) {
                    if let image = UIImage(data: photoData) {
                        NavigationStack {
                            ZoomableImageView(image: image)
                                .navigationTitle("Recipe Photo")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") { showingFullPhoto = false }
                                    }
                                }
                        }
                    }
                }
            } else {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }

                Button {
                    showingPhotoLibrary = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            }

            Text("Photograph a recipe card, cookbook page, or handwritten recipe.")
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

    @ViewBuilder
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
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Dietary Tags")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Tap to add or remove. We've made our best guess.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { tag in
                        let selected = selectedDietaryTags.contains(tag)
                        Button {
                            if selected {
                                selectedDietaryTags.remove(tag)
                            } else {
                                selectedDietaryTags.insert(tag)
                            }
                        } label: {
                            Text(tag.displayName)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selected ? Color.green.opacity(0.2) : Color.secondary.opacity(0.12), in: Capsule())
                                .foregroundStyle(selected ? .green : .secondary)
                                .overlay(Capsule().strokeBorder(selected ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 4)
        }

        Section {
            Toggle(isOn: $linkIngredientsToSteps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Link ingredients to steps")
                        .font(.subheadline)
                    Text("Highlights ingredients mentioned in each direction. Usually accurate, but may occasionally miss or over-match.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button {
                saveImportedRecipe(result)
            } label: {
                Text("Add to My Recipes")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

            Button("Start Over") {
                self.result = nil
                selectedDietaryTags = []
                linkIngredientsToSteps = true
                urlString = ""
                pastedText = ""
                photoData = nil
                recipeCodeText = ""
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var importButton: some View {
        Button {
            Task { await performImport(urlOverride: nil) }
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

    private func performImport(urlOverride: String? = nil) async {
        guard let service = ingestionService else { return }

        isProcessing = true
        errorMessage = nil
        result = nil

        do {
            switch selectedTab {
            case .url:
                let target = urlOverride ?? urlString
                guard let url = URL(string: target) else {
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

        // Seed dietary tags from AI detection
        if let r = result {
            let detected = (r.dietaryInfo ?? []).compactMap { info in
                DietaryRestriction.allCases.first {
                    $0.rawValue.lowercased() == info.lowercased()
                        .replacingOccurrences(of: "-", with: "")
                        .replacingOccurrences(of: " ", with: "")
                }
            }
            selectedDietaryTags = Set(detected)
        }
    }

    private func saveImportedRecipe(_ result: RecipeIngestionResult) {
        guard let service = ingestionService else { return }
        Task {
        let recipe = await service.convertToRecipe(result)
        recipe.dietaryRestrictions = Array(selectedDietaryTags)
        if !linkIngredientsToSteps {
            for i in recipe.directions.indices {
                recipe.directions[i].ingredients = []
            }
        }
        for ingredient in recipe.ingredients {
            modelContext.insert(ingredient)
        }
        modelContext.insert(recipe)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Couldn't save recipe: \(error.localizedDescription)"
        }
        } // end Task
    }
}
