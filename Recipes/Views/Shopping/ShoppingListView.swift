import SwiftUI
import SwiftData

// MARK: - Shopping List View

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query(sort: \GroceryList.dateCreated, order: .reverse) private var lists: [GroceryList]

    @State private var showingCreateList = false
    @State private var showingGuidedShopping = false
    @State private var showingReceiptScanner = false
    @State private var selectedList: GroceryList?
    @State private var listToDelete: GroceryList?

    var body: some View {
        NavigationStack {
            List {
                if let activeList = lists.first {
                    // Active list header
                    Section {
                        ProgressView(value: activeList.progress) {
                            HStack {
                                Text("\(Int(activeList.progress * 100))% complete")
                                Spacer()
                                Text("\(activeList.items.filter(\.isPurchased).count)/\(activeList.items.count) items")
                            }
                        }
                        .tint(Brand.herbGreen)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Estimated")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(activeList.totalEstimatedCost, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Actual")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(activeList.totalActualCost, format: .currency(code: "USD"))
                                    .fontWeight(.medium)
                            }
                        }
                        .font(.subheadline)

                        // Guided shopping button
                        Button {
                            selectedList = activeList
                            showingGuidedShopping = true
                        } label: {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Start Guided Shopping")
                                        .fontWeight(.medium)
                                    Text("Voice-guided, section by section")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Brand.herbGreen)
                            }
                        }
                    } header: {
                        Text(activeList.name)
                    }

                    // Items grouped by store section
                    ForEach(StoreSection.allCases, id: \.self) { section in
                        let sectionItems = activeList.items.filter { $0.storeSection == section }
                        if !sectionItems.isEmpty {
                            Section {
                                ForEach(sectionItems) { item in
                                    ShoppingItemRow(item: item)
                                }
                            } header: {
                                HStack {
                                    Text(section.displayName)
                                    Spacer()
                                    let purchased = sectionItems.filter(\.isPurchased).count
                                    Text("\(purchased)/\(sectionItems.count)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Other lists
                    if lists.count > 1 {
                        Section("Previous Lists") {
                            ForEach(lists.dropFirst()) { list in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(list.name)
                                            .fontWeight(.medium)
                                        Text(list.dateCreated, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(Int(list.progress * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        listToDelete = list
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if lists.isEmpty {
                    ContentUnavailableView(
                        "No Shopping Lists",
                        systemImage: "cart",
                        description: Text("Generate a list from your meal plan or create one manually.")
                    )
                }
            }
            .navigationTitle("Shopping")
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingReceiptScanner = true
                    } label: {
                        Image(systemName: "doc.text.viewfinder")
                    }
                    .accessibilityLabel("Scan Receipt")

                    Button("New List", systemImage: "plus") {
                        showingCreateList = true
                    }
                }
            }
            .confirmationDialog(
                "Delete List",
                isPresented: .init(
                    get: { listToDelete != nil },
                    set: { if !$0 { listToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let list = listToDelete {
                        modelContext.delete(list)
                        listToDelete = nil
                    }
                }
            } message: {
                Text("Delete \"\(listToDelete?.name ?? "")\"? This cannot be undone.")
            }
            .sheet(isPresented: $showingCreateList) {
                CreateShoppingListView()
            }
            .fullScreenCover(isPresented: $showingGuidedShopping) {
                if let list = selectedList {
                    GuidedShoppingView(list: list)
                }
            }
            .sheet(isPresented: $showingReceiptScanner) {
                ReceiptScannerView()
            }
        }
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        HStack {
            Button {
                withAnimation {
                    item.isPurchased.toggle()
                }
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: item.isPurchased)
            .accessibilityLabel(item.isPurchased ? "\(item.name), purchased" : "\(item.name), not purchased")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.isPurchased)
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)
                    .fontWeight(item.isPurchased ? .regular : .medium)

                Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let sub = item.substituteFor {
                    Label("Substituting: \(sub)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(Brand.warmTan)
                }

                if let notes = item.notes {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let price = item.estimatedPrice {
                Text(price, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Create Shopping List View

struct CreateShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("List Name", text: $name)
            }
            .navigationTitle("New Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let list = GroceryList(name: name.isEmpty ? "Shopping List" : name)
                        modelContext.insert(list)
                        dismiss()
                    }
                }
            }
        }
    }
}
