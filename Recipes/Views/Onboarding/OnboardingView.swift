import SwiftUI
import SwiftData

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.aiRouter) private var aiRouter

    @State private var step: OnboardingStep = .welcome
    @State private var name = ""
    @State private var selectedGoal: CookingGoal = .greatFood
    @State private var selectedCuisines: Set<Cuisine> = []
    @State private var selectedRestrictions: Set<DietaryRestriction> = []
    @State private var pantryIngredients: [String] = []
    @State private var newIngredient = ""
    @FocusState private var newIngredientFocused: Bool
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var isParsingMic = false
    @State private var isFinishing = false

    private enum OnboardingStep: Int, CaseIterable {
        case welcome, goals, style, table, kitchen
    }

    /// Cuisines shown in the onboarding picker.
    /// Excludes low-coverage cuisines (.mediterranean, .ethiopian, .british)
    /// but keeps them in the Cuisine enum for backward-compatible recipe tagging.
    private static let onboardingCuisines: [Cuisine] = [
        .american, .brazilian, .chinese, .french, .german,
        .greek, .indian, .italian, .japanese, .korean,
        .mexican, .moroccan, .spanish, .thai, .turkish, .vietnamese
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            Brand.midnight.ignoresSafeArea()

            VStack(spacing: 0) {
                stepDots
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                // TabView gives us swipe-between-pages for free and handles
                // gesture conflicts with child ScrollViews correctly.
                // indexDisplayMode: .never hides the system dots — we render
                // our own animated capsule dots above.
                TabView(selection: $step) {
                    welcomeStep.tag(OnboardingStep.welcome)
                    goalsStep.tag(OnboardingStep.goals)
                    styleStep.tag(OnboardingStep.style)
                    tableStep.tag(OnboardingStep.table)
                    kitchenStep.tag(OnboardingStep.kitchen)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: step)
                // VoiceOver: allow swipe-up/down to advance or go back through steps
                // so users who cannot perform the horizontal swipe can still navigate.
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: advance()
                    case .decrement:
                        switch step {
                        case .welcome:  break
                        case .goals:    step = .welcome
                        case .style:    step = .goals
                        case .table:    step = .style
                        case .kitchen:  step = .table
                        }
                    @unknown default: break
                    }
                }
            }
        }
        // When the user swipes (or the continue button advances) to the kitchen
        // step, pre-populate pantry ingredients from their current picks.
        // Using oldStep == .table means a back-swipe then re-forward-swipe
        // correctly recomputes if cuisine/dietary selections changed.
        .onChange(of: step) { oldStep, newStep in
            // Pre-populate pantry whenever the user arrives at the kitchen step
            // (forward or after changing cuisine/dietary selections mid-flow).
            if newStep == .kitchen && oldStep == .table {
                pantryIngredients = PantryStarterKit.ingredients(
                    for: Array(selectedCuisines),
                    dietaryRestrictions: selectedRestrictions
                ).map(\.name)
            }
        }
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s == step ? Brand.herbGreen : Brand.muted.opacity(0.3))
                    .frame(width: s == step ? 20 : 6, height: 6)
                    .accessibilityHidden(true)
            }
        }
        .animation(.spring(duration: 0.4), value: step)
        // Single accessibility element for the whole dot strip so VoiceOver
        // reads the current progress rather than each individual dot.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    // MARK: - Navigation Helpers

    private func advance() {
        switch step {
        case .welcome:  step = .goals
        case .goals:    step = .style
        case .style:    step = .table
        case .table:    step = .kitchen   // side effect handled by onChange(of: step)
        case .kitchen:  finish()
        }
    }

    // MARK: - Screen 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "house")
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

    // MARK: - Screen 2: Your Goal

    private var goalsStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "What's your goal?",
                subtitle: "This shapes what gets suggested to you."
            )

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(CookingGoal.allCases, id: \.self) { goal in
                        goalCard(goal)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            continueButton(label: "Continue") { advance() }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .padding(.top, 8)
        }
    }

    private func goalCard(_ goal: CookingGoal) -> some View {
        let selected = selectedGoal == goal
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedGoal = goal
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(selected ? Brand.midnight : Brand.cream)
                    Text(goal.description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(selected ? Brand.midnight.opacity(0.7) : Brand.muted)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Brand.midnight : Brand.muted.opacity(0.4))
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(selected ? Brand.herbGreen : Brand.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.clear : Brand.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.title). \(goal.description)")
        .accessibilityHint(selected ? "Selected" : "Double tap to select")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Screen 3: Your Style

    private var styleStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "What do you love to cook?",
                subtitle: "Pick any that feel like you. This seeds your pantry and shapes what you get suggested."
            )

            ScrollView {
                FlowLayout(spacing: 10) {
                    ForEach(Self.onboardingCuisines, id: \.self) { cuisine in
                        cuisineChip(cuisine)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }

            continueButton(label: "Continue") { advance() }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .padding(.top, 8)
        }
    }

    private func cuisineChip(_ cuisine: Cuisine) -> some View {
        let selected = selectedCuisines.contains(cuisine)
        return Button {
            withAnimation(.spring(duration: 0.2)) {
                if selected { selectedCuisines.remove(cuisine) }
                else { selectedCuisines.insert(cuisine) }
            }
        } label: {
            Text(cuisine.displayName)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(selected ? Brand.midnight : Brand.cream)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selected ? Brand.herbGreen : Brand.surface, in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Brand.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cuisine.displayName)\(selected ? ", selected" : "")")
        .accessibilityHint(selected ? "Double tap to deselect" : "Double tap to select")
    }

    // Common intolerances and beliefs — shown by default
    private static let commonRestrictions: [DietaryRestriction] = [
        .vegetarian, .vegan, .pescatarian, .glutenFree, .dairyFree, .nutFree, .halal, .kosher
    ]
    // Lifestyle/protocol diets — hidden under "More options"
    private static let lifestyleRestrictions: [DietaryRestriction] = [
        .keto, .paleo, .whole30, .fodmap, .lowCarb, .lowSodium
    ]

    @State private var showMoreRestrictions = false

    // MARK: - Screen 3: Your Table

    private var tableStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "Any dietary needs?",
                subtitle: "These filter your recipe suggestions and shape what gets generated."
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                        .accessibilityHint(noneSelected ? "Selected" : "Double tap to clear all restrictions")

                        ForEach(Self.commonRestrictions, id: \.self) { restriction in
                            dietaryChip(restriction)
                        }
                    }

                    // "More options" expander for lifestyle/protocol diets
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            withAnimation(.spring(duration: 0.3)) { showMoreRestrictions.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showMoreRestrictions ? "Fewer options" : "More options")
                                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                                    .foregroundStyle(Brand.muted)
                                Image(systemName: showMoreRestrictions ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Brand.muted)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(showMoreRestrictions ? "Double tap to collapse" : "Double tap to show keto, paleo, and more")

                        if showMoreRestrictions {
                            FlowLayout(spacing: 10) {
                                ForEach(Self.lifestyleRestrictions, id: \.self) { restriction in
                                    dietaryChip(restriction)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            continueButton(label: "Continue") { advance() }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .padding(.top, 8)
        }
    }

    private func dietaryChip(_ restriction: DietaryRestriction) -> some View {
        let selected = selectedRestrictions.contains(restriction)
        return Button {
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

    // MARK: - Screen 4: Your Kitchen

    private var kitchenStep: some View {
        VStack(spacing: 0) {
            stepHeading(
                title: "Your Kitchen",
                subtitle: pantryIngredients.isEmpty
                    ? "What do you keep stocked? Add ingredients by typing or use the mic."
                    : "Based on your picks — remove anything you don't have, or add what we missed."
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
                if speechRecognizer.isListening {
                    // Live transcript stream replaces the text field while mic is active
                    Text(speechRecognizer.transcript.isEmpty
                         ? "Listening…"
                         : speechRecognizer.transcript)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(speechRecognizer.transcript.isEmpty ? Brand.muted : Brand.cream)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.default, value: speechRecognizer.transcript)
                } else {
                    TextField("Add an ingredient…", text: $newIngredient)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Brand.cream)
                        .focused($newIngredientFocused)
                        .submitLabel(.done)
                        .onSubmit { addTypedIngredient() }
                }

                // Mic button
                Button {
                    Task {
                        if speechRecognizer.isListening {
                            speechRecognizer.stop()
                            let captured = speechRecognizer.transcript
                            speechRecognizer.transcript = ""
                            await parseAndApplyTranscript(captured)
                        } else {
                            speechRecognizer.transcript = ""
                            await speechRecognizer.start()
                            // Auto-apply when silence is detected and it stops
                            if !speechRecognizer.isListening && !speechRecognizer.transcript.isEmpty {
                                let captured = speechRecognizer.transcript
                                speechRecognizer.transcript = ""
                                await parseAndApplyTranscript(captured)
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

            if isParsingMic {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(Brand.herbGreen)
                    Text("Working out what you said…")
                        .font(.caption)
                        .foregroundStyle(Brand.herbGreen)
                }
                .padding(.top, 6)
                .transition(.opacity)
            } else if speechRecognizer.isListening {
                Text("Tap the mic to stop, or wait for a pause")
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
                    label: pantryIngredients.isEmpty
                        ? "Continue without pantry"
                        : "Add \(pantryIngredients.count) items to my pantry"
                ) { advance() }

                if !pantryIngredients.isEmpty {
                    skipLink { finish() }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
            .padding(.top, 8)
        }
        .onChange(of: speechRecognizer.isListening) { _, isListening in
            // When mic auto-stops on silence, parse the transcript
            if !isListening && !speechRecognizer.transcript.isEmpty {
                let captured = speechRecognizer.transcript
                speechRecognizer.transcript = ""
                Task { await parseAndApplyTranscript(captured) }
            }
        }
    }

    // MARK: - Mic Transcript Parsing

    /// AI-powered parsing: sends the raw transcript to the model to extract
    /// individual ingredient names, then adds/removes chips. Falls back to
    /// regex splitting if the AI call fails.
    private func parseAndApplyTranscript(_ transcript: String) async {
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isParsingMic = true
        defer { isParsingMic = false }

        let prompt = """
        The user spoke a list of pantry ingredients. Extract each individual ingredient name.
        Normalize names (e.g. "some eggs" → "Eggs", "ripe tomatoes" → "Tomatoes", "my tea" → "Tea").
        Also handle removal commands: "remove X", "no X", "without X", "delete X" → mark as remove.
        Input: "\(transcript.sanitizedForAI)"
        Return ONLY a JSON array of objects, no explanation:
        [{"action":"add","name":"Tea"},{"action":"add","name":"Bananas"},{"action":"remove","name":"Olive Oil"}]
        """

        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .classification)
            if let start = response.firstIndex(of: "["),
               let end = response.lastIndex(of: "]"),
               let data = String(response[start...end]).data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                withAnimation {
                    for item in array {
                        guard let name = item["name"] as? String, !name.isEmpty else { continue }
                        let action = item["action"] as? String ?? "add"
                        if action == "remove" {
                            let target = name.lowercased()
                            pantryIngredients.removeAll {
                                $0.lowercased().contains(target) || target.contains($0.lowercased())
                            }
                        } else {
                            let capitalised = name.prefix(1).uppercased() + name.dropFirst()
                            if !pantryIngredients.contains(where: { $0.lowercased() == name.lowercased() }) {
                                pantryIngredients.append(capitalised)
                            }
                        }
                    }
                }
                return
            }
        } catch { /* fall through to regex fallback */ }

        // Fallback: split on commas, "and", newlines
        fallbackApplyTranscript(transcript)
    }

    /// Regex-based fallback for when the AI is unavailable.
    private func fallbackApplyTranscript(_ transcript: String) {
        let parts = transcript
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
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
                    if !pantryIngredients.contains(where: { $0.lowercased() == lower }) {
                        pantryIngredients.append(capitalised)
                    }
                }
            }
        }
    }

    private func addTypedIngredient() {
        let raw = newIngredient.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        newIngredient = ""

        // If the input contains commas or "and", it's explicitly a list — use AI to parse.
        // Single-word input is added directly with no round-trip.
        let looksLikeList = raw.contains(",") || raw.lowercased().contains(" and ")
            || raw.components(separatedBy: " ").count > 2

        if looksLikeList {
            Task { await parseAndApplyTranscript(raw) }
        } else {
            // Single item (e.g. "Milk" or "Yellow onion") — add immediately
            let capitalised = raw.prefix(1).uppercased() + raw.dropFirst()
            withAnimation {
                if !pantryIngredients.contains(where: { $0.lowercased() == raw.lowercased() }) {
                    pantryIngredients.append(capitalised)
                }
            }
        }
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
        profile.cookingGoal = selectedGoal
        modelContext.insert(profile)

        // 2. Seed pantry items as staples.
        // Build a set of already-existing pantry item names so we never create
        // a duplicate, even if the user somehow reaches finish() twice or has
        // manually added items beforehand.
        let existingNames: Set<String>
        if let existing = try? modelContext.fetch(FetchDescriptor<PantryItem>()) {
            existingNames = Set(existing.map { $0.name.lowercased() })
        } else {
            existingNames = []
        }

        // Normalise the user-edited ingredient list to lowercase for matching,
        // eliminating any case-variation duplicates the editor may have allowed.
        let wantedNames = Set(pantryIngredients.map { $0.lowercased() })

        let starter = PantryStarterKit.ingredients(
            for: Array(selectedCuisines),
            dietaryRestrictions: selectedRestrictions
        )
        for item in starter
            where wantedNames.contains(item.name.lowercased())
               && !existingNames.contains(item.name.lowercased()) {
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
        let restrictionsForGen = selectedRestrictions
        Task { await generateStarterRecipes(cuisines: cuisinesForGen, restrictions: restrictionsForGen) }
    }

    private func generateStarterRecipes(cuisines: [Cuisine], restrictions: Set<DietaryRestriction>) async {
        guard !cuisines.isEmpty else { return }
        let service = RecipeIngestionService(aiRouter: aiRouter)

        // Build a dietary constraint clause once — empty if no restrictions.
        let dietaryClause: String
        if restrictions.isEmpty {
            dietaryClause = ""
        } else {
            let labels = restrictions.map(\.displayName).sorted().joined(separator: ", ")
            dietaryClause = " The recipe must be \(labels). Do not include any ingredients that conflict with these requirements."
        }

        for cuisine in cuisines {
            let prompt = """
            Generate a classic, satisfying \(cuisine.displayName) recipe that a home cook would love. \
            Choose something iconic and worth making on a weeknight — not too complex, but genuinely delicious. \
            Include precise measurements, clear steps, and estimated nutrition per serving.\(dietaryClause)
            """
            do {
                let result = try await service.ingestFromTextStreaming(prompt, isGeneration: true) { _ in }
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

    @ViewBuilder
    private func skipLink(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Skip pantry setup")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Brand.muted)
        }
        .buttonStyle(.plain)
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

}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(for: [UserProfile.self, PantryItem.self, Recipe.self], inMemory: true)
        .environment(\.aiRouter, AIServiceRouter())
}
