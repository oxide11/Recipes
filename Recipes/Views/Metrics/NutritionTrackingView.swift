import SwiftUI
import SwiftData
import Charts

// MARK: - Nutrition Tracking View

/// Daily and weekly nutrition tracking dashboard that tallies
/// what was actually cooked vs. the user's nutritional goals.
struct NutritionTrackingView: View {
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Query private var profiles: [UserProfile]

    @State private var selectedPeriod: TrackingPeriod = .week
    @State private var referenceDate = Date()

    private var profile: UserProfile? { profiles.first }

    private var trackedDays: [DayNutrition] {
        NutritionTracker.calculateDays(
            recipes: recipes,
            period: selectedPeriod,
            referenceDate: referenceDate
        )
    }

    private var totals: NutritionTotals {
        NutritionTracker.totals(from: trackedDays)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                goalProgressSection
                calorieChart
                macroBreakdownSection
                dailyBreakdownSection
            }
            .padding()
        }
        .navigationTitle("Nutrition")
        .toolbarBackground(.automatic, for: .navigationBar)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TrackingPeriod.allCases, id: \.self) { period in
                Text(period.rawValue.capitalized).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Goal Progress

    @ViewBuilder
    private var goalProgressSection: some View {
        if let profile, let target = profile.dailyCalorieTarget {
            let avgCalories = totals.avgCaloriesPerDay
            let progressValue = min(avgCalories / Double(target), 1.5)

            VStack(spacing: 12) {
                HStack {
                    Text("Daily Calorie Goal")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(avgCalories)) / \(target) kcal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progressValue, total: 1.5) {
                    EmptyView()
                }
                .tint(progressValue > 1.1 ? .red : progressValue > 0.9 ? .green : .orange)

                if let proteinTarget = profile.dailyProteinTargetGrams {
                    HStack {
                        Label("Protein", systemImage: "figure.strengthtraining.traditional")
                        Spacer()
                        Text("\(Int(totals.avgProteinPerDay))g / \(proteinTarget)g")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .padding()
            .background(in: .rect(cornerRadius: 12))
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Calorie Chart

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calories Over Time")
                .font(.headline)

            Chart(trackedDays) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Calories", day.calories)
                )
                .foregroundStyle(.orange.gradient)

                if let profile, let target = profile.dailyCalorieTarget {
                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
        .padding()
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    // MARK: - Macro Breakdown

    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average Macros")
                .font(.headline)

            HStack(spacing: 20) {
                macroCircle(label: "Protein", value: totals.avgProteinPerDay, unit: "g", color: .blue)
                macroCircle(label: "Carbs", value: totals.avgCarbsPerDay, unit: "g", color: .green)
                macroCircle(label: "Fat", value: totals.avgFatPerDay, unit: "g", color: .orange)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func macroCircle(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value))")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(width: 70, height: 70)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Breakdown")
                .font(.headline)

            ForEach(trackedDays) { day in
                HStack {
                    Text(day.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.subheadline)
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    HStack(spacing: 12) {
                        Label("\(Int(day.calories))", systemImage: "flame")
                            .foregroundStyle(.orange)
                        Label("\(Int(day.protein))g", systemImage: "figure.walk")
                            .foregroundStyle(.blue)
                    }
                    .font(.caption)

                    Text("\(day.recipesCooked) meals")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(in: .rect(cornerRadius: 12))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Tracking Period

enum TrackingPeriod: String, CaseIterable {
    case day, week, month
}

// MARK: - Nutrition Tracker

enum NutritionTracker {

    struct DayNutrition: Identifiable {
        let id = UUID()
        let date: Date
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
        var recipesCooked: Int
    }

    struct NutritionTotals {
        var totalCalories: Double
        var totalProtein: Double
        var totalCarbs: Double
        var totalFat: Double
        var days: Int

        var avgCaloriesPerDay: Double { days > 0 ? totalCalories / Double(days) : 0 }
        var avgProteinPerDay: Double { days > 0 ? totalProtein / Double(days) : 0 }
        var avgCarbsPerDay: Double { days > 0 ? totalCarbs / Double(days) : 0 }
        var avgFatPerDay: Double { days > 0 ? totalFat / Double(days) : 0 }
    }

    static func calculateDays(
        recipes: [Recipe],
        period: TrackingPeriod,
        referenceDate: Date
    ) -> [DayNutrition] {
        let calendar = Calendar.current
        let dayCount: Int
        switch period {
        case .day:   dayCount = 1
        case .week:  dayCount = 7
        case .month: dayCount = 30
        }

        var days: [DayNutrition] = []
        for offset in (0..<dayCount).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            var day = DayNutrition(date: dayStart, calories: 0, protein: 0, carbs: 0, fat: 0, recipesCooked: 0)

            for recipe in recipes {
                let logsToday = recipe.cookingLog.filter { $0.date >= dayStart && $0.date < dayEnd }
                day.recipesCooked += logsToday.count

                if !logsToday.isEmpty, let nutrition = recipe.nutritionalInfo {
                    let count = Double(logsToday.count)
                    day.calories += nutrition.calories * count
                    day.protein += nutrition.proteinGrams * count
                    day.carbs += nutrition.carbsGrams * count
                    day.fat += nutrition.fatGrams * count
                }
            }

            days.append(day)
        }

        return days
    }

    static func totals(from days: [DayNutrition]) -> NutritionTotals {
        let activeDays = days.filter { $0.recipesCooked > 0 }
        return NutritionTotals(
            totalCalories: days.reduce(0) { $0 + $1.calories },
            totalProtein: days.reduce(0) { $0 + $1.protein },
            totalCarbs: days.reduce(0) { $0 + $1.carbs },
            totalFat: days.reduce(0) { $0 + $1.fat },
            days: max(activeDays.count, 1)
        )
    }
}

// Type alias for external use
typealias DayNutrition = NutritionTracker.DayNutrition
typealias NutritionTotals = NutritionTracker.NutritionTotals
