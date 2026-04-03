import SwiftUI
import SwiftData

// MARK: - Shopping List View

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Environment(RemindersSync.self) private var remindersSync
    @Query(sort: \GroceryList.dateCreated, order: .reverse) private var lists: [GroceryList]
    @Query private var profiles: [UserProfile]
    @Query private var pantryItems: [PantryItem]

    @State private var showingAddItem = false
    @State private var showingGuidedShopping = false
    @State private var showingRemindersSetup = false
    @State private var lastSyncDate: Date = .distantPast
    @AppStorage("shoppingHideCompleted") private var hideCompleted = true

    private var currencyCode: String { profiles.first?.preferredCurrencyCode ?? "CAD" }

    /// Always the single persistent list. Created on appear if absent.
    private var list: GroceryList? { lists.first }

    var body: some View {
        NavigationStack {
            Group {
                if let list {
                    if list.items.isEmpty {
                        emptyState
                    } else {
                        listContent(list)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("Shopping")
            .toolbar { toolbar }
            .sheet(isPresented: $showingAddItem) {
                if let list {
                    AddShoppingItemView(list: list)
                }
            }
            .fullScreenCover(isPresented: $showingGuidedShopping) {
                if let list { GuidedShoppingView(list: list) }
            }
            .sheet(isPresented: $showingRemindersSetup) {
                RemindersSetupView(sync: remindersSync, groceryList: list)
            }
        }
        .onAppear {
            ensureListExists()
            // Sync on first appear only — foreground notification handles subsequent syncs
            if lastSyncDate == .distantPast {
                triggerSync()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            triggerSync()
        }
    }

    private func triggerSync() {
        guard let list else { return }
        // Throttle: don't sync more than once every 30 seconds
        guard Date().timeIntervalSince(lastSyncDate) > 30 else { return }
        lastSyncDate = Date()
        Task {
            // Short pause so tab-switch animations finish and the user can
            // navigate away before the sync holds the main actor
            try? await Task.sleep(for: .milliseconds(600))
            await remindersSync.sync(groceryList: list, context: modelContext)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
            Text("Your list is empty")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add items, or generate a list from your meal plan.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                ensureListExists()
                showingAddItem = true
            } label: {
                Label("Add Item", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.herbGreen)
            .padding(.top, 8)

            if !remindersSync.isLinked {
                Button {
                    showingRemindersSetup = true
                } label: {
                    Label("Sync with Reminders", systemImage: "checklist.unchecked")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private func listContent(_ list: GroceryList) -> some View {
        let allItems     = list.items
        let purchased    = allItems.filter(\.isPurchased)
        let remaining    = allItems.filter { !$0.isPurchased }
        let visibleItems = hideCompleted ? remaining : allItems
        let grouped      = Dictionary(grouping: visibleItems, by: \.storeSection)

        List {
            // Progress header
            Section {
                ProgressView(value: list.progress) {
                    HStack {
                        if hideCompleted && !purchased.isEmpty {
                            Text("\(remaining.count) remaining")
                            Spacer()
                            Text("\(purchased.count) hidden")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(Int(list.progress * 100))% complete")
                            Spacer()
                            Text("\(purchased.count)/\(allItems.count) items")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
                .tint(Brand.herbGreen)

                if !remaining.isEmpty {
                    Button {
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
                }
            }

            // Items grouped by store section
            ForEach(StoreSection.allCases, id: \.self) { section in
                let sectionItems = grouped[section] ?? []
                if !sectionItems.isEmpty {
                    Section {
                        ForEach(sectionItems) { item in
                            ShoppingItemRow(
                                item: item,
                                currencyCode: currencyCode,
                                onCheck: { addToPantryIfNeeded($0) },
                                onUncheck: { removeFromPantryIfPresent($0) }
                            )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        let rid = item.remindersIdentifier
                                        list.items.removeAll { $0.persistentModelID == item.persistentModelID }
                                        modelContext.delete(item)
                                        Task { remindersSync.completeReminderByID(rid) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(section.displayName)
                            Spacer()
                            let done = sectionItems.filter(\.isPurchased).count
                            Text("\(done)/\(sectionItems.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Clear completed — only visible when there are checked items
            if !purchased.isEmpty {
                Section {
                    Button(role: .destructive) {
                        let rids = purchased.map(\.remindersIdentifier)
                        let ids = Set(purchased.map(\.persistentModelID))
                        withAnimation {
                            list.items.removeAll { ids.contains($0.persistentModelID) }
                            purchased.forEach { modelContext.delete($0) }
                        }
                        Task { rids.forEach { remindersSync.completeReminderByID($0) } }
                    } label: {
                        Label(
                            "Clear \(purchased.count) Completed \(purchased.count == 1 ? "Item" : "Items")",
                            systemImage: "trash"
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showingRemindersSetup = true
            } label: {
                if remindersSync.isSyncing {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: remindersSync.isLinked ? "checklist" : "checklist.unchecked")
                        .foregroundStyle(remindersSync.isLinked ? Brand.herbGreen : .secondary)
                }
            }
            .accessibilityLabel(remindersSync.isLinked ? "Reminders synced" : "Set up Reminders sync")

            Button {
                hideCompleted.toggle()
            } label: {
                Image(systemName: hideCompleted ? "eye.slash" : "eye")
            }
            .accessibilityLabel(hideCompleted ? "Show completed items" : "Hide completed items")

            Button {
                ensureListExists()
                showingAddItem = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Helpers

    private func addToPantryIfNeeded(_ item: GroceryItem) {
        guard let category = item.storeSection.pantryCategory else { return }
        // Don't add if already linked to a pantry item from a previous check-off.
        guard item.linkedPantryItemID == nil else { return }
        let pantryItem = PantryItem(
            name: item.name,
            category: category,
            quantity: item.quantity,
            unit: item.unit
        )
        modelContext.insert(pantryItem)
        item.linkedPantryItemID = pantryItem.id
    }

    private func removeFromPantryIfPresent(_ item: GroceryItem) {
        guard let linkedID = item.linkedPantryItemID else { return }
        if let pantryItem = pantryItems.first(where: { $0.id == linkedID }) {
            modelContext.delete(pantryItem)
        }
        item.linkedPantryItemID = nil
    }

    private func ensureListExists() {
        guard lists.isEmpty else { return }
        modelContext.insert(GroceryList(name: "Shopping List"))
    }
}

// MARK: - Shopping Item Row

struct ShoppingItemRow: View {
    @Bindable var item: GroceryItem
    @Environment(RemindersSync.self) private var remindersSync
    var currencyCode: String = "CAD"
    var onCheck: (GroceryItem) -> Void = { _ in }
    var onUncheck: (GroceryItem) -> Void = { _ in }

    var body: some View {
        HStack {
            Button {
                withAnimation {
                    if !item.isPurchased {
                        onCheck(item)
                    } else {
                        onUncheck(item)
                    }
                    item.isPurchased.toggle()
                    remindersSync.pushCompletion(for: item)
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
                HStack(spacing: 4) {
                    Text(item.name)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? .secondary : .primary)
                        .fontWeight(item.isPurchased ? .regular : .medium)

                    if item.isStaple {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Brand.warmTan)
                            .accessibilityLabel("Staple item")
                    }
                }

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

            VStack(alignment: .trailing, spacing: 2) {
                if let actual = item.actualPrice {
                    Text(actual, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(Brand.herbGreen)
                        .monospacedDigit()
                }
                if let price = item.estimatedPrice {
                    Text(price, format: .currency(code: currencyCode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .strikethrough(item.actualPrice != nil)
                }
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading) {
            Button {
                withAnimation { item.isStaple.toggle() }
            } label: {
                Label(
                    item.isStaple ? "Remove Staple" : "Mark Staple",
                    systemImage: item.isStaple ? "star.slash" : "star.fill"
                )
            }
            .tint(Brand.warmTan)
        }
    }

}

// MARK: - Add Shopping Item View

struct AddShoppingItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var list: GroceryList

    @State private var name = ""
    @State private var section: StoreSection = .other
    @State private var recentlyAdded: [String] = []
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { addItem() }
                        .onChange(of: name) { _, newName in
                            section = StoreSection.guess(for: newName)
                        }

                    Picker("Section", selection: $section) {
                        ForEach(StoreSection.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                } footer: {
                    Text("Section is set automatically — change it if needed.")
                }

                if !recentlyAdded.isEmpty {
                    Section("Added") {
                        ForEach(recentlyAdded, id: \.self) { itemName in
                            Label(itemName, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: addItem)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func addItem() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Skip duplicates
        let key = trimmed.lowercased()
        guard !list.items.contains(where: { $0.name.lowercased() == key }) else {
            name = ""
            return
        }

        let item = GroceryItem(name: trimmed, quantity: 1, unit: .piece, storeSection: section)
        modelContext.insert(item)
        list.items.append(item)

        recentlyAdded.insert(trimmed, at: 0)
        name = ""
        nameFocused = true
    }
}
