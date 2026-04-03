import SwiftUI

// MARK: - Guided Shopping View

/// Full-screen guided shopping experience with voice interaction,
/// visual progress tracking, and real-time substitution support.
struct GuidedShoppingView: View {
    @Bindable var list: GroceryList
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var voiceService = ShoppingVoiceService()
    @State private var currentSectionIndex = 0
    @State private var currentItemIndex = 0
    @State private var isActive = false
    @State private var isPaused = false
    @State private var showingSubstitution = false
    @State private var substitutionItem: GroceryItem?
    @State private var shoppingTask: Task<Void, Never>?

    private var sortedSections: [(StoreSection, [GroceryItem])] {
        list.itemsBySection
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .filter { !$0.value.allSatisfy(\.isPurchased) }
    }

    private var totalItems: Int {
        list.items.count
    }

    private var purchasedItems: Int {
        list.items.filter(\.isPurchased).count
    }

    private var currentSection: (StoreSection, [GroceryItem])? {
        guard currentSectionIndex < sortedSections.count else { return nil }
        return sortedSections[currentSectionIndex]
    }

    private var hasUnpurchasedItems: Bool {
        !sortedSections.isEmpty
    }

    private var currentItem: GroceryItem? {
        guard let section = currentSection else { return nil }
        let unpurchased = section.1.filter { !$0.isPurchased }
        guard currentItemIndex < unpurchased.count else { return nil }
        return unpurchased[currentItemIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress header
                progressHeader

                Divider()

                if isActive {
                    activeShoppingView
                } else {
                    startView
                }
            }
            .navigationTitle("Guided Shopping")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        shoppingTask?.cancel()
                        voiceService.stopSpeaking()
                        voiceService.stopListening()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSubstitution) {
                if let item = substitutionItem {
                    SubstitutionSheetView(item: item, list: list)
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(purchasedItems), total: Double(totalItems)) {
                HStack {
                    Text("\(purchasedItems) of \(totalItems) items")
                    Spacer()
                    Text("\(Int(list.progress * 100))%")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .tint(Brand.herbGreen)

            if let section = currentSection {
                HStack {
                    Image(systemName: sectionIcon(section.0))
                    Text(section.0.displayName)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(in: .rect)
        .glassEffect(.regular, in: .rect)
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()

            if hasUnpurchasedItems {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Brand.herbGreen)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)

                Text("Ready to Shop")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("I'll guide you section by section through the store. Say \"got it\" when you find an item, or \"can't find\" for substitutions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    startGuidedShopping()
                } label: {
                    Label("Start Voice Shopping", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .tint(Brand.herbGreen)
                .padding(.horizontal, 32)

                Button("Shop Without Voice") {
                    isActive = true
                }
                .font(.subheadline)
            } else {
                Image(systemName: list.items.isEmpty ? "cart" : "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(list.items.isEmpty ? Brand.muted : Brand.herbGreen)
                    .accessibilityHidden(true)

                Text(list.items.isEmpty ? "No Items to Shop" : "All Done!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(list.items.isEmpty
                     ? "This list has no items yet. Add items to your shopping list first."
                     : "Every item on this list has been purchased. Nice work!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Active Shopping View

    private var activeShoppingView: some View {
        VStack(spacing: 0) {
            // Current item card
            if let item = currentItem {
                currentItemCard(item)
            } else {
                // All done in this section or overall
                allDoneView
            }

            Divider()

            // Section items list
            if let section = currentSection {
                List {
                    ForEach(section.1) { item in
                        HStack {
                            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isPurchased ? .green : .secondary)

                            Text(item.name)
                                .strikethrough(item.isPurchased)

                            Spacer()

                            Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Voice status bar
            if voiceService.isListening || voiceService.isSpeaking {
                voiceStatusBar
            }
        }
    }

    private func currentItemCard(_ item: GroceryItem) -> some View {
        VStack(spacing: 16) {
            Text(item.name)
                .font(.title)
                .fontWeight(.bold)

            Text("\(item.quantity, specifier: "%.1f") \(item.unit.rawValue)")
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button {
                    markFound(item)
                } label: {
                    Label("Found It", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .tint(Brand.herbGreen)
                .sensoryFeedback(.success, trigger: item.isPurchased)

                Button {
                    substitutionItem = item
                    showingSubstitution = true
                } label: {
                    Label("Substitute", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)

                Button {
                    skipItem()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .tint(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(in: .rect)
        .glassEffect(.regular, in: .rect)
    }

    private var allDoneView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Brand.herbGreen)
                .accessibilityHidden(true)

            if currentSectionIndex < sortedSections.count - 1 {
                Text("Section Complete!")
                    .font(.title3)
                    .fontWeight(.semibold)

                Button("Next Section") {
                    currentSectionIndex += 1
                    currentItemIndex = 0
                }
                .buttonStyle(.glass)
            } else {
                Text("Shopping Complete!")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("\(purchasedItems) of \(totalItems) items purchased")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("Done") {
                    shoppingTask?.cancel()
                    voiceService.stopSpeaking()
                    voiceService.stopListening()
                    dismiss()
                }
                .buttonStyle(.glass)
                .tint(Brand.herbGreen)
            }
        }
        .padding()
    }

    private var voiceStatusBar: some View {
        HStack {
            if voiceService.isSpeaking {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(Brand.warmTan)
                    .symbolEffect(.variableColor)
                Text("Speaking...")
            } else if voiceService.isListening {
                Image(systemName: "mic.fill")
                    .foregroundStyle(Brand.spiceRed)
                    .symbolEffect(.pulse)
                Text("Listening...")
            }

            Spacer()

            if let heard = voiceService.lastHeardText {
                Text("\"\(heard)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .padding()
        .background(in: .rect)
        .glassEffect(.regular, in: .rect)
    }

    // MARK: - Actions

    private func startGuidedShopping() {
        guard hasUnpurchasedItems else { return }
        isActive = true
        shoppingTask = Task {
            await voiceService.guideShopping(list: list)
        }
    }

    private func markFound(_ item: GroceryItem) {
        item.isPurchased = true
        advanceToNextItem()
    }

    private func skipItem() {
        advanceToNextItem()
    }

    private func advanceToNextItem() {
        guard let section = currentSection else { return }
        let unpurchased = section.1.filter { !$0.isPurchased }

        if currentItemIndex < unpurchased.count - 1 {
            currentItemIndex += 1
        } else {
            // Move to next section
            currentItemIndex = 0
            if currentSectionIndex < sortedSections.count - 1 {
                currentSectionIndex += 1
            }
        }
    }

    private func sectionIcon(_ section: StoreSection) -> String {
        switch section {
        case .produce:       return "leaf"
        case .meat:          return "fork.knife"
        case .seafood:       return "fish"
        case .dairy:         return "cup.and.saucer"
        case .bakery:        return "birthday.cake"
        case .frozen:        return "snowflake"
        case .canned:        return "cylinder"
        case .dryGoods:      return "bag"
        case .spices:        return "sparkle"
        case .condiments:    return "drop"
        case .beverages:     return "waterbottle"
        case .snacks:        return "popcorn"
        case .deli:          return "storefront"
        case .international: return "globe"
        case .other:         return "cart"
        }
    }
}

// MARK: - Substitution Sheet

struct SubstitutionSheetView: View {
    let item: GroceryItem
    @Bindable var list: GroceryList
    @Environment(\.dismiss) private var dismiss

    private var substitutions: [SubstitutionEngine.Substitution] {
        SubstitutionEngine.findSubstitutions(for: item.name)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Substitutions for \(item.name)") {
                    if substitutions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No known substitutions available for \(item.name).")
                                .foregroundStyle(.secondary)
                            Text("Try a similar product at the store, or skip this item for now.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Button("Skip Item") {
                            item.isPurchased = true
                            dismiss()
                        }
                        .foregroundStyle(.orange)
                    } else {
                        ForEach(substitutions, id: \.replacement) { sub in
                            Button {
                                applySubstitution(sub)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sub.replacement)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text("Ratio: \(sub.ratio)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(sub.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Substitutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func applySubstitution(_ sub: SubstitutionEngine.Substitution) {
        // Mark original as purchased with substitution note
        item.isPurchased = true
        item.substituteFor = item.name
        item.name = sub.replacement
        item.notes = "Substituted: \(sub.notes)"
        dismiss()
    }
}
