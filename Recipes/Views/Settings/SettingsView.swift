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

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                aiSection
                measurementSection
                notificationsSection
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
                        Text(profile.dietaryRestrictions.map { $0.rawValue.capitalized }.joined(separator: ", "))
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
        if !openAIKey.isEmpty {
            _ = KeychainService.store(key: .openAIAPIKey, value: openAIKey)
        }
        if !claudeKey.isEmpty {
            _ = KeychainService.store(key: .claudeAPIKey, value: claudeKey)
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
