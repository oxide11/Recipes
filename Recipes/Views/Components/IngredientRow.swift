import SwiftUI

// MARK: - Ingredient Row (Color Coded)

struct IngredientRow: View {
    let ingredient: Ingredient
    var servingMultiplier: Double = 1.0
    var isChecked: Bool = false
    var onToggle: (() -> Void)? = nil
    @State private var showingLookup = false

    private var scaledAmount: IngredientAmount {
        MeasurementConversionService.scale(
            amount: ingredient.amount,
            by: servingMultiplier
        )
    }

    var body: some View {
        Button(action: { onToggle?() }) {
            HStack(spacing: 12) {
                // Checklist toggle / category dot
                if onToggle != nil {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isChecked ? Brand.herbGreen : Brand.muted.opacity(0.6))
                } else {
                    Circle()
                        .fill(colorForCategory(ingredient.category))
                        .frame(width: 8, height: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.name)
                        .fontWeight(.medium)
                        .strikethrough(isChecked)
                        .foregroundStyle(isChecked ? .secondary : .primary)

                    if let notes = ingredient.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(scaledAmount.displayString)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? .tertiary : .secondary)
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
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ingredient.name), \(scaledAmount.displayString)\(ingredient.isOptional ? ", optional" : "")")
        .accessibilityAddTraits(isChecked ? [.isSelected] : [])
        .contextMenu {
            Button {
                showingLookup = true
            } label: {
                Label("Look Up '\(ingredient.name)'", systemImage: "character.book.closed")
            }
        }
        .sheet(isPresented: $showingLookup) {
            IngredientLookupView(ingredientName: ingredient.name, category: ingredient.category)
        }
    }

    private func colorForCategory(_ category: IngredientCategory) -> Color {
        category.displayColor.swiftUIColor
    }
}
