import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Brand Colors (mirroring main app Brand tokens)

private enum WidgetBrand {
    static let warmTan = Color(red: 200/255, green: 184/255, blue: 154/255)
    static let herbGreen = Color(red: 122/255, green: 158/255, blue: 126/255)
    static let muted = Color(red: 136/255, green: 136/255, blue: 136/255)
}

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
            Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
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
        var totalSteps: Int
        /// Non-nil while the timer is counting down; nil when paused or ended.
        var endDate: Date?
        var isPaused: Bool
        /// Seconds remaining at the moment of pause. Nil when running or ended.
        var remainingSeconds: Int?
    }

    var recipeTitle: String
    var recipeID: String   // UUID string — used for the widgetURL deep link
}

// MARK: - Live Activity View

struct CookingTimerLiveActivityView: View {
    let context: ActivityViewContext<CookingTimerAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(WidgetBrand.warmTan)
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
                Image(systemName: context.state.isPaused ? "pause.circle" : "timer")
                    .foregroundStyle(WidgetBrand.warmTan)
                if context.state.isPaused {
                    Text("Paused")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(WidgetBrand.muted)
                } else if let end = context.state.endDate {
                    Text(end, style: .timer)
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(WidgetBrand.warmTan)
                }
                Spacer()
            }
        }
        .padding()
        .widgetURL(deepLinkURL(for: context))
    }

    private func deepLinkURL(for context: ActivityViewContext<CookingTimerAttributes>) -> URL? {
        URL(string: "recipes://timer/\(context.attributes.recipeID)/\(context.state.stepNumber)")
    }
}

// MARK: - Cooking Timer Live Activity Widget

struct CookingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingTimerAttributes.self) { context in
            // Lock screen / notification banner
            CookingTimerLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.recipeTitle, systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(WidgetBrand.warmTan)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Step \(context.state.stepNumber)/\(context.state.totalSteps)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.stepInstruction)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer()
                        if context.state.isPaused {
                            Text("Paused")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(WidgetBrand.muted)
                        } else if let end = context.state.endDate {
                            Text(end, style: .timer)
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(WidgetBrand.warmTan)
                        }
                    }
                    .widgetURL(URL(string: "recipes://timer/\(context.attributes.recipeID)/\(context.state.stepNumber)"))
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.circle" : "timer")
                    .foregroundStyle(WidgetBrand.warmTan)
            } compactTrailing: {
                if context.state.isPaused {
                    Text("II")
                        .font(.caption2)
                        .foregroundStyle(WidgetBrand.muted)
                } else if let end = context.state.endDate {
                    Text(end, style: .timer)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(WidgetBrand.warmTan)
                }
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(WidgetBrand.warmTan)
            }
        }
    }
}

// MARK: - Widget Bundle

@main
struct RecipesWidgetBundle: WidgetBundle {
    var body: some Widget {
        MealPlanWidget()
        CookingTimerLiveActivity()
    }
}
