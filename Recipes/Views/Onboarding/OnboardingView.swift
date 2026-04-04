import SwiftUI
import SwiftData

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter

    @State private var step: OnboardingStep = .welcome
    @State private var name = ""
    @State private var selectedCuisines: Set<Cuisine> = []
    @State private var selectedRestrictions: Set<DietaryRestriction> = []
    @State private var pantryIngredients: [String] = []
    @State private var showingKitchenEditor = false
    @State private var newIngredient = ""
    @FocusState private var newIngredientFocused: Bool
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isFinishing = false

    private enum OnboardingStep: Int, CaseIterable {
        case welcome, style, table, kitchen
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Brand.midnight.ignoresSafeArea()

            VStack(spacing: 0) {
                stepDots
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                Group {
                    switch step {
                    case .welcome:  welcomeStep
                    case .style:    styleStep
                    case .table:    tableStep
                    case .kitchen:  kitchenStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? Brand.herbGreen : Brand.muted.opacity(0.3))
                    .frame(width: s == step ? 20 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.4), value: step)
    }

    // MARK: - Navigation Helpers

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch step {
            case .welcome:  step = .style
            case .style:    step = .table
            case .table:
                // Pre-compute pantry ingredients from cuisine picks before showing kitchen
                pantryIngredients = PantryStarterKit.ingredients(for: Array(selectedCuisines)).map(\.name)
                step = .kitchen
            case .kitchen:
                finish()
            }
        }
    }

    // MARK: - Screen 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(Brand.herbGreen)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("Welcome to Mise")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Brand.cream)
                    Text("Your kitchen, your way.\nLet's get you set up.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Brand.muted)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What should we call you?")
                        .font(.caption)
                        .foregroundStyle(Brand.muted)
                        .padding(.horizontal, 4)
                    TextField("Your name (optional)", text: $name)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Brand.cream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 14))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }
                .padding(.horizontal, 32)

                continueButton(label: "Get started") { advance() }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Screen 2: Your Style

    private var styleStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "What do you love to cook?",
                subtitle: "Pick any that feel like you. This seeds your pantry and shapes what you get suggested."
            )

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(Cuisine.allCases.filter { $0 != .other }, id: \.self) { cuisine in
                        cuisineTile(cuisine)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            bottomButtons(
                continueLabel: selectedCuisines.isEmpty ? "Skip for now" : "Continue",
                onContinue: { advance() }
            )
        }
    }

    private func cuisineTile(_ cuisine: Cuisine) -> some View {
        let selected = selectedCuisines.contains(cuisine)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if selected { selectedCuisines.remove(cuisine) }
                else { selectedCuisines.insert(cuisine) }
            }
        } label: {
            HStack(spacing: 10) {
                Text(cuisine.onboardingEmoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(cuisine.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(selected ? Brand.midnight : Brand.cream)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.midnight)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(selected ? Brand.herbGreen : Brand.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.clear : Brand.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cuisine.displayName)\(selected ? ", selected" : "")")
        .accessibilityHint(selected ? "Double tap to deselect" : "Double tap to select")
    }

    // MARK: - Screen 3: Your Table

    private var tableStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "Any dietary needs?",
                subtitle: "These filter your recipe suggestions and shape what gets generated."
            )

            ScrollView {
                // "None" clear button
                if !selectedRestrictions.isEmpty {
                    Button {
                        withAnimation { selectedRestrictions.removeAll() }
                    } label: {
                        Label("Clear all", systemImage: "xmark.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Brand.muted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                FlowLayout(spacing: 10) {
                    // "None" chip — prominent if nothing is selected
                    let noneSelected = selectedRestrictions.isEmpty
                    Button {
                        withAnimation { selectedRestrictions.removeAll() }
                    } label: {
                        Text("None")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(noneSelected ? Brand.midnight : Brand.cream)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(noneSelected ? Brand.herbGreen : Brand.surface, in: Capsule())
                            .overlay(Capsule().stroke(noneSelected ? Color.clear : Brand.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("None\(noneSelected ? ", selected" : "")")

                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        let selected = selectedRestrictions.contains(restriction)
                        Button {
                            withAnimation {
                                if selected { selectedRestrictions.remove(restriction) }
                                else { selectedRestrictions.insert(restriction) }
                            }
                        } label: {
                            Text(restriction.displayName)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(selected ? Brand.midnight : Brand.cream)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selected ? Brand.herbGreen : Brand.surface, in: Capsule())
                                .overlay(Capsule().stroke(selected ? Color.clear : Brand.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(restriction.displayName)\(selected ? ", selected" : "")")
                        .accessibilityHint(selected ? "Double tap to deselect" : "Double tap to select")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            bottomButtons(
                continueLabel: "Continue",
                onContinue: { advance() }
            )
        }
    }

    // MARK: - Screen 4: Your Kitchen

    private var kitchenStep: some View {
        VStack(spacing: 0) {
            // Always show the editor when there's nothing to preview,
            // so the screen never looks broken/empty.
            if pantryIngredients.isEmpty || showingKitchenEditor {
                kitchenEditor
            } else {
                kitchenPreview
            }
        }
    }

    private var kitchenPreview: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "Your Kitchen",
                subtitle: "Based on your picks, we'd add these staples to your pantry."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Ingredient preview list
                    VStack(spacing: 0) {
                        ForEach(Array(pantryIngredients.enumerated()), id: \.offset) { index, item in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(Brand.herbGreen)
                                    .accessibilityHidden(true)
                                Text(item)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(Brand.cream)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            if index < pantryIngredients.count - 1 {
                                Divider().overlay(Brand.border).padding(.horizontal, 20)
                            }
                        }
                    }
                    .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
            }

            VStack(spacing: 12) {
                continueButton(label: "Add \(pantryIngredients.count) items to my pantry") {
                    advance()
                }

                Button {
                    withAnimation { showingKitchenEditor = true }
                } label: {
                    Text("Let me adjust first")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Brand.muted)
                }
                .buttonStyle(.plain)

                skipLink { finish() }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }

    private var kitchenEditor: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "Your Kitchen",
                subtitle: pantryIngredients.isEmpty
                    ? "What do you keep stocked? Add ingredients by typing or use the mic."
                    : "Remove anything you don't have. Add anything we missed."
            )

            // Chips
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(pantryIngredients, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .foregroundStyle(Brand.cream)
                            Button {
                                withAnimation { pantryIngredients.removeAll { $0 == item } }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Brand.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item)")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Brand.surface, in: Capsule())
                        .overlay(Capsule().stroke(Brand.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            // Add row
            HStack(spacing: 10) {
                TextField("Add an ingredient…", text: $newIngredient)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Brand.cream)
                    .focused($newIngredientFocused)
                    .submitLabel(.done)
                    .onSubmit { addTypedIngredient() }

                // Mic button
                Button {
                    Task {
                        if speechRecognizer.isListening {
                            speechRecognizer.stop()
                            applyMicTranscript(speechRecognizer.transcript)
                            speechRecognizer.transcript = ""
                        } else {
                            speechRecognizer.transcript = ""
                            await speechRecognizer.start()
                            // Auto-apply when silence is detected and it stops
                            if !speechRecognizer.isListening && !speechRecognizer.transcript.isEmpty {
                                applyMicTranscript(speechRecognizer.transcript)
                                speechRecognizer.transcript = ""
                            }
                        }
                    }
                } label: {
                    Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                        .font(.body)
                        .foregroundStyle(speechRecognizer.isListening ? Brand.herbGreen : Brand.muted)
                        .frame(width: 36, height: 36)
                        .background(Brand.surface, in: Circle())
                        .overlay(Circle().stroke(
                            speechRecognizer.isListening ? Brand.herbGreen.opacity(0.5) : Brand.border,
                            lineWidth: 1
                        ))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speechRecognizer.isListening ? "Stop listening" : "Add by voice")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Brand.surface.opacity(0.6))

            if speechRecognizer.isListening {
                Text("Listening… say items to add, or \"remove olive oil\"")
                    .font(.caption)
                    .foregroundStyle(Brand.herbGreen)
                    .padding(.top, 6)
                    .transition(.opacity)
            } else if let err = speechRecognizer.error {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Brand.spiceRed)
                    .padding(.top, 6)
                    .transition(.opacity)
            }

            VStack(spacing: 12) {
                continueButton(
                    label: pantryIngredients.isEmpty ? "Skip pantry setup" : "Add \(pantryIngredients.count) items to my pantry"
                ) { advance() }

                skipLink { finish() }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
        .onChange(of: speechRecognizer.isListening) { _, isListening in
            // When mic stops, apply the transcript automatically
            if !isListening && !speechRecognizer.transcript.isEmpty {
                applyMicTranscript(speechRecognizer.transcript)
                speechRecognizer.transcript = ""
            }
        }
    }

    // MARK: - Mic Transcript Parsing

    /// Splits the transcript on commas and "and", then adds or removes chips.
    /// Removal triggered by "remove X", "no X", or "without X" prefix.
    private func applyMicTranscript(_ transcript: String) {
        let parts = transcript
            .components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        withAnimation {
            for part in parts {
                let lower = part.lowercased()
                let isRemoval = lower.hasPrefix("remove ")
                    || lower.hasPrefix("no ")
                    || lower.hasPrefix("without ")
                    || lower.hasPrefix("delete ")

                if isRemoval {
                    let target = lower
                        .replacingOccurrences(of: "remove ", with: "")
                        .replacingOccurrences(of: "no ", with: "")
                        .replacingOccurrences(of: "without ", with: "")
                        .replacingOccurrences(of: "delete ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    pantryIngredients.removeAll {
                        $0.lowercased().contains(target) || target.contains($0.lowercased())
                    }
                } else {
                    let capitalised = part.prefix(1).uppercased() + part.dropFirst()
                    if !pantryIngredients.contains(where: { $0.lowercased() == part.lowercased() }) {
                        pantryIngredients.append(capitalised)
                    }
                }
            }
        }
    }

    private func addTypedIngredient() {
        let trimmed = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let capitalised = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !pantryIngredients.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            withAnimation { pantryIngredients.append(capitalised) }
        }
        newIngredient = ""
    }

    // MARK: - Completion

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true

        // 1. Create and persist profile
        let profile = UserProfile(
            displayName: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Chef" : name,
            dietaryRestrictions: Array(selectedRestrictions),
            preferredCuisines: Array(selectedCuisines),
            skillLevel: .intermediate
        )
        modelContext.insert(profile)

        // 2. Seed pantry items as staples
        let starter = PantryStarterKit.ingredients(for: Array(selectedCuisines))
        for item in starter where pantryIngredients.contains(item.name) {
            let pantryItem = PantryItem(
                name: item.name,
                category: item.category,
                quantity: item.quantity,
                unit: item.unit
            )
            pantryItem.isStaple = true
            modelContext.insert(pantryItem)
        }

        // 3. Dismiss the cover first so the user lands in the app immediately
        dismiss()

        // 4. Kick off starter recipe generation — runs on the main actor but suspends
        //    during network calls, so the UI remains fully responsive.
        let cuisinesForGen = Array(selectedCuisines.prefix(3))
        Task { await generateStarterRecipes(cuisines: cuisinesForGen) }
    }

    private func generateStarterRecipes(cuisines: [Cuisine]) async {
        guard !cuisines.isEmpty else { return }
        let service = RecipeIngestionService(aiRouter: aiRouter)
        for cuisine in cuisines {
            let prompt = """
            Generate a classic, satisfying \(cuisine.displayName) recipe that a home cook would love. \
            Choose something iconic and worth making on a weeknight — not too complex, but genuinely delicious. \
            Include precise measurements, clear steps, and estimated nutrition per serving.
            """
            do {
                let result = try await service.ingestFromTextStreaming(prompt) { _ in }
                let recipe = await service.convertToRecipe(result)
                modelContext.insert(recipe)
            } catch {
                // Silent failure — user can generate recipes manually from the Recipes tab
            }
        }
    }

    // MARK: - Shared UI Helpers

    private func stepHeading(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Brand.cream)
            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func continueButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Brand.midnight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Brand.herbGreen, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func bottomButtons(continueLabel: String, onContinue: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            continueButton(label: continueLabel, action: onContinue)
            skipLink(action: onContinue) // tapping skip also advances; only shown as alternate framing
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func skipLink(action: @escaping () -> Void) -> some View {
        if step != .welcome {
            Button(action: action) {
                Text("I'll do this later")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Brand.muted)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Cuisine Display Helpers

private extension Cuisine {
    var displayName: String {
        switch self {
        case .mexican:        return "Mexican"
        case .italian:        return "Italian"
        case .japanese:       return "Japanese"
        case .chinese:        return "Chinese"
        case .indian:         return "Indian"
        case .thai:           return "Thai"
        case .french:         return "French"
        case .korean:         return "Korean"
        case .vietnamese:     return "Vietnamese"
        case .greek:          return "Greek"
        case .mediterranean:  return "Mediterranean"
        case .american:       return "American"
        case .brazilian:      return "Brazilian"
        case .ethiopian:      return "Ethiopian"
        case .moroccan:       return "Moroccan"
        case .turkish:        return "Turkish"
        case .spanish:        return "Spanish"
        case .german:         return "German"
        case .british:        return "British"
        case .other:          return "Other"
        }
    }

    var onboardingEmoji: String {
        switch self {
        case .mexican:        return "🌮"
        case .italian:        return "🍝"
        case .japanese:       return "🍱"
        case .chinese:        return "🥡"
        case .indian:         return "🍛"
        case .thai:           return "🍜"
        case .french:         return "🥐"
        case .korean:         return "🍲"
        case .vietnamese:     return "🫕"
        case .greek:          return "🫒"
        case .mediterranean:  return "🫙"
        case .american:       return "🍔"
        case .brazilian:      return "🥩"
        case .ethiopian:      return "🫓"
        case .moroccan:       return "🥙"
        case .turkish:        return "🫔"
        case .spanish:        return "🥘"
        case .german:         return "🥨"
        case .british:        return "☕️"
        case .other:          return "🍽️"
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, PantryItem.self, Recipe.self], inMemory: true)
        .environment(AIServiceRouter())
}
