import SwiftUI
import SwiftData
import FoundationModels

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query private var profiles: [UserProfile]

    @State private var openAIKey = ""
    @State private var claudeKey = ""
    @State private var showOpenAIKey = false
    @State private var showClaudeKey = false
    @State private var preferredProvider: AIProvider = .hybrid
    @State private var measurementSystem: MeasurementSystem = .imperial
    @State private var onDeviceAvailable = false
    @State private var showingSavedAlert = false
    @State private var showingSampleDataConfirm = false
    @State private var sampleDataLoaded = false
    @State private var apiKeyWarning: String? = nil

    private var profile: UserProfile? { profiles.first }

    @State private var showingClearDataConfirm = false

    private static let commonCurrencies = ["CAD", "USD", "EUR", "GBP", "AUD", "JPY", "MXN", "BRL", "INR"]

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                measurementSection
                currencySection
                mealPrepSection
                notificationsSection
                iCloudAndSharingSection
                profileSection
                sampleDataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .toolbarBackground(.automatic, for: .navigationBar)
            .task {
                loadSettings()
                onDeviceAvailable = await aiRouter.foundationModelService.isAvailable
            }
            .alert("Settings Saved", isPresented: $showingSavedAlert) {
                Button("OK") {}
            }
            .alert("Check Your API Key", isPresented: Binding(
                get: { apiKeyWarning != nil },
                set: { if !$0 { apiKeyWarning = nil } }
            )) {
                Button("Save Anyway") {
                    apiKeyWarning = nil
                    commitAPIKeys()
                }
                Button("Cancel", role: .cancel) { apiKeyWarning = nil }
            } message: {
                Text(apiKeyWarning ?? "")
            }
        }
    }

    // MARK: - AI Configuration

    private var aiSection: some View {
        Section {
            // On-device AI status
            HStack {
                Label("Apple Intelligence", systemImage: "apple.intelligence")
                Spacer()
                Text(onDeviceAvailable ? "Available" : "Unavailable")
                    .foregroundStyle(onDeviceAvailable ? Brand.herbGreen : .secondary)
            }

            // Preferred provider
            Picker("AI Provider", selection: $preferredProvider) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(providerDisplayName(provider)).tag(provider)
                }
            }
            .onChange(of: preferredProvider) {
                aiRouter.preferredProvider = preferredProvider
            }

            // OpenAI API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenAI API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showOpenAIKey {
                            TextField("sk-...", text: $openAIKey)
                        } else {
                            SecureField("sk-...", text: $openAIKey)
                        }
                    }
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button {
                        showOpenAIKey.toggle()
                    } label: {
                        Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(showOpenAIKey ? "Hide OpenAI API key" : "Show OpenAI API key")
                }
            }

            // Claude API Key
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showClaudeKey {
                            TextField("sk-ant-...", text: $claudeKey)
                        } else {
                            SecureField("sk-ant-...", text: $claudeKey)
                        }
                    }
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button {
                        showClaudeKey.toggle()
                    } label: {
                        Image(systemName: showClaudeKey ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(showClaudeKey ? "Hide Claude API key" : "Show Claude API key")
                }
            }

            Button("Save API Keys") {
                saveAPIKeys()
            }
        } header: {
            Label("AI Configuration", systemImage: "sparkles")
        } footer: {
            Text("API keys are stored securely in your device's Keychain. On-device AI processes data locally — no data leaves your device.")
        }
    }

    // MARK: - Currency

    private var currencySection: some View {
        Section {
            if let profile {
                Picker("Currency", selection: Bindable(profile).preferredCurrencyCode) {
                    ForEach(Self.commonCurrencies, id: \.self) { code in
                        Text("\(code) (\(currencySymbol(for: code)))")
                            .tag(code)
                    }
                }
            } else {
                Text("Create a profile to set currency")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Currency", systemImage: "dollarsign.circle")
        } footer: {
            Text("Used for shopping list cost estimates and receipt totals.")
        }
    }

    private func currencySymbol(for code: String) -> String {
        let locale = Locale(identifier: "en_US")
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = locale
        return formatter.currencySymbol ?? code
    }

    // MARK: - Meal Prep

    private var mealPrepSection: some View {
        Section {
            if let profile {
                Picker("Meal Prep Mode", selection: Bindable(profile).defaultMealPrepMode) {
                    Text("Daily Prep").tag(MealPrepMode.daily)
                    Text("Weekly Prep").tag(MealPrepMode.weekly)
                }

                Toggle(isOn: Bindable(profile).autoDeductPantry) {
                    VStack(alignment: .leading) {
                        Text("Auto-Deduct Pantry")
                        Text("Reduce pantry quantities when you log a cooking session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Create a profile to configure meal prep")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Meal Planning & Cooking", systemImage: "calendar")
        } footer: {
            Text("Weekly: Shop Saturday, prep Sunday for the whole week. Daily: Prep each day's meals individually.")
        }
    }

    // MARK: - iCloud & Sharing

    private var iCloudAndSharingSection: some View {
        Section {
            if let profile {
                Toggle(isOn: Bindable(profile).iCloudSyncEnabled) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("iCloud Sync")
                            Text("(todo)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text("Sync recipes, meal plans, and pantry across devices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)

                Toggle(isOn: Bindable(profile).shareRecipesEnabled) {
                    HStack {
                        Text("Share Recipes")
                        Text("(todo)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(true)

                Toggle(isOn: Bindable(profile).shareStatsEnabled) {
                    HStack {
                        Text("Share Cooking Stats")
                        Text("(todo)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(true)

                Toggle(isOn: Bindable(profile).shareJournalEnabled) {
                    HStack {
                        Text("Share Restaurant Journal")
                        Text("(todo)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(true)
            } else {
                Text("Create a profile to configure sharing")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("iCloud & Sharing", systemImage: "icloud")
        } footer: {
            Text("These features are coming soon.")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Smart Notifications")
                            .fontWeight(.medium)
                        Text("Pantry expiry alerts, meal reminders & streaks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Brand.warmTan)
                }
            }
        }
    }

    // MARK: - Measurements

    private var measurementSection: some View {
        Section("Measurements") {
            Picker("System", selection: $measurementSystem) {
                Text("Imperial (cups, oz, °F)").tag(MeasurementSystem.imperial)
                Text("Metric (ml, g, °C)").tag(MeasurementSystem.metric)
            }
        }
    }

    // MARK: - Profile

    @State private var showingProfileEditor = false

    private var profileSection: some View {
        Section("Profile") {
            if let profile {
                LabeledContent("Name", value: profile.displayName)
                LabeledContent("Skill Level", value: profile.skillLevel.rawValue.capitalized)
                LabeledContent("Member Since", value: profile.dateJoined, format: .dateTime.month().year())

                if !profile.dietaryRestrictions.isEmpty {
                    LabeledContent("Dietary") {
                        Text(profile.dietaryRestrictions.map { $0.displayName }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Edit Profile") {
                    showingProfileEditor = true
                }
            } else {
                Button {
                    showingProfileEditor = true
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Create Profile")
                                .fontWeight(.medium)
                            Text("Set up your dietary preferences and cooking goals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorView(profile: profile)
        }
    }

    // MARK: - Sample Data

    private var sampleDataSection: some View {
        Section {
            Button {
                showingSampleDataConfirm = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Load Sample Data")
                            .fontWeight(.medium)
                        Text("Populate the app with recipes, pantry items, a meal plan, and more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(Brand.warmTan)
                }
            }
            .disabled(sampleDataLoaded)
            .confirmationDialog(
                "Load Sample Data?",
                isPresented: $showingSampleDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Load Sample Data") {
                    SampleData.populate(modelContext)
                    sampleDataLoaded = true
                }
            } message: {
                Text("This will add sample recipes, pantry items, a meal plan, grocery list, restaurant journal entries, and a user profile.")
            }

            Button(role: .destructive) {
                showingClearDataConfirm = true
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Clear All Data")
                            .fontWeight(.medium)
                        Text("Remove all recipes, meal plans, pantry items, and more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "trash")
                        .foregroundStyle(Brand.spiceRed)
                }
            }
            .confirmationDialog(
                "Clear All Data?",
                isPresented: $showingClearDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    SampleData.clearAll(modelContext)
                    sampleDataLoaded = false
                }
            } message: {
                Text("This will permanently delete all recipes, meal plans, pantry items, shopping lists, journal entries, and your profile. This cannot be undone.")
            }
        } header: {
            Label("Developer", systemImage: "hammer")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Platform", value: "iOS 26")
            LabeledContent("Built with", value: "SwiftUI, SwiftData, FoundationModels")
        }
    }

    // MARK: - Helpers

    private func loadSettings() {
        openAIKey = KeychainService.retrieve(key: .openAIAPIKey) ?? ""
        claudeKey = KeychainService.retrieve(key: .claudeAPIKey) ?? ""
        preferredProvider = aiRouter.preferredProvider
        if let profile {
            measurementSystem = profile.measurementSystem
        }
    }

    private func saveAPIKeys() {
        let trimmedOpenAI = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClaude = claudeKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic format validation — warn but allow the user to save anyway
        if !trimmedOpenAI.isEmpty && !trimmedOpenAI.hasPrefix("sk-") {
            apiKeyWarning = "Your OpenAI key doesn't look right — it should start with \"sk-\". Double-check it and try again."
            return
        }
        if !trimmedClaude.isEmpty && !trimmedClaude.hasPrefix("sk-ant-") {
            apiKeyWarning = "Your Claude key doesn't look right — it should start with \"sk-ant-\". Double-check it and try again."
            return
        }

        commitAPIKeys()
    }

    private func commitAPIKeys() {
        let trimmedOpenAI = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClaude = claudeKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOpenAI.isEmpty {
            _ = KeychainService.store(key: .openAIAPIKey, value: trimmedOpenAI)
        }
        if !trimmedClaude.isEmpty {
            _ = KeychainService.store(key: .claudeAPIKey, value: trimmedClaude)
        }
        showingSavedAlert = true
    }

    private func providerDisplayName(_ provider: AIProvider) -> String {
        switch provider {
        case .onDevice: return "On-Device Only"
        case .claude:   return "Claude (Anthropic)"
        case .openAI:   return "OpenAI"
        case .hybrid:   return "Hybrid (On-Device + Cloud)"
        }
    }
}
