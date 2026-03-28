import SwiftUI

// MARK: - Ingredient Row (Color Coded)

struct IngredientRow: View {
    let ingredient: Ingredient
    var servingMultiplier: Double = 1.0

    private var scaledAmount: IngredientAmount {
        MeasurementConversionService.scale(
            amount: ingredient.amount,
            by: servingMultiplier
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color-coded category indicator
            Circle()
                .fill(colorForCategory(ingredient.category))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .fontWeight(.medium)

                if let notes = ingredient.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(scaledAmount.displayString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if ingredient.isOptional {
                Text("optional")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !SeasonalAwarenessService.isInSeason(ingredient.name) {
                Image(systemName: "leaf.arrow.triangle.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .help("Not in season")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ingredient.name), \(scaledAmount.displayString)\(ingredient.isOptional ? ", optional" : "")")
    }

    private func colorForCategory(_ category: IngredientCategory) -> Color {
        switch category.displayColor {
        case .red:    return .red
        case .green:  return .green
        case .orange: return .orange
        case .amber:  return .yellow
        case .blue:   return .blue
        case .purple: return .purple
        case .yellow: return .yellow
        case .teal:   return .teal
        case .cyan:   return .cyan
        case .pink:   return .pink
        case .brown:  return .brown
        case .mint:   return .mint
        case .lime:   return .green.opacity(0.7)
        case .gray:   return .gray
        }
    }
}
