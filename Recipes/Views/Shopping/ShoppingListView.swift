import SwiftUI
import SwiftData

// MARK: - Shopping List View

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryList.dateCreated, order: .reverse) private var lists: [GroceryList]

    @State private var showingCreateList = false
    @State private var activeShoppingSession = false
    @State private var voiceService = ShoppingVoiceService()

    var body: some View {
        NavigationStack {
            List {
                if let activeList = lists.first {
                    Section {
                        ProgressView(value: activeList.progress) {
                            Text("\(Int(activeList.progress * 100))% complete")
                        }

                        HStack {
                            LabeledContent("Estimated", value: activeList.totalEstimatedCost, format: .currency(code: "USD"))
                            Spacer()
                            LabeledContent("Actual", value: activeList.totalActualCost, format: .currency(code: "USD"))
                        }
                        .font(.caption)

                        Button {
                            startGuidedShopping(list: activeList)
                        } label: {
                            Label("Start Guided Shopping", systemImage: "waveform")
                        }
                        .tint(.green)
                    } header: {
                        Text(activeList.name)
                    }

                    // Items grouped by store section
                    ForEach(StoreSection.allCases, id: \.self) { section in
                        let sectionItems = activeList.items.filter { $0.storeSection == section }
                        if !sectionItems.isEmpty {
                            Section(section.displayName) {
                                ForEach(sectionItems) { item in
                                    ShoppingItemRow(item: item)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New List", systemImage: "plus") {
                        showingCreateList = true
                    }
                }
            }
            .sheet(isPresented: $showingCreateList) {
                CreateShoppingListView()
            }
        }
    }

    private func startGuidedShopping(list: GroceryList) {
        Task {
            await voiceService.guideShopping(list: list)
        }
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    @Bindable var item: GroceryItem

    var body: some View {
        HStack {
            Button {
                item.isPurchased.toggle()
            } label: {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPurchased ? .green : .secondary)
            }

            VStack(alignment: .leading) {
                Text(item.name)
                    .strikethrough(item.isPurchased)
                    .foregroundStyle(item.isPurchased ? .secondary : .primary)

                Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let sub = item.substituteFor {
                    Text("Substituting: \(sub)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if let price = item.estimatedPrice {
                Text(price, format: .currency(code: "USD"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
