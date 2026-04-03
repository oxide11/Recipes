import SwiftUI
import SwiftData

// MARK: - Profile Editor View

/// Full profile creation and editing with dietary preferences,
/// skill level, cuisine preferences, and nutritional goals.
struct ProfileEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingProfile: UserProfile?

    @State private var displayName: String
    @State private var skillLevel: RecipeDifficulty
    @State private var measurementSystem: MeasurementSystem
    @State private var hemisphere: Hemisphere
    @State private var dietaryRestrictions: Set<DietaryRestriction>
    @State private var preferredCuisines: Set<Cuisine>
    @State private var dislikedIngredients: String
    @State private var allergens: String
    @State private var maxCookTime: String
    @State private var dailyCalories: String
    @State private var dailyProtein: String
    @State private var weeklyBudget: String

    init(profile: UserProfile? = nil) {
        self.existingProfile = profile
        _displayName = State(initialValue: profile?.displayName ?? "")
        _skillLevel = State(initialValue: profile?.skillLevel ?? .intermediate)
        _measurementSystem = State(initialValue: profile?.measurementSystem ?? .imperial)
        _hemisphere = State(initialValue: profile?.hemisphere ?? .northern)
        _dietaryRestrictions = State(initialValue: Set(profile?.dietaryRestrictions ?? []))
        _preferredCuisines = State(initialValue: Set(profile?.preferredCuisines ?? []))
        _dislikedIngredients = State(initialValue: profile?.dislikedIngredients.joined(separator: ", ") ?? "")
        _allergens = State(initialValue: profile?.allergens.joined(separator: ", ") ?? "")
        _maxCookTime = State(initialValue: profile?.maxCookTimeMinutes.map(String.init) ?? "")
        _dailyCalories = State(initialValue: profile?.dailyCalorieTarget.map(String.init) ?? "")
        _dailyProtein = State(initialValue: profile?.dailyProteinTargetGrams.map(String.init) ?? "")
        _weeklyBudget = State(initialValue: profile?.weeklyGroceryBudget.map { String(format: "%.0f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                aboutYouSection
                dietaryRestrictionsSection
                favoriteCuisinesSection
                avoidAndAllergensSection
                cookingPreferencesSection
                nutritionalGoalsSection
            }
            .navigationTitle(existingProfile == nil ? "Create Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(displayName.isEmpty)
                }
            }
        }
    }

    private var aboutYouSection: some View {
        Section("About You") {
            TextField("Your Name", text: $displayName)
                .textContentType(.name)

            Picker("Cooking Skill Level", selection: $skillLevel) {
                ForEach(RecipeDifficulty.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }

            Picker("Measurement System", selection: $measurementSystem) {
                Text("Imperial (cups, oz, °F)").tag(MeasurementSystem.imperial)
                Text("Metric (ml, g, °C)").tag(MeasurementSystem.metric)
            }

            Picker("Hemisphere", selection: $hemisphere) {
                Text("Northern (Canada, US, Europe…)").tag(Hemisphere.northern)
                Text("Southern (Australia, NZ, S. America…)").tag(Hemisphere.southern)
            }
        }
    }

    private var dietaryRestrictionsSection: some View {
        Section {
            ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                Toggle(restriction.displayName, isOn: Binding(
                    get: { dietaryRestrictions.contains(restriction) },
                    set: { isOn in
                        if isOn { dietaryRestrictions.insert(restriction) }
                        else { dietaryRestrictions.remove(restriction) }
                    }
                ))
            }
        } header: {
            Text("Dietary Restrictions")
        } footer: {
            Text("Recipes will be filtered and AI suggestions will respect these preferences.")
        }
    }

    private var favoriteCuisinesSection: some View {
        Section("Favorite Cuisines") {
            LazyVGrid(columns: [.init(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(Cuisine.allCases, id: \.self) { cuisine in
                    Button {
                        if preferredCuisines.contains(cuisine) {
                            preferredCuisines.remove(cuisine)
                        } else {
                            preferredCuisines.insert(cuisine)
                        }
                    } label: {
                        Text(cuisine.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                preferredCuisines.contains(cuisine)
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear,
                                in: .capsule
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        preferredCuisines.contains(cuisine)
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: preferredCuisines.count)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var avoidAndAllergensSection: some View {
        Section("Avoid & Allergens") {
            TextField("Disliked ingredients (comma separated)", text: $dislikedIngredients)
            TextField("Allergens (comma separated)", text: $allergens)
        }
    }

    private var cookingPreferencesSection: some View {
        Section {
            TextField("Max cook time (minutes)", text: $maxCookTime)
                .keyboardType(.numberPad)
        } header: {
            Text("Cooking Preferences")
        }
    }

    private var nutritionalGoalsSection: some View {
        Section("Nutritional Goals (Optional)") {
            TextField("Daily calories", text: $dailyCalories)
                .keyboardType(.numberPad)
            TextField("Daily protein (grams)", text: $dailyProtein)
                .keyboardType(.numberPad)
            TextField("Weekly grocery budget ($)", text: $weeklyBudget)
                .keyboardType(.decimalPad)
        }
    }

    private func saveProfile() {
        let profile = existingProfile ?? UserProfile()

        profile.displayName = displayName
        profile.skillLevel = skillLevel
        profile.measurementSystem = measurementSystem
        profile.hemisphere = hemisphere
        profile.dietaryRestrictions = Array(dietaryRestrictions)
        profile.preferredCuisines = Array(preferredCuisines)
        profile.dislikedIngredients = dislikedIngredients
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        profile.allergens = allergens
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        profile.maxCookTimeMinutes = Int(maxCookTime)
        profile.dailyCalorieTarget = Int(dailyCalories)
        profile.dailyProteinTargetGrams = Int(dailyProtein)
        profile.weeklyGroceryBudget = Double(weeklyBudget)

        if existingProfile == nil {
            modelContext.insert(profile)
        }

        dismiss()
    }
}

// MARK: - Onboarding View

/// First-launch onboarding flow that walks new users through profile setup.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var displayName = ""
    @State private var skillLevel: RecipeDifficulty = .intermediate
    @State private var selectedRestrictions: Set<DietaryRestriction> = []
    @State private var selectedCuisines: Set<Cuisine> = []

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            dietaryPage.tag(1)
            cuisinePage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Brand.midnight.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: currentPage) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Brand.warmTan.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "fork.knife")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(Brand.warmTan)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 24)

            Text("Welcome to Recipes")
                .font(.title.weight(.bold))
                .foregroundStyle(Brand.cream)
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("Your AI-powered kitchen companion.\nLet's personalize your experience.")
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

            // Name field
            VStack(alignment: .leading, spacing: 6) {
                Text("What should we call you?")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Brand.muted)
                    .padding(.horizontal, 4)
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Brand.cream)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            // Cooking level selection
            VStack(alignment: .leading, spacing: 10) {
                Text("Cooking level")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Brand.muted)
                    .padding(.horizontal, 4)

                let levels: [(RecipeDifficulty, String, String)] = [
                    (.beginner,     "🌱", "Beginner"),
                    (.intermediate, "🍳", "Intermediate"),
                    (.advanced,     "👨‍🍳", "Advanced"),
                    (.expert,       "⭐", "Expert"),
                ]
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(levels, id: \.0) { level, emoji, label in
                        Button {
                            skillLevel = level
                        } label: {
                            VStack(spacing: 6) {
                                Text(emoji)
                                    .font(.system(size: 26))
                                Text(label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(skillLevel == level ? Brand.midnight : Brand.cream)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                skillLevel == level ? Brand.warmTan : Brand.surface,
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(skillLevel == level ? Brand.warmTan : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation { currentPage = 1 }
            } label: {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(Brand.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(displayName.isEmpty ? Brand.muted : Brand.warmTan, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .disabled(displayName.isEmpty)

            Spacer().frame(height: 48)
        }
    }

    private var dietaryPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Brand.herbGreen.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Brand.herbGreen)
            }
            .padding(.bottom, 16)

            Text("Dietary Preferences")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Brand.cream)
                .padding(.bottom, 8)

            Text("Select any that apply. You can change these anytime.")
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 130))], spacing: 10) {
                    ForEach(DietaryRestriction.allCases, id: \.self) { restriction in
                        Button {
                            if selectedRestrictions.contains(restriction) {
                                selectedRestrictions.remove(restriction)
                            } else {
                                selectedRestrictions.insert(restriction)
                            }
                        } label: {
                            Text(restriction.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedRestrictions.contains(restriction) ? Brand.midnight : Brand.cream)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedRestrictions.contains(restriction) ? Brand.herbGreen : Brand.surface,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(Brand.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Brand.warmTan, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer().frame(height: 48)
        }
    }

    private var cuisinePage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Brand.warmTan.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Brand.warmTan)
            }
            .padding(.bottom, 16)

            Text("Favorite Cuisines")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Brand.cream)
                .padding(.bottom, 8)

            Text("Pick cuisines you love. AI will prioritize these in recommendations.")
                .font(.subheadline)
                .foregroundStyle(Brand.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Cuisine.allCases, id: \.self) { cuisine in
                        Button {
                            if selectedCuisines.contains(cuisine) {
                                selectedCuisines.remove(cuisine)
                            } else {
                                selectedCuisines.insert(cuisine)
                            }
                        } label: {
                            Text(cuisine.rawValue.capitalized)
                                .font(.system(size: 14, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .foregroundStyle(selectedCuisines.contains(cuisine) ? Brand.midnight : Brand.cream)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selectedCuisines.contains(cuisine) ? Brand.warmTan : Brand.surface,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            Button {
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(Brand.midnight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Brand.herbGreen, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .sensoryFeedback(.success, trigger: currentPage)

            Spacer().frame(height: 48)
        }
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            displayName: displayName,
            dietaryRestrictions: Array(selectedRestrictions),
            preferredCuisines: Array(selectedCuisines),
            skillLevel: skillLevel
        )
        modelContext.insert(profile)
        dismiss()
    }
}
