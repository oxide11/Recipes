import SwiftUI
import SwiftData

// MARK: - Voice Pantry Edit View

/// Lets the user speak add/remove commands ("remove kefir, add cumin, Italian seasoning")
/// which are transcribed in real time, parsed by AI, then confirmed before applying.
struct VoicePantryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AIServiceRouter.self) private var aiRouter
    @Query(sort: \PantryItem.name) private var pantryItems: [PantryItem]

    @State private var recognizer = SpeechRecognizer()
    @State private var phase: Phase = .idle
    @State private var parsedActions: [PantryAction] = []
    @State private var errorMessage: String?

    enum Phase { case idle, listening, parsing, confirm }

    var body: some View {
        NavigationStack {
            Group {
                // Confirm phase needs a scrollable list with pinned buttons —
                // all other phases are simple centered content.
                if phase == .confirm {
                    confirmView
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 32) {
                        Spacer()

                        switch phase {
                        case .idle:      idleView
                        case .listening: listeningView
                        case .parsing:   parsingView
                        case .confirm:   EmptyView()
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Brand.spiceRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Voice Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recognizer.stop()
                        dismiss()
                    }
                }
            }
            .task { await startListening() }
            .onChange(of: recognizer.isListening) { _, listening in
                if !listening && phase == .listening {
                    // Auto-stopped (silence timeout) — notify and move to parsing
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    Task { await parse(recognizer.transcript) }
                }
            }
        }
    }

    // MARK: - Phase Views

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Brand.herbGreen)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("What would you like to change?")
                    .font(.headline)
                Text("\"Remove kefir, add cumin, Italian seasoning, olive oil\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .tint(Brand.herbGreen)
        }
    }

    private var listeningView: some View {
        VStack(spacing: 20) {
            PulsingMicView(isActive: recognizer.isListening)

            Text(recognizer.transcript.isEmpty ? "Listening…" : recognizer.transcript)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(recognizer.transcript.isEmpty ? .secondary : .primary)
                .padding(.horizontal)
                .animation(.easeInOut, value: recognizer.transcript)

            Text("Stops automatically after a pause")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button("Done Talking") {
                recognizer.stop()
                Task { await parse(recognizer.transcript) }
            }
            .buttonStyle(.bordered)
        }
    }

    private var parsingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Working out what to change…")
                .foregroundStyle(.secondary)
        }
    }

    private var confirmView: some View {
        VStack(spacing: 0) {
            if parsedActions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Couldn't work out any changes from that.")
                        .foregroundStyle(.secondary)
                    retryButton
                    Spacer()
                }
            } else {
                Text("Here's what I'll do:")
                    .font(.headline)
                    .padding(.vertical, 16)

                // Scrollable item list — expands to fill available space
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(parsedActions) { action in
                            HStack(spacing: 12) {
                                Image(systemName: action.type == .add ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundStyle(action.type == .add ? Brand.herbGreen : Brand.spiceRed)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.name).fontWeight(.medium)
                                    if action.type == .add {
                                        if pantryItems.contains(where: { $0.name.lowercased() == action.name.lowercased() }) {
                                            Text("Already in pantry — will skip")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        } else if let cat = action.category {
                                            Text(cat.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if action.type == .remove && !pantryItems.contains(where: { $0.name.lowercased() == action.name.lowercased() }) {
                                        Text("Not in pantry — will skip")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Button {
                                    parsedActions.removeAll { $0.id == action.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            Divider().padding(.leading, 52)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Buttons pinned below the scroll area — always reachable
                VStack(spacing: 12) {
                    Button {
                        applyChanges()
                    } label: {
                        Text("Apply")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.herbGreen)

                    retryButton
                }
                .padding(.vertical, 16)
            }
        }
    }

    private var retryButton: some View {
        Button {
            parsedActions = []
            errorMessage = nil
            Task { await startListening() }
        } label: {
            Label("Try Again", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Actions

    private func startListening() async {
        errorMessage = nil
        phase = .listening
        await recognizer.start()
        if let err = recognizer.error {
            errorMessage = err
            phase = .idle
        }
    }

    private func parse(_ transcript: String) async {
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Nothing was transcribed. Try again."
            phase = .idle
            return
        }
        phase = .parsing

        let prompt = """
        Parse these spoken pantry commands into structured add/remove actions.
        Normalize ingredient names (e.g. "Italian type spices" → "Italian Seasoning", "some eggs" → "Eggs").
        Input: "\(transcript)"
        Return ONLY a JSON array, no explanation:
        [{"action":"add","name":"Cumin","category":"spice"},{"action":"remove","name":"Kefir"}]
        Valid categories: protein, dairy, vegetable, fruit, grain, spice, herb, condiment, oil, liquid, sweetener, nut, other
        """

        do {
            let response = try await aiRouter.generateText(prompt: prompt, taskType: .classification)
            parsedActions = parseActions(from: response)
            phase = .confirm
        } catch {
            errorMessage = "Couldn't parse that. Try again."
            phase = .idle
        }
    }

    private func applyChanges() {
        for action in parsedActions {
            switch action.type {
            case .add:
                let key = action.name.lowercased()
                guard !pantryItems.contains(where: { $0.name.lowercased() == key }) else { continue }
                let item = PantryItem(
                    name: action.name,
                    category: action.category ?? .other,
                    quantity: 1,
                    unit: .piece
                )
                modelContext.insert(item)
            case .remove:
                let key = action.name.lowercased()
                if let item = pantryItems.first(where: { $0.name.lowercased() == key }) {
                    modelContext.delete(item)
                }
            }
        }
        dismiss()
    }

    // MARK: - Parsing

    struct PantryAction: Identifiable {
        let id = UUID()
        enum ActionType { case add, remove }
        let type: ActionType
        let name: String
        let category: IngredientCategory?
    }

    private func parseActions(from response: String) -> [PantryAction] {
        guard let start = response.firstIndex(of: "["),
              let end = response.lastIndex(of: "]") else { return [] }
        let json = String(response[start...end])
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let name = dict["name"] as? String, !name.isEmpty,
                  let actionStr = dict["action"] as? String else { return nil }
            let type: PantryAction.ActionType = actionStr == "add" ? .add : .remove
            let category = IngredientCategory(rawValue: dict["category"] as? String ?? "")
            return PantryAction(type: type, name: name, category: category)
        }
    }
}

// MARK: - Pulsing Mic Animation

private struct PulsingMicView: View {
    var isActive: Bool = true
    @State private var scale = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Brand.herbGreen.opacity(0.15) : Color.secondary.opacity(0.1))
                .frame(width: 100, height: 100)
                .scaleEffect(isActive ? scale : 1.0)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: isActive)

            Image(systemName: isActive ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(isActive ? Brand.herbGreen : .secondary)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isActive)
                .accessibilityLabel(isActive ? "Microphone active" : "Microphone inactive")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                scale = 1.25
            }
        }
    }
}
