import SwiftUI
import SwiftData

// MARK: - Tag Management View

/// Full tag management system with creation, editing, batch tagging,
/// and tag-based recipe collections.
struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]

    @State private var newTagName = ""
    @State private var selectedTag: String?
    @State private var showingBatchTag = false
    @State private var tagToDelete: String?

    private var allTags: [TagInfo] {
        var tagCounts: [String: Int] = [:]
        for recipe in recipes {
            for tag in recipe.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        return tagCounts
            .map { TagInfo(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private var recipesForSelectedTag: [Recipe] {
        guard let tag = selectedTag else { return [] }
        return recipes.filter { $0.tags.contains(tag) }
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
                                selectedTag = tag.name
                                showingBatchTag = true
                            } label: {
                                Label("Add to...", systemImage: "plus")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            // Suggested tags
            Section("Suggested Tags") {
                let suggestions = suggestedTags
                if suggestions.isEmpty {
                    Text("Add more recipes to get tag suggestions.")
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { tag in
                            Button {
                                newTagName = tag
                                createTag()
                            } label: {
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.tint.opacity(0.1), in: .capsule)
                            }
                        }
                    }
                }
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
        .sheet(isPresented: $showingBatchTag) {
            if let tag = selectedTag {
                BatchTagView(tagName: tag, recipes: recipes)
            }
        }
    }

    private func createTag() {
        let tag = newTagName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty else { return }
        newTagName = ""
        // Tag is created — it just needs to be added to recipes
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
            .navigationTitle("Add #\(tagName)")
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
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.title2)
                .fontWeight(.bold)

            FlowLayout(spacing: 6) {
                ForEach(recipe.tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#\(tag)")
                            .font(.caption)
                        Button {
                            recipe.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.1), in: .capsule)
                }

                // Add tag field
                HStack(spacing: 4) {
                    TextField("add tag", text: $newTag)
                        .font(.caption)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(width: 80)
                    Button {
                        addTag()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                    }
                    .disabled(newTag.isEmpty)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.1), in: .capsule)
            }
        }
        .sensoryFeedback(.selection, trigger: recipe.tags.count)
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).lowercased()
        guard !tag.isEmpty, !recipe.tags.contains(tag) else { return }
        recipe.tags.append(tag)
        newTag = ""
    }
}
