import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Meal Plan Widget

/// Shows today's planned meals on the home screen and lock screen.
struct MealPlanWidget: Widget {
    let kind = "MealPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealPlanTimelineProvider()) { entry in
            MealPlanWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Meals")
        .description("See what's planned for today.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Timeline Provider

struct MealPlanTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealPlanEntry {
        MealPlanEntry(
            date: .now,
            meals: [
                .init(type: "Breakfast", title: "Avocado Toast", time: 15),
                .init(type: "Lunch", title: "Caesar Salad", time: 20),
                .init(type: "Dinner", title: "Pasta Aglio e Olio", time: 30),
            ]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MealPlanEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealPlanEntry>) -> Void) {
        // In production, fetch from shared SwiftData container
        let entry = placeholder(in: context)
        let timeline = Timeline(entries: [entry], policy: .after(
            Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        ))
        completion(timeline)
    }
}

// MARK: - Entry

struct MealPlanEntry: TimelineEntry {
    let date: Date
    let meals: [WidgetMeal]
}

struct WidgetMeal: Identifiable {
    let id = UUID()
    let type: String
    let title: String
    let time: Int
}

// MARK: - Widget Views

struct MealPlanWidgetView: View {
    let entry: MealPlanEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            accessoryView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundStyle(.tint)
                Text("Today")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            if entry.meals.isEmpty {
                Text("No meals planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.meals.prefix(3)) { meal in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meal.type)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(meal.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundStyle(.tint)
                Text("Today's Meals")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(entry.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if entry.meals.isEmpty {
                Text("No meals planned for today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                HStack(spacing: 16) {
                    ForEach(entry.meals.prefix(3)) { meal in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.type)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                            Text(meal.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            Label("\(meal.time) min", systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var accessoryView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                Text("Meals")
                    .fontWeight(.semibold)
            }
            .font(.caption)

            if let next = entry.meals.first {
                Text("\(next.type): \(next.title)")
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text("Nothing planned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Cooking Timer Live Activity

/// Attributes for the cooking timer Live Activity.
/// Shows active step, remaining time, and recipe title on the lock screen and Dynamic Island.
import ActivityKit

struct CookingTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var stepInstruction: String
        var remainingSeconds: Int
        var totalSteps: Int
    }

    var recipeTitle: String
    var totalCookTimeMinutes: Int
}

// MARK: - Live Activity View

struct CookingTimerLiveActivityView: View {
    let context: ActivityViewContext<CookingTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text(context.attributes.recipeTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("Step \(context.state.stepNumber)/\(context.state.totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(context.state.stepInstruction)
                .font(.subheadline)
                .lineLimit(2)

            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
                Text(formatTime(context.state.remainingSeconds))
                    .font(.title2)
                    .fontWeight(.bold)
                    .monospacedDigit()
                Spacer()
            }
        }
        .padding()
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Widget Bundle

@main
struct RecipesWidgetBundle: WidgetBundle {
    var body: some Widget {
        MealPlanWidget()
    }
}
