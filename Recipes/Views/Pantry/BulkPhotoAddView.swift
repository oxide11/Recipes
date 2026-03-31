import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Mode

private enum AddMode: String, CaseIterable {
    case photo = "Food Photo"
    case receipt = "Receipt"

    var icon: String {
        switch self {
        case .photo: return "camera.viewfinder"
        case .receipt: return "doc.text.viewfinder"
        }
    }
}

// MARK: - Identified Item

private struct IdentifiedItem: Identifiable {
    let id = UUID()
    var name: String
    var category: IngredientCategory
    var quantity: Double
    var isFrozen: Bool
    var price: Double?
    var isSelected: Bool = true
}

// MARK: - Bulk Photo Add View

struct BulkPhotoAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var mode: AddMode = .photo
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingPhotoDialog = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var identifiedItems: [IdentifiedItem] = []
    @State private var detectedStoreName: String = ""
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var didAnalyze = false

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(AddMode.allCases, id: \.self) { m in
                            Label(m.rawValue, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) {
                        identifiedItems = []
                        didAnalyze = false
                        errorMessage = nil
                    }
                }

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

                    let hasImage = selectedImage != nil
                    Button {
                        showingPhotoDialog = true
                    } label: {
                        Label(
                            hasImage ? "Change Photo" : "Take or Choose a Photo",
                            systemImage: "camera.viewfinder"
                        )
                        .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text(mode == .receipt
                         ? "Take a photo of your grocery receipt. The AI will extract food items and prices."
                         : "Take a photo of your fridge, counter, or grocery haul. The AI will identify what it sees.")
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
                                    Text(mode == .receipt ? "Reading receipt…" : "Identifying items…")
                                } else {
                                    Image(systemName: "sparkles")
                                    Text(mode == .receipt ? "Read Receipt" : "Identify Items")
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

                // Store name (receipt mode)
                if mode == .receipt && didAnalyze && !identifiedItems.isEmpty {
                    Section("Store") {
                        TextField("Store name (optional)", text: $detectedStoreName)
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
                                        if [IngredientCategory.protein, .vegetable, .fruit].contains(item.category) {
                                            Toggle("Frozen", isOn: $item.isFrozen)
                                                .font(.caption)
                                                .labelsHidden()
                                            if item.isFrozen {
                                                Image(systemName: "snowflake")
                                                    .font(.caption2)
                                                    .foregroundStyle(.blue)
                                            }
                                        }
                                        if let price = item.price {
                                            Text("$\(price, specifier: "%.2f")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
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
                            Text(mode == .receipt ? "Receipt Items" : "Identified Items")
                            Spacer()
                            Button("Select All") {
                                for i in identifiedItems.indices { identifiedItems[i].isSelected = true }
                            }
                            .font(.caption)
                        }
                    } footer: {
                        if mode == .receipt, let total = receiptTotal {
                            Text("Selected total: $\(total, specifier: "%.2f")")
                        } else {
                            Text("Tap the circle to include or exclude an item. Edit names or categories as needed.")
                        }
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
            .navigationTitle(mode == .receipt ? "Scan Receipt" : "Add from Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingPhotoDialog) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(image: $selectedImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) {
                Task { await loadPhoto() }
            }
        }
    }

    private var selectedCount: Int {
        identifiedItems.filter(\.isSelected).count
    }

    private var receiptTotal: Double? {
        let selected = identifiedItems.filter(\.isSelected).compactMap(\.price)
        guard !selected.isEmpty else { return nil }
        return selected.reduce(0, +)
    }

    private func loadPhoto() async {
        guard let item = selectedPhotoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedImage = image
        identifiedItems = []
        detectedStoreName = ""
        didAnalyze = false
        errorMessage = nil
    }

    private func analyze() async {
        guard let image = selectedImage,
              let jpeg = image.jpegData(compressionQuality: 0.8) else { return }

        isAnalyzing = true
        errorMessage = nil

        let prompt = mode == .receipt ? receiptPrompt : foodPhotoPrompt

        do {
            let response = try await aiRouter.analyzeImage(
                imageBase64: jpeg.base64EncodedString(),
                prompt: prompt
            )
            if mode == .receipt {
                parseReceiptResponse(response)
            } else {
                identifiedItems = parseFoodItems(from: response)
            }
            didAnalyze = true
            if identifiedItems.isEmpty {
                errorMessage = mode == .receipt
                    ? "No food items found on receipt. Try a clearer photo."
                    : "No food items identified. Try a clearer photo."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    private var foodPhotoPrompt: String {
        """
        This is a photo of food items (fridge, freezer, counter, or grocery haul).
        List every distinct food item you can identify.
        Respond with ONLY a JSON array, no explanation:
        [{"name": "chicken breast", "category": "protein", "quantity": 2, "frozen": true}]
        Valid categories: protein, vegetable, fruit, grain, dairy, spice, herb, condiment, oil, liquid, sweetener, nut, legume, other
        Estimate quantity as a whole number. Use "frozen": true if the item appears frozen.
        """
    }

    private var receiptPrompt: String {
        """
        This is a photo of a grocery receipt.
        Extract the store name and all food/grocery items with their prices and quantities.
        Ignore non-food items (cleaning supplies, paper goods, etc).
        Respond with ONLY a JSON object, no explanation:
        {"store": "Store Name or null", "items": [{"name": "Chicken Breast", "category": "protein", "quantity": 1, "price": 8.99}]}
        Valid categories: protein, vegetable, fruit, grain, dairy, spice, herb, condiment, oil, liquid, sweetener, nut, legume, other
        Normalize abbreviated names (e.g. "CHKN BRST" → "Chicken Breast"). Use null for price if not readable.
        """
    }

    private func parseFoodItems(from response: String) -> [IdentifiedItem] {
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

    private func parseReceiptResponse(_ response: String) {
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}") else { return }
        let jsonString = String(response[start...end])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        detectedStoreName = json["store"] as? String ?? ""

        guard let items = json["items"] as? [[String: Any]] else { return }
        identifiedItems = items.compactMap { dict in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let category = IngredientCategory(rawValue: dict["category"] as? String ?? "") ?? .other
            let quantity = (dict["quantity"] as? Double) ?? (dict["quantity"] as? Int).map(Double.init) ?? 1
            let price = dict["price"] as? Double
            return IdentifiedItem(name: name, category: category, quantity: quantity, isFrozen: false, price: price)
        }
    }

    private func addSelectedItems() {
        let selected = identifiedItems.filter(\.isSelected)

        if mode == .receipt {
            let total = selected.compactMap(\.price).reduce(0, +)
            let receipt = GroceryReceipt(
                storeName: detectedStoreName.isEmpty ? nil : detectedStoreName,
                totalAmount: total
            )
            receipt.items = selected.map {
                ReceiptLineItem(name: $0.name, price: $0.price ?? 0, quantity: Int($0.quantity))
            }
            modelContext.insert(receipt)
        }

        for item in selected {
            let pantryItem = PantryItem(
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                unit: .piece
            )
            pantryItem.isFrozen = item.isFrozen
            pantryItem.purchasePrice = item.price
            modelContext.insert(pantryItem)
        }

        dismiss()
    }
}
