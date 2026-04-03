import SwiftUI
import SwiftData

// MARK: - Tag Management View

/// Full tag management system with creation, editing, batch tagging,
/// and tag-based recipe collections.
struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @State private var newTagName = ""
    @State private var selectedTag: TagSelection?
    @State private var tagToDelete: String?
    @State private var cachedAllTags: [TagInfo] = []

    private struct TagSelection: Identifiable {
        let id = UUID()
        let name: String
    }

    private var allTags: [TagInfo] { cachedAllTags }

    private func rebuildAllTags() {
        var tagCounts: [String: Int] = [:]
        for recipe in recipes {
            let normalized = Set(recipe.tags.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            for tag in normalized where !tag.isEmpty {
                tagCounts[tag, default: 0] += 1
            }
        }
        cachedAllTags = tagCounts
            .map { TagInfo(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var recipesForSelectedTag: [Recipe] {
        guard let tag = selectedTag else { return [] }
        return recipes.filter { $0.tags.contains(tag.name) }
    }

    var body: some View {
        List {
            // Create tag
            Section {
                HStack {
                    TextField("New tag name...", text: $newTagName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Create") {
                        createTag()
                    }
                    .disabled(newTagName.isEmpty)
                }
            } header: {
                Text("Create Tag")
            } footer: {
                Text("Tags help you organize recipes into custom collections like \"weeknight dinners\" or \"meal prep\".")
            }

            // All tags
            Section("Your Tags (\(allTags.count))") {
                if allTags.isEmpty {
                    Text("No tags yet. Create one above or add tags to recipes.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allTags) { tag in
                        NavigationLink {
                            TagDetailView(tagName: tag.name, recipes: recipesForTag(tag.name))
                        } label: {
                            HStack {
                                Image(systemName: "tag")
                                    .foregroundStyle(.tint)
                                Text(tag.name)
                                Spacer()
                                Text("\(tag.count) recipe\(tag.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                tagToDelete = tag.name
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                selectedTag = TagSelection(name: tag.name)
                            } label: {
                                Label("Add to...", systemImage: "plus")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            // Suggested tags
            Section {
                let suggestions = suggestedTags
                if suggestions.isEmpty {
                    Text("You've used all the suggested tags.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { tag in
                                Button {
                                    selectedTag = TagSelection(name: tag)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .semibold))
                                        Text(tag)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.tint.opacity(0.1), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.trailing, 16)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Suggested Tags")
            } footer: {
                Text("Tap a suggestion to choose which of your recipes it applies to.")
            }
        }
        .navigationTitle("Tags")
        .toolbarBackground(.automatic, for: .navigationBar)
        .confirmationDialog(
            "Delete Tag",
            isPresented: .init(
                get: { tagToDelete != nil },
                set: { if !$0 { tagToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let tag = tagToDelete {
                    removeTagFromAll(tag)
                    tagToDelete = nil
                }
            }
        } message: {
            Text("Remove the tag \"\(tagToDelete ?? "")\" from all recipes?")
        }
        .sheet(item: $selectedTag) { selection in
            BatchTagView(tagName: selection.name, recipes: recipes)
        }
        .onAppear { Task { rebuildAllTags() } }
        .onChange(of: recipes.count) { rebuildAllTags() }
    }

    private func createTag() {
        let tag = newTagName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty else { return }
        // Tags live on recipes — open batch tagger so user can apply it immediately
        selectedTag = TagSelection(name: tag)
        newTagName = ""
    }

    private func removeTagFromAll(_ tag: String) {
        for recipe in recipes {
            recipe.tags.removeAll { $0 == tag }
        }
    }

    private func recipesForTag(_ tag: String) -> [Recipe] {
        recipes.filter { $0.tags.contains(tag) }
    }

    private var suggestedTags: [String] {
        let existing = Set(allTags.map(\.name))
        let suggestions = [
            "weeknight dinner", "meal prep", "date night", "quick lunch",
            "comfort food", "healthy", "party", "holiday", "kid friendly",
            "one pot", "slow cooker", "air fryer", "grilling", "baking",
            "breakfast favorite", "side dish", "appetizer", "dessert"
        ]
        return suggestions.filter { !existing.contains($0) }
    }
}

struct TagInfo: Identifiable {
    var id: String { name }
    let name: String
    let count: Int
}

// MARK: - Tag Detail View

struct TagDetailView: View {
    let tagName: String
    let recipes: [Recipe]

    var body: some View {
        List {
            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        recipe.tags.removeAll { $0 == tagName }
                    } label: {
                        Label("Remove Tag", systemImage: "tag.slash")
                    }
                }
            }
        }
        .navigationTitle("#\(tagName)")
    }
}

// MARK: - Batch Tag View

struct BatchTagView: View {
    let tagName: String
    let recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipeIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(recipes) { recipe in
                    let isTagged = recipe.tags.contains(tagName)
                    let isSelected = selectedRecipeIDs.contains(recipe.id)

                    Button {
                        if isSelected {
                            selectedRecipeIDs.remove(recipe.id)
                        } else {
                            selectedRecipeIDs.insert(recipe.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: (isTagged || isSelected) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isTagged ? .green : isSelected ? .blue : .secondary)
                            VStack(alignment: .leading) {
                                Text(recipe.title)
                                    .foregroundStyle(.primary)
                                if isTagged {
                                    Text("Already tagged")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .disabled(isTagged)
                }
            }
            .navigationTitle("Tag as \"\(tagName)\"")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply (\(selectedRecipeIDs.count))") {
                        applyTag()
                        dismiss()
                    }
                    .disabled(selectedRecipeIDs.isEmpty)
                }
            }
        }
    }

    private func applyTag() {
        for recipe in recipes where selectedRecipeIDs.contains(recipe.id) {
            if !recipe.tags.contains(tagName) {
                recipe.tags.append(tagName)
            }
        }
    }
}

// MARK: - Recipe Tag Editor (inline in RecipeDetailView)

struct RecipeTagEditorView: View {
    @Bindable var recipe: Recipe
    @Query(sort: \Recipe.dateModified, order: .reverse) private var allRecipes: [Recipe]
    @State private var newTag = ""
    @State private var cachedExistingTags: [String] = []
    @FocusState private var fieldFocused: Bool

    /// Filtered suggestions — existing tags that match what's being typed.
    private var suggestions: [String] {
        guard !newTag.isEmpty else { return cachedExistingTags }
        let q = newTag.lowercased()
        return cachedExistingTags.filter { $0.contains(q) }
    }

    private func rebuildExistingTags() {
        let recipeTags = Set(recipe.tags)
        var seen = Set<String>()
        var result: [String] = []
        for r in allRecipes {
            for tag in r.tags where !recipeTags.contains(tag) && seen.insert(tag).inserted {
                result.append(tag)
            }
        }
        cachedExistingTags = result.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.title2)
                .fontWeight(.bold)

            // Current tags
            if !recipe.tags.isEmpty {
                WrappingLayout(itemSpacing: 6, rowSpacing: 6) {
                    ForEach(recipe.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                withAnimation { recipe.tags.removeAll { $0 == tag } }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Brand.herbGreen.opacity(0.15), in: .capsule)
                    }
                }
            }

            // Input row
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Add a tag…", text: $newTag)
                    .font(.subheadline)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($fieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addTag() }
                if !newTag.isEmpty {
                    Button(action: addTag) {
                        Image(systemName: "return")
                            .font(.caption)
                            .foregroundStyle(Brand.herbGreen)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))

            // Suggestions — existing tags from your library, or new one to create
            if !suggestions.isEmpty || !newTag.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    let trimmed = newTag.lowercased().trimmingCharacters(in: .whitespaces)
                    if !newTag.isEmpty && !cachedExistingTags.contains(trimmed) {
                        suggestionButton(label: "Create \"\(trimmed)\"", isNew: true) {
                            addTag()
                        }
                    }
                    ForEach(suggestions.prefix(6), id: \.self) { tag in
                        suggestionButton(label: "#\(tag)", isNew: false) {
                            applyExisting(tag)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .sensoryFeedback(.selection, trigger: recipe.tags.count)
        .onAppear { Task { rebuildExistingTags() } }
        .onChange(of: allRecipes.count) { rebuildExistingTags() }
        .onChange(of: recipe.tags.count) { rebuildExistingTags() }
    }

    @ViewBuilder
    private func suggestionButton(label: String, isNew: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isNew ? "plus.circle" : "tag")
                    .font(.caption)
                    .foregroundStyle(isNew ? Brand.herbGreen : .secondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !recipe.tags.contains(tag) else { newTag = ""; return }
        withAnimation { recipe.tags.append(tag) }
        newTag = ""
    }

    private func applyExisting(_ tag: String) {
        guard !recipe.tags.contains(tag) else { return }
        withAnimation { recipe.tags.append(tag) }
        newTag = ""
    }
}
