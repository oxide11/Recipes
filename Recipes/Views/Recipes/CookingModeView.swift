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

    @State private var currentStepIndex = 0
    @State private var timerActive = false
    @State private var remainingSeconds = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var isVoiceEnabled = true
    @State private var synthesizer = AVSpeechSynthesizer()

    private var currentStep: RecipeDirection? {
        guard currentStepIndex < recipe.directions.count else { return nil }
        return recipe.directions[currentStepIndex]
    }

    private var progress: Double {
        guard !recipe.directions.isEmpty else { return 0 }
        return Double(currentStepIndex + 1) / Double(recipe.directions.count)
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
        .background(.black)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            synthesizer.stopSpeaking(at: .immediate)
            timerTask?.cancel()
            Task { await CookingTimerLiveActivityManager.shared.endTimer() }
        }
        // Accessibility: Support Switch Control and blink-based navigation
        .accessibilityAction(.escape) { dismiss() }
        .accessibilityAction(named: "Next Step") { advanceStep() }
        .accessibilityAction(named: "Previous Step") { goBack() }
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
                Text("Step \(currentStepIndex + 1) of \(recipe.directions.count)")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal)

            ProgressView(value: progress)
                .tint(.green)
        }
        .padding(.top, 8)
    }

    // MARK: - Step Content

    private func stepContent(_ step: RecipeDirection, height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Step number badge
                Text("\(step.stepNumber)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(.tint, in: .circle)

                // Instruction — large text for readability
                Text(step.instruction)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Step \(step.stepNumber). \(step.instruction)")

                // Inline ingredients
                if !step.ingredients.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(step.ingredients, id: \.ingredientName) { ref in
                            HStack {
                                Circle()
                                    .fill(.tint.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                Text("\(ref.amount.displayString) \(ref.ingredientName)")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                }

                // Timer
                if let timer = step.timer {
                    timerView(timer)
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
        VStack(spacing: 12) {
            if timerActive {
                Text(formatTime(remainingSeconds))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remainingSeconds <= 10 ? .red : .orange)

                Button("Stop Timer") {
                    stopTimer()
                }
                .font(.title3)
                .buttonStyle(.glass)
            } else {
                Text(timer.displayDuration)
                    .font(.title)
                    .foregroundStyle(.orange)

                Button("Start Timer") {
                    startTimer(seconds: timer.durationSeconds)
                }
                .font(.title3)
                .buttonStyle(.glass)
                .tint(.orange)
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 16))
        .sensoryFeedback(.impact, trigger: timerActive)
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("All Done!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("You've completed all \(recipe.directions.count) steps.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))

            Button("Finish") {
                dismiss()
            }
            .font(.title3)
            .buttonStyle(.glass)
            .tint(.green)
            .padding(.top)
            Spacer()
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
            .disabled(currentStepIndex >= recipe.directions.count)
            .opacity(currentStepIndex >= recipe.directions.count ? 0.3 : 1)
            .accessibilityLabel("Next step")
        }
        .foregroundStyle(.white)
        .padding()
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func advanceStep() {
        synthesizer.stopSpeaking(at: .immediate)
        stopTimer()

        if currentStepIndex < recipe.directions.count - 1 {
            currentStepIndex += 1
            if isVoiceEnabled, let step = currentStep {
                speakStep(step)
            }
        } else {
            currentStepIndex = recipe.directions.count // show completion
        }
    }

    private func goBack() {
        guard currentStepIndex > 0 else { return }
        synthesizer.stopSpeaking(at: .immediate)
        stopTimer()
        currentStepIndex -= 1
        if isVoiceEnabled, let step = currentStep {
            speakStep(step)
        }
    }

    private func speakStep(_ step: RecipeDirection) {
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

    private func startTimer(seconds: Int) {
        remainingSeconds = seconds
        timerActive = true

        CookingTimerLiveActivityManager.shared.startTimer(
            recipeTitle: recipe.title,
            totalCookTimeMinutes: recipe.cookTimeMinutes,
            stepNumber: (currentStep?.stepNumber ?? 1),
            stepInstruction: currentStep?.instruction ?? "",
            durationSeconds: seconds,
            totalSteps: recipe.directions.count
        )

        timerTask = Task {
            while remainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }
            timerActive = false
            await CookingTimerLiveActivityManager.shared.endTimer()

            // Vibrate when timer completes
            if remainingSeconds <= 0 {
                // Auto-advance after timer
                advanceStep()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerActive = false
        Task { await CookingTimerLiveActivityManager.shared.endTimer() }
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
