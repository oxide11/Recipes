import SwiftUI
import SwiftData

private let expiryDateFormatterSameYear: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
}()

private let expiryDateFormatterOtherYear: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d, yyyy"
    return f
}()

private func expiryDateFormatter(for date: Date) -> DateFormatter {
    Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
        ? expiryDateFormatterSameYear
        : expiryDateFormatterOtherYear
}

private func daysAgoLabel(for date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
    if days <= 0 { return "Added today" }
    if days == 1 { return "Added yesterday" }
    return "Added \(days)d ago"
}

private func expiryLabel(for date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
    if days <= 0 { return "Today" }
    if days == 1 { return "Tomorrow" }
    return "in \(days) days"
}

// MARK: - Pantry View

struct PantryView: View {
    var startWithAddSheet: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var items: [PantryItem]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @State private var showingScanner = false
    @State private var showingAddItem = false
    @State private var showingBulkPhoto = false
    @State private var showingQuickAdd = false
    @State private var showingNoWasteResults = false
    @State private var searchText = ""
    @State private var editingItem: PantryItem?

    private var filteredItems: [PantryItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedItems: [IngredientCategory: [PantryItem]] {
        Dictionary(grouping: filteredItems, by: \.category)
    }

    private var expiringItems: [PantryItem] {
        items.filter(\.isExpiringSoon)
    }

    @ViewBuilder
    private func pantryItemRow(_ item: PantryItem) -> some View {
        PantryItemRow(item: item)
            .contentShape(Rectangle())
            .onTapGesture { editingItem = item }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    modelContext.delete(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    private var spiceRackItems: [PantryItem] {
        filteredItems.filter { $0.category == .spice || $0.category == .herb }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
        List {
                // "Use It Up" section for expiring items
                if !expiringItems.isEmpty {
                    Section {
                        ForEach(expiringItems) { item in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Brand.spiceRed)
                                Text(item.name)
                                Spacer()
                                if let date = item.expirationDate {
                                    Text(expiryLabel(for: date))
                                        .font(.caption)
                                        .foregroundStyle(Brand.spiceRed)
                                }
                            }
                        }

                        Button {
                            showingNoWasteResults = true
                        } label: {
                            Label("Find Recipes to Use These Up", systemImage: "sparkles")
                        }
                        .tint(Brand.spiceRed)
                    } header: {
                        Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                    }
                }

                // Quick actions
                if !items.isEmpty {
                    Section {
                        NavigationLink {
                            NoWasteResultsView(recipes: recipes, pantryItems: items)
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("What Can I Make?")
                                        .fontWeight(.medium)
                                    Text("\(items.count) items in pantry")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "frying.pan")
                                    .foregroundStyle(.tint)
                            }
                        }

                        NavigationLink {
                            RecommendedStaplesView()
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Recommended Staples")
                                        .fontWeight(.medium)
                                    let missing = RecommendedStaplesService.missingStaples(pantryItems: items)
                                    Text("\(missing.count) suggested items to stock")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checklist")
                                    .foregroundStyle(Brand.herbGreen)
                            }
                        }
                    }
                }

                // Spice Rack
                if !spiceRackItems.isEmpty {
                    Section {
                        ForEach(spiceRackItems) { item in
                            PantryItemRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture { editingItem = item }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Label("Spice Rack", systemImage: "sparkles")
                    }
                }

                // Items by category (excluding spices/herbs shown above)
                ForEach(IngredientCategory.allCases.filter({ $0 != .spice && $0 != .herb }), id: \.self) { category in
                    if let categoryItems = groupedItems[category], !categoryItems.isEmpty {
                        Section(category.rawValue.capitalized) {
                            ForEach(categoryItems) { item in
                                pantryItemRow(item)
                            }
                        }
                    }
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "Pantry is Empty",
                        systemImage: "refrigerator",
                        description: Text("Scan barcodes or add items manually to start tracking ingredients.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("No pantry items match your search.")
                    )
                }
            }
            .navigationTitle("Pantry")
            .searchable(text: $searchText, prompt: "Search pantry...")
            .onAppear { if startWithAddSheet { showingAddItem = true } }
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Scan", systemImage: "barcode.viewfinder") {
                        showingScanner = true
                    }
                    .accessibilityLabel("Scan barcode")
                    Menu {
                        Button("Quick Add", systemImage: "text.badge.plus") {
                            showingQuickAdd = true
                        }
                        Button("Add Item Manually", systemImage: "square.and.pencil") {
                            showingAddItem = true
                        }
                        Button("Add from Photo", systemImage: "camera.viewfinder") {
                            showingBulkPhoto = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerFullView()
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddPantryView()
            }
            .sheet(isPresented: $showingAddItem) {
                AddPantryItemView()
            }
            .sheet(isPresented: $showingBulkPhoto) {
                BulkPhotoAddView()
            }
            .sheet(item: $editingItem) { item in
                EditPantryItemView(item: item)
            }
            .sheet(isPresented: $showingNoWasteResults) {
                NavigationStack {
                    NoWasteResultsView(
                        recipes: recipes,
                        pantryItems: items,
                        expiringOnly: true
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingNoWasteResults = false }
                        }
                    }
                }
        }
        }
    }
}

