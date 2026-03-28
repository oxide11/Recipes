import SwiftUI
import SwiftData

// MARK: - Pantry View

struct PantryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.dateAdded, order: .reverse) private var items: [PantryItem]

    @State private var showingScanner = false
    @State private var showingAddItem = false
    @State private var searchText = ""

    private var filteredItems: [PantryItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedItems: [IngredientCategory: [PantryItem]] {
        Dictionary(grouping: filteredItems, by: \.category)
    }

    var body: some View {
        NavigationStack {
            List {
                // Expiring soon alert
                let expiring = items.filter(\.isExpiringSoon)
                if !expiring.isEmpty {
                    Section {
                        ForEach(expiring) { item in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(item.name)
                                Spacer()
                                if let date = item.expirationDate {
                                    Text(date, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } header: {
                        Label("Expiring Soon", systemImage: "clock.badge.exclamationmark")
                    }
                }

                // Items by category
                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    if let categoryItems = groupedItems[category], !categoryItems.isEmpty {
                        Section(category.rawValue.capitalized) {
                            ForEach(categoryItems) { item in
                                PantryItemRow(item: item)
                            }
                            .onDelete { offsets in
                                for offset in offsets {
                                    modelContext.delete(categoryItems[offset])
                                }
                            }
                        }
                    }
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "Pantry is Empty",
                        systemImage: "refrigerator",
                        description: Text("Scan barcodes or add items manually.")
                    )
                }
            }
            .navigationTitle("Pantry")
            .searchable(text: $searchText, prompt: "Search pantry...")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Scan", systemImage: "barcode.viewfinder") {
                        showingScanner = true
                    }
                    Button("Add", systemImage: "plus") {
                        showingAddItem = true
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView()
            }
            .sheet(isPresented: $showingAddItem) {
                AddPantryItemView()
            }
        }
    }
}

// MARK: - Pantry Item Row

struct PantryItemRow: View {
    let item: PantryItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .fontWeight(.medium)
                    .foregroundStyle(item.isExpired ? .red : .primary)

                Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = item.expirationDate {
                VStack(alignment: .trailing) {
                    Text(item.isExpired ? "Expired" : "Expires")
                        .font(.caption2)
                        .foregroundStyle(item.isExpired ? .red : .secondary)
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(item.isExpired ? .red : .secondary)
                }
            }
        }
    }
}

// MARK: - Barcode Scanner View (Placeholder)

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)

                Text("Point camera at a barcode")
                    .font(.headline)

                Text("Scanned items will be added to your pantry automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Pantry Item View

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
