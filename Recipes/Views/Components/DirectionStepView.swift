import SwiftUI
import ActivityKit
import AudioToolbox
import UserNotifications

// MARK: - Direction Step View

/// Displays a single recipe direction with inline measurements,
/// timer controls, and safe temperature badges.
struct DirectionStepView: View {
    let direction: RecipeDirection
    var ingredientColorMap: [String: Color] = [:]
    var ingredientCategoryMap: [String: IngredientCategory] = [:]

    @State private var timerActive = false
    @State private var isPaused = false
    @State private var endDate: Date? = nil
    @State private var pausedSeconds: Int = 0
    @State private var liveActivity = CookingTimerLiveActivityManager()
    @State private var selectedConversion: DirectionIngredientRef?
    @State private var lookupIngredient: (name: String, category: IngredientCategory)?

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
                // Instruction text with color-coded ingredient + amount references
                Text(attributedInstruction)

                // Tappable ingredient chips with conversion popover + look up
                if !direction.ingredients.isEmpty {
                    WrappingLayout(itemSpacing: 6, rowSpacing: 6) {
                        ForEach(direction.ingredients, id: \.ingredientName) { ref in
                            let color = ingredientColorMap[ref.ingredientName.lowercased()] ?? .accentColor
                            Button {
                                selectedConversion = ref
                            } label: {
                                Text("\(ref.amount.displayString) \(ref.ingredientName)")
                                    .font(.caption)
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(color.opacity(0.12), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    lookupIngredient = (
                                        name: ref.ingredientName,
                                        category: ingredientCategoryMap[ref.ingredientName.lowercased()] ?? .other
                                    )
                                } label: {
                                    Label("Look Up '\(ref.ingredientName)'", systemImage: "character.book.closed")
                                }
                                Button {
                                    selectedConversion = ref
                                } label: {
                                    Label("Convert Units", systemImage: "arrow.triangle.swap")
                                }
                            }
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
        .onAppear { restoreTimerIfNeeded() }
        .popover(item: $selectedConversion) { ref in
            IngredientConversionPopover(ref: ref)
                .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: Binding(
            get: { lookupIngredient != nil },
            set: { if !$0 { lookupIngredient = nil } }
        )) {
            if let lookup = lookupIngredient {
                IngredientLookupView(ingredientName: lookup.name, category: lookup.category)
            }
        }
    }

    // MARK: - Timer View

    var recipeTitle: String = ""
    var recipeID: UUID = UUID()
    var totalSteps: Int = 1

    private func timerView(_ timer: TimerStep) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if timerActive {
                // Countdown display
                Group {
                    if isPaused {
                        Text(formatTime(pausedSeconds))
                            .monospacedDigit()
                    } else if let end = endDate {
                        Text(end, style: .timer)
                            .monospacedDigit()
                    }
                }
                .fontWeight(.semibold)
                .foregroundStyle(isPaused ? Color.secondary : Color.orange)

                HStack(spacing: 6) {
                    Button(isPaused ? "Resume" : "Pause") {
                        if isPaused { resumeTimer() } else { pauseTimer() }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .tint(.orange)

                    Button("Stop") { stopTimer() }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(.red)
                }
            } else {
                // Duration stacked above start button
                Text(timer.displayDuration)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)

                Button {
                    startTimer(seconds: timer.durationSeconds)
                } label: {
                    Label("Start Timer", systemImage: "timer")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .font(.caption)
        .task(id: endDate) {
            guard let end = endDate, !isPaused else { return }
            let interval = end.timeIntervalSinceNow
            guard interval > 0 else {
                timerActive = false
                endDate = nil
                await liveActivity.end()
                timerDidFinish()
                return
            }
            try? await Task.sleep(for: .seconds(interval))
            if !Task.isCancelled, !isPaused {
                timerActive = false
                endDate = nil
                await liveActivity.end()
                timerDidFinish()
            }
        }
    }

    // MARK: - Restore after navigation

    /// Called on appear. If this step has an orphaned Live Activity (e.g. the user
    /// navigated away and came back), reconnect to it and restore the in-app timer state.
    private func restoreTimerIfNeeded() {
        guard !timerActive, direction.timer != nil else { return }

        let match = Activity<CookingTimerAttributes>.activities.first {
            $0.attributes.recipeID == recipeID.uuidString &&
            $0.content.state.stepNumber == direction.stepNumber
        }
        guard let activity = match else { return }

        let state = activity.content.state
        if let end = state.endDate, end > .now {
            // Timer still running — reconnect
            liveActivity.reconnect(to: activity)
            endDate = end
            timerActive = true
            isPaused = false
        } else if state.isPaused, let remaining = state.remainingSeconds, remaining > 0 {
            // Timer was paused — restore paused state using stored remaining seconds
            liveActivity.reconnect(to: activity)
            pausedSeconds = remaining
            timerActive = true
            isPaused = true
            endDate = nil
        } else {
            // Timer already finished but Live Activity wasn't ended — clean it up
            Task {
                var finalState = state
                finalState.endDate = nil
                nonisolated(unsafe) let a = activity
                await a.end(
                    .init(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
    }

    private var notificationID: String {
        "timer-\(recipeID.uuidString)-step-\(direction.stepNumber)"
    }

    private func startTimer(seconds: Int) {
        let end = Date().addingTimeInterval(Double(seconds))
        endDate = end
        timerActive = true
        isPaused = false
        liveActivity.start(
            recipeTitle: recipeTitle,
            recipeID: recipeID,
            stepNumber: direction.stepNumber,
            stepInstruction: direction.instruction,
            durationSeconds: seconds,
            totalSteps: totalSteps
        )
        scheduleTimerNotification(fireAt: end)
    }

    private func pauseTimer() {
        guard let end = endDate else { return }
        pausedSeconds = max(0, Int(end.timeIntervalSinceNow))
        isPaused = true
        endDate = nil
        cancelTimerNotification()
        Task { await liveActivity.pause(remainingSeconds: pausedSeconds) }
    }

    private func resumeTimer() {
        let end = Date().addingTimeInterval(Double(pausedSeconds))
        endDate = end
        isPaused = false
        scheduleTimerNotification(fireAt: end)
        Task { await liveActivity.resume(remainingSeconds: pausedSeconds) }
    }

    private func stopTimer() {
        timerActive = false
        isPaused = false
        endDate = nil
        pausedSeconds = 0
        cancelTimerNotification()
        Task { await liveActivity.end() }
    }

    /// Plays a sound and haptic when the timer finishes while the app is in the foreground.
    /// (The local notification handles the backgrounded case.)
    private func timerDidFinish() {
        // System sound 1005 = "Tock" alarm-style chime
        AudioServicesPlaySystemSound(1005)
        // Strong haptic so it's felt as well as heard
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    private func scheduleTimerNotification(fireAt date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Done!"
        content.body = "Step \(direction.stepNumber)\(recipeTitle.isEmpty ? "" : " — \(recipeTitle)"): \(direction.instruction.prefix(60))\(direction.instruction.count > 60 ? "…" : "")"
        content.sound = .defaultCritical   // plays even in Focus / Silent mode
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private var attributedInstruction: AttributedString {
        var result = AttributedString(direction.instruction)
        for ref in direction.ingredients {
            let color = ingredientColorMap[ref.ingredientName.lowercased()]

            // Try to match "amount ingredient" first (e.g. "2 cup flour")
            let fullPattern = "\(ref.amount.displayString) \(ref.ingredientName)"
            if let range = result.range(of: fullPattern, options: .caseInsensitive) {
                result[range].font = .body.bold()
                if let color { result[range].foregroundColor = color }
            } else if let range = result.range(of: ref.ingredientName, options: .caseInsensitive) {
                // Fallback: just highlight the ingredient name
                result[range].font = .body.bold()
                if let color { result[range].foregroundColor = color }
            }
        }
        return result
    }
}

// MARK: - Ingredient Conversion Popover

/// Shows useful unit conversions for a tapped ingredient chip.
struct IngredientConversionPopover: View {
    let ref: DirectionIngredientRef

    private var conversions: [IngredientAmount] {
        let amount = ref.amount
        let targets = Self.conversionTargets(for: amount.unit)
        return targets.compactMap { target in
            MeasurementConversionService.convert(amount: amount, to: target)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: original amount
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundStyle(Brand.warmTan)
                Text(ref.ingredientName.capitalized)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)

            Divider()

            // Original
            HStack {
                Text(ref.amount.displayString)
                    .fontWeight(.medium)
                Spacer()
                Text("original")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            }
            .font(.subheadline)

            // Conversions
            ForEach(conversions, id: \.unit) { converted in
                HStack {
                    Text(converted.displayString)
                        .fontWeight(.medium)
                    Spacer()
                    Text(converted.unit.rawValue)
                        .font(.caption)
                        .foregroundStyle(Brand.muted)
                }
                .font(.subheadline)
            }

            if conversions.isEmpty {
                Text("No conversions available")
                    .font(.caption)
                    .foregroundStyle(Brand.muted)
            }
        }
        .padding()
        .frame(minWidth: 200)
    }

    /// Returns the most useful conversion targets for a given unit.
    private static func conversionTargets(for unit: MeasurementUnit) -> [MeasurementUnit] {
        switch unit {
        // Volume imperial → metric + other imperial
        case .teaspoon:    return [.tablespoon, .milliliter]
        case .tablespoon:  return [.teaspoon, .cup, .milliliter]
        case .cup:         return [.tablespoon, .milliliter, .liter]
        case .fluidOunce:  return [.tablespoon, .cup, .milliliter]
        // Volume metric → imperial
        case .milliliter:  return [.teaspoon, .tablespoon, .cup, .fluidOunce]
        case .liter:       return [.cup, .milliliter, .fluidOunce]
        // Weight imperial → metric
        case .ounce:       return [.gram, .pound]
        case .pound:       return [.gram, .kilogram, .ounce]
        // Weight metric → imperial
        case .gram:        return [.ounce, .pound, .kilogram]
        case .kilogram:    return [.gram, .pound, .ounce]
        // Temperature
        case .fahrenheit:  return [.celsius]
        case .celsius:     return [.fahrenheit]
        // Count units — no meaningful conversions
        default:           return []
        }
    }
}

// MARK: - Wrapping Layout

struct WrappingLayout: Layout {
    var itemSpacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

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
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + itemSpacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

