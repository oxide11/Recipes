import SwiftUI

// MARK: - Direction Step View

/// Displays a single recipe direction with inline measurements,
/// timer controls, and safe temperature badges.
struct DirectionStepView: View {
    let direction: RecipeDirection
    var ingredientColorMap: [String: Color] = [:]
    var ingredientCategoryMap: [String: IngredientCategory] = [:]

    @State private var timerActive = false
    @State private var remainingSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
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
                    FlowLayout(spacing: 6) {
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
