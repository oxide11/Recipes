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
    @State private var cookingGoal: CookingGoal
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
        _cookingGoal = State(initialValue: profile?.cookingGoal ?? .greatFood)
        _measurementSystem = State(initialValue: profile?.measurementSystem ?? .imperial)
        _hemisphere = State(initialValue: profile?.hemisphere ?? .northern)
        let restrictions = Set(profile?.dietaryRestrictions ?? [])
        _dietaryRestrictions = State(initialValue: restrictions)
        // Auto-expand if the user already has lifestyle restrictions selected
        let lifestyle: [DietaryRestriction] = [.keto, .paleo, .whole30, .fodmap, .lowCarb, .lowSodium]
        _showMoreDietaryOptions = State(initialValue: restrictions.contains { lifestyle.contains($0) })
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

            if let profile = existingProfile {
                LabeledContent("Skill Level", value: profile.skillLevel.displayName)
                Text(profile.skillLevelDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Cooking Goal", selection: $cookingGoal) {
                ForEach(CookingGoal.allCases, id: \.self) { goal in
                    Text(goal.title).tag(goal)
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

    @State private var showMoreDietaryOptions = false

    private static let commonRestrictions: [DietaryRestriction] = [
        .vegetarian, .vegan, .pescatarian, .glutenFree, .dairyFree, .nutFree, .halal, .kosher
    ]
    private static let lifestyleRestrictions: [DietaryRestriction] = [
        .keto, .paleo, .whole30, .fodmap, .lowCarb, .lowSodium
    ]

    private var dietaryRestrictionsSection: some View {
        Section {
            ForEach(Self.commonRestrictions, id: \.self) { restriction in
                dietaryToggle(restriction)
            }

            DisclosureGroup(
                isExpanded: $showMoreDietaryOptions,
                content: {
                    ForEach(Self.lifestyleRestrictions, id: \.self) { restriction in
                        dietaryToggle(restriction)
                    }
                },
                label: {
                    let selectedCount = dietaryRestrictions.filter {
                        Self.lifestyleRestrictions.contains($0)
                    }.count
                    HStack {
                        Text(showMoreDietaryOptions ? "Fewer options" : "More options")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        if !showMoreDietaryOptions && selectedCount > 0 {
                            Text("\(selectedCount) selected")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                }
            )
        } header: {
            Text("Dietary Restrictions")
        } footer: {
            Text("Recipes will be filtered and AI suggestions will respect these preferences.")
        }
    }

    private func dietaryToggle(_ restriction: DietaryRestriction) -> some View {
        Toggle(restriction.displayName, isOn: Binding(
            get: { dietaryRestrictions.contains(restriction) },
            set: { isOn in
                if isOn { dietaryRestrictions.insert(restriction) }
                else { dietaryRestrictions.remove(restriction) }
            }
        ))
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
                                            : Color.secondary.opacity(0.5),
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
        profile.cookingGoal = cookingGoal
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
