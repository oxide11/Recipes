import SwiftUI

// MARK: - Nutrition Facts Card

/// Displays nutritional information in a format inspired by
/// standard FDA nutrition labels, following HIG for readability.
struct NutritionCardView: View {
    let info: NutritionalInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let serving = info.servingSize {
                Text("Serving Size: \(serving)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            Divider().overlay(.primary)

            nutritionRow(label: "Calories", value: "\(Int(info.calories))", bold: true)

            Divider()

            nutritionRow(label: "Total Fat", value: "\(formatted(info.fatGrams))g")
            if let sat = info.saturatedFatGrams {
                nutritionRow(label: "  Saturated Fat", value: "\(formatted(sat))g", isSubItem: true)
            }
            if let trans = info.transFatGrams {
                nutritionRow(label: "  Trans Fat", value: "\(formatted(trans))g", isSubItem: true)
            }

            Divider()

            if let chol = info.cholesterolMg {
                nutritionRow(label: "Cholesterol", value: "\(Int(chol))mg")
            }
            if let sodium = info.sodiumMg {
                nutritionRow(label: "Sodium", value: "\(Int(sodium))mg")
            }

            Divider()

            nutritionRow(label: "Total Carbohydrate", value: "\(formatted(info.carbsGrams))g")
            nutritionRow(label: "  Dietary Fiber", value: "\(formatted(info.fiberGrams))g", isSubItem: true)
            nutritionRow(label: "  Total Sugars", value: "\(formatted(info.sugarGrams))g", isSubItem: true)

            Divider()

            nutritionRow(label: "Protein", value: "\(formatted(info.proteinGrams))g", bold: true)

            Divider().overlay(.primary)

            // Macro breakdown bar
            macroPieChart
        }
        .padding()
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func nutritionRow(label: String, value: String, bold: Bool = false, isSubItem: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isSubItem ? .caption : .subheadline)
                .fontWeight(bold ? .bold : .regular)
            Spacer()
            Text(value)
                .font(isSubItem ? .caption : .subheadline)
                .fontWeight(bold ? .bold : .medium)
        }
        .padding(.vertical, 2)
    }

    private var macroPieChart: some View {
        VStack(spacing: 8) {
            Text("Macro Breakdown")
                .font(.caption)
                .fontWeight(.semibold)

            HStack(spacing: 16) {
                macroIndicator(label: "Protein", percentage: info.proteinPercentage, color: .blue)
                macroIndicator(label: "Carbs", percentage: info.carbsPercentage, color: .green)
                macroIndicator(label: "Fat", percentage: info.fatPercentage, color: .orange)
            }

            // Proportional bar
            GeometryReader { geo in
                HStack(spacing: 1) {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: geo.size.width * info.proteinPercentage / 100)
                    Rectangle()
                        .fill(.green)
                        .frame(width: geo.size.width * info.carbsPercentage / 100)
                    Rectangle()
                        .fill(.orange)
                        .frame(width: geo.size.width * info.fatPercentage / 100)
                }
                .clipShape(.rect(cornerRadius: 4))
            }
            .frame(height: 8)
        }
        .padding(.top, 8)
    }

    private func macroIndicator(label: String, percentage: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(Int(percentage))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}
