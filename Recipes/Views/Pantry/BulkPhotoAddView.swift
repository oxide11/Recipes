import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Identified Item

private struct IdentifiedItem: Identifiable {
    let id = UUID()
    var name: String
    var category: IngredientCategory
    var quantity: Double
    var isFrozen: Bool
    var isSelected: Bool = true
}

// MARK: - Bulk Photo Add View

struct BulkPhotoAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var identifiedItems: [IdentifiedItem] = []
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var didAnalyze = false

    var body: some View {
        NavigationStack {
            Form {
                // Photo picker
                Section {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(.rect(cornerRadius: 10))
                            .frame(maxWidth: .infinity)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            selectedImage != nil ? "Change Photo" : "Take or Choose a Photo",
                            systemImage: "camera.viewfinder"
                        )
                        .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Take a photo of your fridge, counter, or grocery haul. The AI will identify what it sees.")
                }

                // Analyze button
                if selectedImage != nil && !didAnalyze {
                    Section {
                        Button {
                            Task { await analyze() }
                        } label: {
                            HStack {
                                Spacer()
                                if isAnalyzing {
                                    ProgressView().padding(.trailing, 8)
                                    Text("Identifying items…")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("Identify Items")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isAnalyzing)
                    }
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                // Results checklist
                if !identifiedItems.isEmpty {
                    Section {
                        ForEach($identifiedItems) { $item in
                            HStack(alignment: .center) {
                                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                    .onTapGesture { item.isSelected.toggle() }

                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("Name", text: $item.name)
                                    HStack(spacing: 8) {
                                        TextField("Qty", value: $item.quantity, format: .number)
                                            .keyboardType(.decimalPad)
                                            .frame(width: 40)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if item.category == .protein || item.category == .vegetable || item.category == .fruit {
                                            Toggle("Frozen", isOn: $item.isFrozen)
                                                .font(.caption)
                                                .labelsHidden()
                                            if item.isFrozen {
                                                Image(systemName: "snowflake")
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                    }
                                }

                                Spacer()

                                Picker("", selection: $item.category) {
                                    ForEach(IngredientCategory.allCases, id: \.self) { c in
                                        Text(c.rawValue.capitalized).tag(c)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 110)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Identified Items")
                            Spacer()
                            Button("Select All") {
                                for i in identifiedItems.indices { identifiedItems[i].isSelected = true }
                            }
                            .font(.caption)
                        }
                    } footer: {
                        Text("Tap the circle to include or exclude an item. Edit names or categories as needed.")
                    }

                    Section {
                        Button {
                            addSelectedItems()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Add \(selectedCount) Item\(selectedCount == 1 ? "" : "s") to Pantry")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(selectedCount == 0)
                    }
                }
            }
            .navigationTitle("Add from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) {
                Task { await loadPhoto() }
            }
        }
    }

    private var selectedCount: Int {
        identifiedItems.filter(\.isSelected).count
    }

    private func loadPhoto() async {
        guard let item = selectedPhotoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedImage = image
        identifiedItems = []
        didAnalyze = false
        errorMessage = nil
    }

    private func analyze() async {
        guard let image = selectedImage,
              let jpeg = image.jpegData(compressionQuality: 0.8) else { return }

        isAnalyzing = true
        errorMessage = nil

        let prompt = """
        This is a photo of food items (fridge, freezer, counter, or grocery haul).
        List every distinct food item you can identify.
        Respond with ONLY a JSON array, no explanation:
        [{"name": "chicken breast", "category": "protein", "quantity": 2, "frozen": true}, {"name": "spinach", "category": "vegetable", "quantity": 1, "frozen": false}]
        Valid categories: protein, vegetable, fruit, grain, dairy, spice, herb, condiment, oil, liquid, sweetener, nut, legume, other
        Estimate quantity as a whole number (e.g. number of items, bags, or containers visible). Use "frozen": true if the item appears to be frozen or is in a freezer context.
        """

        do {
            let response = try await aiRouter.analyzeImage(
                imageBase64: jpeg.base64EncodedString(),
                prompt: prompt
            )
            identifiedItems = parseItems(from: response)
            didAnalyze = true
            if identifiedItems.isEmpty {
                errorMessage = "No food items identified. Try a clearer photo."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    private func parseItems(from response: String) -> [IdentifiedItem] {
        guard let start = response.firstIndex(of: "["),
              let end = response.lastIndex(of: "]") else { return [] }
        let jsonString = String(response[start...end])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let category = IngredientCategory(rawValue: dict["category"] as? String ?? "") ?? .other
            let quantity = (dict["quantity"] as? Double) ?? (dict["quantity"] as? Int).map(Double.init) ?? 1
            let isFrozen = dict["frozen"] as? Bool ?? false
            return IdentifiedItem(name: name, category: category, quantity: quantity, isFrozen: isFrozen)
        }
    }

    private func addSelectedItems() {
        for item in identifiedItems where item.isSelected {
            let pantryItem = PantryItem(
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                unit: .piece
            )
            pantryItem.isFrozen = item.isFrozen
            modelContext.insert(pantryItem)
        }
        dismiss()
    }
}