// MARK: - Pantry Item Row

struct PantryItemRow: View {
    let item: PantryItem

    var body: some View {
        HStack(spacing: 10) {
            // Color-coded category dot
            Circle()
                .fill(categoryColor(item.category))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isExpired ? .red : .primary)

                HStack(spacing: 4) {
                    if item.barcode != nil {
                        Image(systemName: "barcode")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if !SeasonalAwarenessService.isInSeason(item.name) {
                        Label("Off season", systemImage: "leaf.arrow.triangle.circlepath")
                            .font(.caption2)
                            .foregroundStyle(Brand.muted)
                    }
                }
            }

            Spacer()

            if let date = item.expirationDate {
                VStack(alignment: .trailing) {
                    Text(item.isExpired ? "Expired" : "Expires")
                        .font(.caption2)
                        .foregroundStyle(item.isExpired ? Brand.spiceRed : Color.secondary)
                    Text(date, formatter: expiryDateFormatter(for: date))
                        .font(.caption2)
                        .foregroundStyle(item.isExpired ? Brand.spiceRed : Color.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    let daysInPantry = Calendar.current.dateComponents([.day], from: item.dateAdded, to: Date()).day ?? 0
                    if item.category == .protein && !item.isFrozen && daysInPantry >= 3 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Brand.spiceRed)
                            .help("No expiration date set — consider adding one for fresh proteins")
                    }
                    Text(daysAgoLabel(for: item.dateAdded))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func categoryColor(_ category: IngredientCategory) -> Color {
        category.displayColor.swiftUIColor
    }
}

// MARK: - Barcode Scanner Full View (with live camera)

struct BarcodeScannerFullView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var scanner = BarcodeScannerService()
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 86400)
    @State private var isFrozen = false
    @State private var manualName = ""
    @State private var manualCategory: IngredientCategory = .other

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Camera preview or result
                if scanner.isScanning, let session = scanner.captureSession {
                    ZStack {
                        CameraPreviewView(session: session)

                        // Scan overlay
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 280, height: 140)
                            Spacer()

                            HStack(spacing: 16) {
                                Text("Position barcode within the frame")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)

                                Button {
                                    scanner.capturePhoto()
                                } label: {
                                    Label("Photo", systemImage: "camera.fill")
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.glass)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 16))
                    .padding()
                } else if scanner.scannedCode != nil {
                    // Show result
                    scannedResultView
                } else {
                    // Camera not started yet
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Button("Start Scanning") {
                            Task {
                                let granted = await scanner.requestCameraAccess()
                                if granted {
                                    scanner.startScanning()
                                } else {
                                    scanner.errorMessage = "Camera access is required for barcode scanning. Enable it in Settings."
                                }
                            }
                        }
                        .buttonStyle(.glass)
                    }
                    .frame(height: 300)
                }

                if let error = scanner.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Brand.spiceRed)
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                let granted = await scanner.requestCameraAccess()
                if granted {
                    scanner.startScanning()
                }
            }
        }
    }

    @ViewBuilder
    private var scannedResultView: some View {
        Form {
            if scanner.isLookingUp {
                Section {
                    HStack {
                        ProgressView()
                        Text("Looking up product...")
                            .padding(.leading, 8)
                    }
                }
            } else if let product = scanner.lookupResult {
                Section("Product Found") {
                    LabeledContent("Name", value: product.name)
                    if let brand = product.brand {
                        LabeledContent("Brand", value: brand)
                    }
                    LabeledContent("Category", value: product.category.rawValue.capitalized)
                    LabeledContent("Barcode", value: product.barcode)
                }

                Section {
                    if let product = scanner.lookupResult, [.protein, .vegetable, .fruit].contains(product.category) {
                        Toggle("Frozen", isOn: $isFrozen)
                    }
                    Toggle("Has Expiration Date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Add to Pantry") {
                        addProductToPantry()
                    }
                    .frame(maxWidth: .infinity)

                    Button("Scan Another") {
                        scanner.resetForNextScan()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Product not found — manual entry or AI identification
                Section("Product Not Found") {
                    Text("Barcode: \(scanner.scannedCode ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        if scanner.capturedImage == nil {
                            scanner.capturePhoto()
                        }
                        Task { await scanner.llmIdentifyProduct(using: aiRouter) }
                    } label: {
                        HStack {
                            if scanner.isLLMIdentifying {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Label("Try AI Identification", systemImage: "sparkles")
                        }
                    }
                    .disabled(scanner.isLLMIdentifying)

                    TextField("Item Name", text: $manualName)
                    Picker("Category", selection: $manualCategory) {
                        ForEach(IngredientCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }

                    if let img = scanner.capturedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 120)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }

                Section {
                    if [.protein, .vegetable, .fruit].contains(manualCategory) {
                        Toggle("Frozen", isOn: $isFrozen)
                    }
                    Toggle("Has Expiration Date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                    }
                }

                Section {
                    Button("Add to Pantry") {
                        addManualItem()
                    }
                    .disabled(manualName.isEmpty)
                    .frame(maxWidth: .infinity)

                    Button("Scan Another") {
                        scanner.resetForNextScan()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func addProductToPantry() {
        if let item = scanner.createPantryItem(
            expirationDate: hasExpiration ? expirationDate : nil
        ) {
            item.isFrozen = isFrozen
            modelContext.insert(item)
            scanner.resetForNextScan()
        }
    }

    private func addManualItem() {
        let item = PantryItem(
            name: manualName,
            category: manualCategory,
            barcode: scanner.scannedCode,
            quantity: 1,
            unit: .piece,
            expirationDate: hasExpiration ? expirationDate : nil
        )
        item.isFrozen = isFrozen
        modelContext.insert(item)
        scanner.resetForNextScan()
        manualName = ""
    }
}

// MARK: - Add Pantry Item View (Manual)

struct AddPantryItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: IngredientCategory = .other
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 86400)
    @State private var isFrozen = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(IngredientCategory.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }

                if category == .protein || category == .vegetable || category == .fruit {
                    Toggle("Frozen", isOn: $isFrozen)
                }

                Toggle("Has Expiration Date", isOn: $hasExpiration)
                if hasExpiration {
                    DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Add Pantry Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = PantryItem(
                            name: name,
                            category: category,
                            quantity: 1,
                            unit: .piece,
                            expirationDate: hasExpiration ? expirationDate : nil
                        )
                        item.isFrozen = isFrozen
                        modelContext.insert(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Pantry Item View

struct EditPantryItemView: View {
    @Bindable var item: PantryItem
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var category: IngredientCategory
    @State private var hasExpiration: Bool
    @State private var expirationDate: Date
    @State private var isFrozen: Bool

    init(item: PantryItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _hasExpiration = State(initialValue: item.expirationDate != nil)
        _expirationDate = State(initialValue: item.expirationDate ?? Date().addingTimeInterval(7 * 86400))
        _isFrozen = State(initialValue: item.isFrozen)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(IngredientCategory.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }

                if category == .protein || category == .vegetable || category == .fruit {
                    Toggle("Frozen", isOn: $isFrozen)
                }

                Toggle("Has Expiration Date", isOn: $hasExpiration)
                if hasExpiration {
                    DatePicker("Expires", selection: $expirationDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.name = name
                        item.category = category
                        item.expirationDate = hasExpiration ? expirationDate : nil
                        item.isFrozen = isFrozen
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Quick Add Pantry View

/// Natural-language bulk add: type "eggs, butter, olive oil, chicken thighs"
/// and the AI categorises each item automatically.
struct QuickAddPantryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var inputText = ""
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "e.g. eggs, butter, olive oil, chicken thighs",
                        text: $inputText,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .autocorrectionDisabled()
                } header: {
                    Text("What do you have?")
                } footer: {
                    Text("Separate items with commas or new lines. The AI will categorise each one.")
                        .font(.caption)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(Brand.spiceRed).font(.caption)
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { await addItems() }
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func addItems() async {
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }

        // Parse raw tokens from input
        let tokens = inputText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return }

        // Ask AI to categorise all tokens in one call
        let list = tokens.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let prompt = """
        Categorise each grocery/pantry item into one of these categories: protein, dairy, vegetable, fruit, grain, spice, herb, condiment, oil, liquid, sweetener, nut, other.
        Items:
        \(list)
        Respond with ONLY a JSON array, one object per item, in order:
        [{"name":"item name","category":"category"}]
        """

        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .classification)
            let parsed = parseItems(from: response, fallback: tokens)
            for entry in parsed {
                let item = PantryItem(name: entry.name, category: entry.category, quantity: 1, unit: .piece)
                modelContext.insert(item)
            }
            dismiss()
        } catch {
            // AI failed — add items with .other category as a fallback
            for token in tokens {
                let item = PantryItem(name: token, category: .other, quantity: 1, unit: .piece)
                modelContext.insert(item)
            }
            dismiss()
        }
    }

    private struct ParsedItem { let name: String; let category: IngredientCategory }

    private func parseItems(from response: String, fallback tokens: [String]) -> [ParsedItem] {
        guard let start = response.firstIndex(of: "["),
              let end = response.lastIndex(of: "]") else {
            return tokens.map { ParsedItem(name: $0, category: .other) }
        }
        let json = String(response[start...end])
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return tokens.map { ParsedItem(name: $0, category: .other) }
        }
        return array.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let cat = IngredientCategory(rawValue: dict["category"] as? String ?? "") ?? .other
            return ParsedItem(name: name, category: cat)
        }
    }
}
