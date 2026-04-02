import SwiftUI
import SwiftData
import AVFoundation
import Speech

// MARK: - Cooking Mode View

/// Full-screen hands-free cooking experience with large text, voice readback,
/// auto-advancing timers, keep-screen-awake, and blink-based navigation
/// via Apple's Switch Control / AssistiveTouch accessibility features.
struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var currentStepIndex = 0
    @State private var stepEndDates: [Int: Date] = [:]
    @State private var stepPausedSeconds: [Int: Int] = [:]
    @State private var stepIsPaused: Set<Int> = []
    @State private var stepTimerTasks: [Int: Task<Void, Never>] = [:]
    @State private var stepLiveActivities: [Int: CookingTimerLiveActivityManager] = [:]
    @State private var checkedIngredients: [Int: Set<String>] = [:]  // stepIndex → ingredient names
    @State private var isVoiceEnabled = true
    @State private var showingTutorial = false
    @State private var selectedConversion: DirectionIngredientRef?
    @AppStorage("hasSeenCookingModeTutorial") private var hasSeenTutorial = false
    private let synthesizer = AVSpeechSynthesizer()

    // Cooking log
    private let sessionStartDate = Date()
    @State private var logRating: Int? = nil
    @State private var logNotes = ""

    /// Maps lowercased ingredient names to their category color for syntax-style highlighting.
    private var ingredientColors: [String: Color] {
        var map: [String: Color] = [:]
        for ingredient in recipe.ingredients {
            map[ingredient.name.lowercased()] = ingredient.category.displayColor.swiftUIColor
        }
        return map
    }

    /// Directions sorted by stepNumber so they always appear in the correct order
    /// regardless of how SwiftData returns them.
    private var sortedDirections: [RecipeDirection] {
        recipe.directions.sorted { $0.stepNumber < $1.stepNumber }
    }

    private var currentStep: RecipeDirection? {
        guard currentStepIndex < sortedDirections.count else { return nil }
        return sortedDirections[currentStepIndex]
    }

    private var progress: Double {
        guard !sortedDirections.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(sortedDirections.count)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Progress bar
                progressBar

                if let step = currentStep {
                    stepContent(step, height: geo.size.height * 0.7)
                } else {
                    completionView
                }

                Spacer(minLength: 0)

                // Controls
                controlBar
            }
        }
        .gesture(
            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 { advanceStep() }
                    else if value.translation.width > 40 { goBack() }
                }
        )
        .background(.black)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if !hasSeenTutorial {
                showingTutorial = true
            } else if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        }
        .overlay {
            if showingTutorial {
                CookingModeTutorialOverlay {
                    hasSeenTutorial = true
                    showingTutorial = false
                    if isVoiceEnabled, let step = currentStep {
                        speakStep(step)
                    }
                }
                .transition(.opacity)
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            synthesizer.stopSpeaking(at: .immediate)
            stepTimerTasks.values.forEach { $0.cancel() }
            Task { for m in stepLiveActivities.values { await m.end() } }
        }
        // Accessibility: Support Switch Control and blink-based navigation
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityAction(named: "Next Step") { advanceStep() }
        .accessibilityAction(named: "Previous Step") { goBack() }
        .popover(item: $selectedConversion) { ref in
            IngredientConversionPopover(ref: ref)
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text(recipe.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer()
                Text("Step \(currentStepIndex + 1) of \(sortedDirections.count)")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal)

            ProgressView(value: progress)
                .tint(.green)

            // Persistent banner for all active timers
            let activeSteps = stepEndDates.keys.sorted().filter { !stepIsPaused.contains($0) }
                + stepIsPaused.sorted().filter { stepEndDates[$0] == nil }
            ForEach(activeSteps, id: \.self) { stepIdx in
                HStack(spacing: 8) {
                    Image(systemName: stepIsPaused.contains(stepIdx) ? "pause.circle" : "timer")
                    Text("Step \(stepIdx + 1):")
                    if stepIsPaused.contains(stepIdx), let secs = stepPausedSeconds[stepIdx] {
                        Text(formatTime(secs))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.secondary)
                    } else if let end = stepEndDates[stepIdx] {
                        Text(end, style: .timer)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.orange)
                    }
                    Spacer()
                    if stepIsPaused.contains(stepIdx) {
                        Button("Resume") { resumeTimer(stepIndex: stepIdx) }
                            .font(.caption).foregroundStyle(.orange)
                    } else {
                        Button("Pause") { pauseTimer(stepIndex: stepIdx) }
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Button("Stop") { stopTimer(for: stepIdx) }
                        .font(.caption).foregroundStyle(.red)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.2), in: .rect(cornerRadius: 8))
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Step Content

    private func stepContent(_ step: RecipeDirection, height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Instruction — large text with color-coded ingredients
                Text(coloredInstruction(step))
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Step \(step.stepNumber). \(step.instruction)")

                // Timer
                if let timer = step.timer {
                    timerView(timer)
                }

                // Ingredient chips — tap to check off, long press to convert units
                if !step.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ingredients for this step")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 24)

                        WrappingLayout(itemSpacing: 8, rowSpacing: 8) {
                            ForEach(step.ingredients, id: \.ingredientName) { ref in
                                let color = ingredientColors[ref.ingredientName.lowercased()] ?? .accentColor
                                let isChecked = checkedIngredients[currentStepIndex]?.contains(ref.ingredientName) ?? false
                                Button {
                                    var checked = checkedIngredients[currentStepIndex] ?? []
                                    if isChecked { checked.remove(ref.ingredientName) }
                                    else { checked.insert(ref.ingredientName) }
                                    checkedIngredients[currentStepIndex] = checked
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.caption)
                                        Text("\(ref.amount.displayString) \(ref.ingredientName.lowercased())")
                                            .font(.subheadline)
                                            .strikethrough(isChecked)
                                    }
                                    .foregroundStyle(isChecked ? .white.opacity(0.35) : color)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isChecked ? .white.opacity(0.06) : color.opacity(0.15), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(LongPressGesture().onEnded { _ in
                                    selectedConversion = ref
                                })
                                .sensoryFeedback(.selection, trigger: isChecked)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Safe temperature
                if let temp = step.safeTemperature {
                    HStack(spacing: 8) {
                        Image(systemName: "thermometer.medium")
                            .font(.title2)
                        Text("\(temp.protein): \(Int(temp.minimumFahrenheit))°F / \(Int(temp.minimumCelsius))°C")
                            .font(.title3)
                    }
                    .foregroundStyle(.red)
                    .padding()
                    .background(.red.opacity(0.15), in: .rect(cornerRadius: 12))
                }
            }
            .padding(.vertical, 32)
        }
        .frame(maxHeight: height)
    }

    // MARK: - Timer

    private func timerView(_ timer: TimerStep) -> some View {
        let endDate = stepEndDates[currentStepIndex]
        let isPaused = stepIsPaused.contains(currentStepIndex)
        let pausedSecs = stepPausedSeconds[currentStepIndex]
        let isActive = endDate != nil || isPaused

        return VStack(spacing: 12) {
            if isActive {
                Group {
                    if isPaused, let secs = pausedSecs {
                        Text(formatTime(secs))
                    } else if let end = endDate {
                        Text(end, style: .timer)
                    }
                }
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isPaused ? Color.secondary : Color.orange)

                HStack(spacing: 12) {
                    Button(isPaused ? "Resume" : "Pause") {
                        if isPaused {
                            resumeTimer(stepIndex: currentStepIndex)
                        } else {
                            pauseTimer(stepIndex: currentStepIndex)
                        }
                    }
                    .font(.title3)
                    .buttonStyle(.glass)
                    .tint(.orange)

                    Button("Stop Timer") {
                        stopTimer(for: currentStepIndex)
                    }
                    .font(.title3)
                    .buttonStyle(.glass)
                }
            } else {
                VStack(spacing: 8) {
                    Text(timer.displayDuration)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)

                    Button {
                        startTimer(seconds: timer.durationSeconds, stepIndex: currentStepIndex)
                    } label: {
                        Label("Start Timer", systemImage: "timer")
                    }
                    .font(.title3)
                    .buttonStyle(.glass)
                    .tint(.orange)
                }
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 16))
        .sensoryFeedback(.impact, trigger: isActive)
    }

    // MARK: - Completion

    private var completionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("All Done!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("You've completed all \(sortedDirections.count) steps.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))

                // Rating
                VStack(spacing: 8) {
                    Text("How did it turn out?")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= (logRating ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundStyle(star <= (logRating ?? 0) ? .yellow : .white.opacity(0.3))
                                .onTapGesture {
                                    logRating = logRating == star ? nil : star
                                }
                        }
                    }
                }
                .padding()
                .background(.white.opacity(0.05), in: .rect(cornerRadius: 16))

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (optional)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("How did it go? Any substitutions?", text: $logNotes, axis: .vertical)
                        .lineLimit(3...5)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                }

                // Actions
                VStack(spacing: 12) {
                    Button {
                        saveLog()
                        dismiss()
                    } label: {
                        Text("Save & Finish")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(.green)

                    Button("Skip") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(24)
        }
        .sensoryFeedback(.success, trigger: currentStepIndex)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 24) {
            // Back
            Button {
                goBack()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 48))
            }
            .disabled(currentStepIndex == 0)
            .opacity(currentStepIndex == 0 ? 0.3 : 1)
            .accessibilityLabel("Previous step")

            // Voice toggle
            Button {
                isVoiceEnabled.toggle()
                if !isVoiceEnabled {
                    synthesizer.stopSpeaking(at: .immediate)
                }
            } label: {
                Image(systemName: isVoiceEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .font(.system(size: 32))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isVoiceEnabled ? "Disable voice" : "Enable voice")

            // Close
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
            }
            .accessibilityLabel("Exit cooking mode")

            // Forward
            Button {
                advanceStep()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 48))
            }
            .disabled(currentStepIndex >= sortedDirections.count)
            .opacity(currentStepIndex >= sortedDirections.count ? 0.3 : 1)
            .accessibilityLabel("Next step")
        }
        .foregroundStyle(.white)
        .padding()
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func advanceStep() {
        synthesizer.stopSpeaking(at: .immediate)

        if currentStepIndex < sortedDirections.count - 1 {
            currentStepIndex += 1
            if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        } else {
            currentStepIndex = sortedDirections.count // show completion
        }
    }

    private func goBack() {
        guard currentStepIndex > 0 else { return }
        synthesizer.stopSpeaking(at: .immediate)
        currentStepIndex -= 1
        if isVoiceEnabled, let step = currentStep {
            speakStep(step)
        }
    }

    private func coloredInstruction(_ step: RecipeDirection) -> AttributedString {
        var result = AttributedString(step.instruction)
        for ref in step.ingredients {
            let color = ingredientColors[ref.ingredientName.lowercased()]

            // Try to match "amount ingredient" first (e.g. "2 cup flour")
            let fullPattern = "\(ref.amount.displayString) \(ref.ingredientName)"
            if let range = result.range(of: fullPattern, options: .caseInsensitive) {
                result[range].font = .system(size: 28, weight: .bold)
                if let color { result[range].foregroundColor = color }
            } else if let range = result.range(of: ref.ingredientName, options: .caseInsensitive) {
                result[range].font = .system(size: 28, weight: .bold)
                if let color { result[range].foregroundColor = color }
            }
        }
        return result
    }

    private func speakStep(_ step: RecipeDirection) {
        // Override mute switch so cooking guidance plays like navigation audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)

        var text = "Step \(step.stepNumber). \(step.instruction)"
        if let timer = step.timer {
            text += ". Timer: \(timer.displayDuration)."
        }
        if let temp = step.safeTemperature {
            text += ". Cook \(temp.protein) to \(Int(temp.minimumFahrenheit)) degrees Fahrenheit."
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func startTimer(seconds: Int, stepIndex: Int) {
        let endDate = Date().addingTimeInterval(Double(seconds))
        stepEndDates[stepIndex] = endDate
        stepIsPaused.remove(stepIndex)

        let manager = CookingTimerLiveActivityManager()
        stepLiveActivities[stepIndex] = manager
        manager.start(
            recipeTitle: recipe.title,
            recipeID: recipe.id,
            stepNumber: stepIndex + 1,
            stepInstruction: sortedDirections[stepIndex].instruction,
            durationSeconds: seconds,
            totalSteps: sortedDirections.count
        )

        scheduleCompletion(stepIndex: stepIndex, endDate: endDate)
    }

    private func pauseTimer(stepIndex: Int) {
        guard let end = stepEndDates[stepIndex] else { return }
        stepPausedSeconds[stepIndex] = max(0, Int(end.timeIntervalSinceNow))
        stepIsPaused.insert(stepIndex)
        stepEndDates.removeValue(forKey: stepIndex)
        stepTimerTasks[stepIndex]?.cancel()
        let remaining = stepPausedSeconds[stepIndex] ?? 0
        Task { await stepLiveActivities[stepIndex]?.pause(remainingSeconds: remaining) }
    }

    private func resumeTimer(stepIndex: Int) {
        guard let secs = stepPausedSeconds[stepIndex] else { return }
        stepIsPaused.remove(stepIndex)
        let endDate = Date().addingTimeInterval(Double(secs))
        stepEndDates[stepIndex] = endDate
        Task { await stepLiveActivities[stepIndex]?.resume(remainingSeconds: secs) }
        scheduleCompletion(stepIndex: stepIndex, endDate: endDate)
    }

    private func scheduleCompletion(stepIndex: Int, endDate: Date) {
        stepTimerTasks[stepIndex]?.cancel()
        stepTimerTasks[stepIndex] = Task {
            let interval = endDate.timeIntervalSinceNow
            guard interval > 0 else { return }
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, !stepIsPaused.contains(stepIndex) else { return }
            stepEndDates.removeValue(forKey: stepIndex)
            stepPausedSeconds.removeValue(forKey: stepIndex)
            stepTimerTasks.removeValue(forKey: stepIndex)
            await stepLiveActivities[stepIndex]?.end()
            stepLiveActivities.removeValue(forKey: stepIndex)
            if currentStepIndex == stepIndex { advanceStep() }
        }
    }

    private func stopTimer(for stepIndex: Int) {
        stepTimerTasks[stepIndex]?.cancel()
        stepTimerTasks.removeValue(forKey: stepIndex)
        stepEndDates.removeValue(forKey: stepIndex)
        stepPausedSeconds.removeValue(forKey: stepIndex)
        stepIsPaused.remove(stepIndex)
        Task {
            await stepLiveActivities[stepIndex]?.end()
            stepLiveActivities.removeValue(forKey: stepIndex)
        }
    }

    private func saveLog() {
        let elapsed = Int(Date().timeIntervalSince(sessionStartDate) / 60)
        let entry = CookingLogEntry(
            cookTimeMinutes: elapsed > 0 ? elapsed : nil,
            rating: logRating,
            notes: logNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : logNotes
        )
        recipe.cookingLog.append(entry)
    }

}

// MARK: - Blink Navigation Accessibility Help

/// Instructions view explaining how to set up blink-based navigation
/// via Apple's Switch Control accessibility feature.
struct BlinkNavigationHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Hands-Free Navigation", systemImage: "accessibility")
                                .font(.headline)

                            Text("Cooking Mode supports Apple's Switch Control, which lets you navigate steps by blinking, making head movements, or using external switches.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox("How to Set Up Blink Navigation") {
                        VStack(alignment: .leading, spacing: 12) {
                            setupStep(1, "Go to Settings > Accessibility > Switch Control")
                            setupStep(2, "Enable Switch Control")
                            setupStep(3, "Tap Switches > Add New Switch")
                            setupStep(4, "Select Camera > Left Head Movement → set to \"Move to Previous Item\"")
                            setupStep(5, "Select Camera > Right Head Movement → set to \"Move to Next Item\"")
                            setupStep(6, "Optionally: Camera > Blink → set to \"Select Item\" to tap buttons by blinking")
                        }
                    }

                    GroupBox("In Cooking Mode") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("\"Next Step\" — move to next direction", systemImage: "chevron.right")
                            Label("\"Previous Step\" — go back one step", systemImage: "chevron.left")
                            Label("Buttons respond to Switch Control selection", systemImage: "hand.tap")
                        }
                        .font(.subheadline)
                    }

                    GroupBox("Tips") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Voice readback announces each step automatically")
                            Text("• Timers auto-advance to the next step when complete")
                            Text("• The screen stays awake during cooking mode")
                            Text("• Large text ensures readability from a distance")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Hands-Free Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: .circle)

            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Cooking Mode Tutorial Overlay

struct CookingModeTutorialOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Brand.warmTan)

                Text("Cooking Mode")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 16) {
                    tutorialRow(icon: "chevron.left.chevron.right", text: "Swipe or tap arrows to navigate steps")
                    tutorialRow(icon: "speaker.wave.3.fill", text: "Each step is read aloud automatically")
                    tutorialRow(icon: "timer", text: "Timers auto-advance to the next step")
                    tutorialRow(icon: "display", text: "Screen stays awake while cooking")
                    tutorialRow(icon: "accessibility", text: "Works with Switch Control for hands-free use")
                }

                Button {
                    withAnimation { onDismiss() }
                } label: {
                    Text("Got It")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glass)
                .tint(Brand.warmTan)
                .padding(.horizontal, 32)
            }
            .padding(32)
        }
        .accessibilityAction(.escape) { onDismiss() }
    }

    private func tutorialRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Brand.warmTan)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
