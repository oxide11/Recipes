import SwiftUI
import SwiftData

// MARK: - Pantry View

struct PantryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var items: [PantryItem]
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @State private var showingScanner = false
    @State private var showingAddItem = false
    @State private var showingNoWasteResults = false
    @State private var searchText = ""
    @State private var itemToDelete: PantryItem?

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
                                    Text(date, style: .relative)
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

                // Items by category
                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    if let categoryItems = groupedItems[category], !categoryItems.isEmpty {
                        Section(category.rawValue.capitalized) {
                            ForEach(categoryItems) { item in
                                PantryItemRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            itemToDelete = item
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
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
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Scan", systemImage: "barcode.viewfinder") {
                        showingScanner = true
                    }
                    .accessibilityLabel("Scan barcode")
                    Button("Add", systemImage: "plus") {
                        showingAddItem = true
                    }
                    .accessibilityLabel("Add pantry item")
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerFullView()
            }
            .sheet(isPresented: $showingAddItem) {
                AddPantryItemView()
            }
            .confirmationDialog(
                "Delete Item",
                isPresented: .init(
                    get: { itemToDelete != nil },
                    set: { if !$0 { itemToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        modelContext.delete(item)
                        itemToDelete = nil
                    }
                }
            } message: {
                Text("Remove \"\(itemToDelete?.name ?? "")\" from your pantry?")
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
        HStack {
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
                    Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(item.isExpired ? Brand.spiceRed : Color.secondary)
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

    @State private var scanner = BarcodeScannerService()
    @State private var quantity: Double = 1
    @State private var unit: MeasurementUnit = .piece
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 86400)
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
                            Text("Position barcode within the frame")
                                .font(.subheadline)
                                .foregroundStyle(.white)
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

                Section("Quantity") {
                    HStack {
                        TextField("Qty", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $unit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
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
                // Product not found — manual entry
                Section("Product Not Found") {
                    Text("Barcode: \(scanner.scannedCode ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Item Name", text: $manualName)
                    Picker("Category", selection: $manualCategory) {
                        ForEach(IngredientCategory.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }

                Section("Quantity") {
                    HStack {
                        TextField("Qty", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                        Picker("Unit", selection: $unit) {
                            ForEach(MeasurementUnit.allCases, id: \.self) { u in
                                Text(u.rawValue).tag(u)
                            }
                        }
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
            quantity: quantity,
            unit: unit,
            expirationDate: hasExpiration ? expirationDate : nil
        ) {
            modelContext.insert(item)
            scanner.resetForNextScan()
        }
    }

    private func addManualItem() {
        let item = PantryItem(
            name: manualName,
            category: manualCategory,
            barcode: scanner.scannedCode,
            quantity: quantity,
            unit: unit,
            expirationDate: hasExpiration ? expirationDate : nil
        )
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
    @State private var quantity: Double = 1
    @State private var unit: MeasurementUnit = .piece
    @State private var hasExpiration = false
    @State private var expirationDate = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Name", text: $name)

                Picker("Category", selection: $category) {
                    ForEach(IngredientCategory.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }

                HStack {
                    TextField("Qty", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    Picker("Unit", selection: $unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
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
                            quantity: quantity,
                            unit: unit,
                            expirationDate: hasExpiration ? expirationDate : nil
                        )
                        modelContext.insert(item)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
