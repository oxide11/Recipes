import SwiftUI

// MARK: - Direction Step View

/// Displays a single recipe direction with inline measurements,
/// timer controls, and safe temperature badges.
struct DirectionStepView: View {
    let direction: RecipeDirection

    @State private var timerActive = false
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text("\(direction.stepNumber)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: .circle)

            VStack(alignment: .leading, spacing: 8) {
                // Instruction text with inline ingredient references
                Text(attributedInstruction)

                // Inline ingredients used in this step
                if !direction.ingredients.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(direction.ingredients, id: \.ingredientName) { ref in
                            Text("\(ref.amount.displayString) \(ref.ingredientName)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.tint.opacity(0.1), in: .capsule)
                        }
                    }
                }

                // Timer
                if let timer = direction.timer {
                    timerView(timer)
                }

                // Safe temperature badge
                if let temp = direction.safeTemperature {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer.medium")
                        Text("\(temp.protein): \(Int(temp.minimumFahrenheit))°F")
                        if let rest = temp.restTimeMinutes {
                            Text("(rest \(rest) min)")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red.opacity(0.1), in: .capsule)
                    .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(direction.stepNumber). \(direction.instruction)")
    }

    // MARK: - Timer View

    private func timerView(_ timer: TimerStep) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")

            if timerActive {
                Text(formatTime(remainingSeconds))
                    .monospacedDigit()
                    .fontWeight(.semibold)

                Button("Stop") {
                    stopTimer()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            } else {
                Text(timer.displayDuration)

                Button("Start Timer") {
                    startTimer(seconds: timer.durationSeconds)
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .font(.caption)
        .padding(8)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 8))
    }

    @State private var timerStartTrigger = false
    var recipeTitle: String = ""
    var totalSteps: Int = 1

    private func startTimer(seconds: Int) {
        remainingSeconds = seconds
        timerActive = true
        timerStartTrigger.toggle()

        // Start Live Activity on lock screen
        CookingTimerLiveActivityManager.shared.startTimer(
            recipeTitle: recipeTitle,
            totalCookTimeMinutes: seconds / 60,
            stepNumber: direction.stepNumber,
            stepInstruction: direction.instruction,
            durationSeconds: seconds,
            totalSteps: totalSteps
        )

        timerTask = Task {
            while remainingSeconds > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1

                // Update Live Activity every 5 seconds
                if remainingSeconds % 5 == 0 {
                    await CookingTimerLiveActivityManager.shared.updateTimer(
                        stepNumber: direction.stepNumber,
                        stepInstruction: direction.instruction,
                        remainingSeconds: remainingSeconds,
                        totalSteps: totalSteps
                    )
                }
            }
            timerActive = false
            await CookingTimerLiveActivityManager.shared.endTimer()
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

    private var attributedInstruction: AttributedString {
        var result = AttributedString(direction.instruction)
        // Bold any ingredient references in the instruction text
        for ref in direction.ingredients {
            if let range = result.range(of: ref.ingredientName, options: .caseInsensitive) {
                result[range].font = .body.bold()
            }
        }
        return result
    }
}

// MARK: - Flow Layout (for ingredient chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
