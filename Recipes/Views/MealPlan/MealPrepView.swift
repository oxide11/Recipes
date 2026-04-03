import SwiftUI

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Meal Prep View

struct MealPrepView: View {
    let meals: [PlannedMeal]
    let date: Date
    var weekEndDate: Date? = nil  // non-nil → week range header

    @State private var detailTask: PrepTask? = nil

    @State private var taskGroups: [PrepTaskGroup] = []
    @Environment(\.dismiss) private var dismiss

    private var recipeCount: Int {
        Set(meals.compactMap(\.recipe?.title)).count
    }

    private var completedTaskCount: Int {
        taskGroups.flatMap(\.tasks).filter(\.isCompleted).count
    }

    private var totalTaskCount: Int {
        taskGroups.flatMap(\.tasks).count
    }

    private var progress: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    private var totalActiveMinutes: Int {
        taskGroups.reduce(0) { $0 + $1.estimatedMinutes }
    }

    private var totalTimeLabel: String {
        if totalActiveMinutes < 60 { return "~\(totalActiveMinutes) min active prep" }
        let h = totalActiveMinutes / 60
        let m = totalActiveMinutes % 60
        return m == 0 ? "~\(h)h active prep" : "~\(h)h \(m)m active prep"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    progressSection

                    let sections = MealPrepPlanGenerator.groupedByUrgency(taskGroups)
                    ForEach(sections, id: \.title) { section in
                        urgencySection(section.title, icon: section.icon, groups: section.groups)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Brand.midnight)
            .navigationTitle("Meal Prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Brand.warmTan)
                }
            }
        }
        .task {
            taskGroups = MealPrepPlanGenerator.generate(from: meals)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            if let end = weekEndDate {
                Text("Week of \(date.formatted(.dateTime.month(.wide).day())) – \(end.formatted(.dateTime.month(.wide).day()))")
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
            } else {
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.miseHeading)
                    .foregroundStyle(Brand.cream)
            }

            Text("\(recipeCount) recipes · \(totalTaskCount) prep tasks")
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)

            Text(totalTimeLabel)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Brand.warmTan)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Brand.warmTan.opacity(0.15), in: Capsule())

            // List the recipe names
            let recipeNames = meals.compactMap(\.recipe?.title)
            if !recipeNames.isEmpty {
                Text(recipeNames.joined(separator: " · "))
                    .font(.miseMeta)
                    .foregroundStyle(Brand.warmTan)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Progress")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.muted)
                Spacer()
                Text("\(completedTaskCount)/\(totalTaskCount)")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.cream)
            }

            ProgressView(value: progress)
                .tint(progress >= 1.0 ? Brand.herbGreen : Brand.warmTan)

            if progress >= 1.0 {
                Text("All prep done!")
                    .font(.miseMeta)
                    .foregroundStyle(Brand.herbGreen)
            }
        }
        .padding()
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Urgency Section

    private func urgencySection(_ title: String, icon: String, groups: [PrepTaskGroup]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Brand.warmTan)
                Text(title)
                    .miseSectionHeader()
            }
            .padding(.top, 4)

            ForEach(groups) { group in
                ingredientGroupCard(groupIndex: findGroupIndex(group))
            }
        }
    }

    private func findGroupIndex(_ group: PrepTaskGroup) -> Int {
        taskGroups.firstIndex(where: { $0.id == group.id }) ?? 0
    }

    private func ingredientGroupCard(groupIndex: Int) -> some View {
        let group = taskGroups[groupIndex]
        // Group task indices by action so each action gets its own checkbox row
        let tasksByAction = Dictionary(grouping: group.tasks.indices, by: { group.tasks[$0].preparationNote })
        let sortedActions = tasksByAction.keys.sorted()

        return VStack(alignment: .leading, spacing: 10) {
            // Ingredient name + total amount — header, no checkbox
            HStack {
                Text(group.ingredientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(group.isFullyCompleted ? Brand.muted : Brand.cream)
                    .accessibilityLabel("\(group.ingredientName)\(group.isFullyCompleted ? ", all steps completed" : "")")
                Spacer()
                Text(group.totalAmount)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.warmTan.opacity(group.isFullyCompleted ? 0.5 : 1))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Brand.warmTan.opacity(0.15), in: Capsule())
            }

            Divider().overlay(Brand.muted.opacity(0.3))

            // One checkable row per action
            ForEach(sortedActions, id: \.self) { action in
                actionRow(groupIndex: groupIndex, action: action, indices: tasksByAction[action] ?? [], showAmount: sortedActions.count > 1)
            }
        }
        .padding(12)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private func actionRow(groupIndex: Int, action: String, indices: [Int], showAmount: Bool) -> some View {
        let group = taskGroups[groupIndex]
        let tasks = indices.map { group.tasks[$0] }
        let allDone = tasks.allSatisfy(\.isCompleted)
        let totalAmount = combinedDisplay(tasks.map(\.amount))
        let _ = tasks.map(\.recipeName).uniqued().joined(separator: ", ")

        // Use first task that has detail for the info button (all tasks same action, pick first with detail)
        let detailSource = tasks.first(where: { $0.detail != nil })

        return HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let target = !allDone
                    for i in indices { taskGroups[groupIndex].tasks[i].isCompleted = target }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: allDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(allDone ? Brand.herbGreen : Brand.muted)
                        .accessibilityHidden(true)

                    let displayAction = action.hasPrefix("Wash and ") ? String(action.dropFirst("Wash and ".count)).capitalized : action
                    let hasPassiveTime = MealPrepPlanGenerator.actionPassiveNote[action] != nil
                    let baseAction = action.components(separatedBy: " ").first ?? action
                    let mins = MealPrepPlanGenerator.actionTimeEstimates[action] ?? MealPrepPlanGenerator.actionTimeEstimates[baseAction] ?? 3

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(displayAction)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(allDone ? Brand.muted : Brand.cream)
                                .strikethrough(allDone)
                            if showAmount {
                                Text(totalAmount)
                                    .font(.caption2)
                                    .foregroundStyle(Brand.warmTan.opacity(allDone ? 0.4 : 0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Brand.warmTan.opacity(0.1), in: Capsule())
                            }
                            Spacer()
                            if hasPassiveTime {
                                Image(systemName: "clock.badge")
                                    .font(.caption)
                                    .foregroundStyle(Brand.spiceRed.opacity(allDone ? 0.4 : 0.9))
                            }
                            Text("~\(mins) min")
                                .font(.caption2)
                                .foregroundStyle(Brand.muted.opacity(allDone ? 0.4 : 0.7))
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(action)\(allDone ? ", completed" : ", not completed")")
            .accessibilityHint("Double tap to \(allDone ? "mark as incomplete" : "mark as complete")")

            if let src = detailSource {
                Button {
                    detailTask = src
                } label: {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(Brand.warmTan.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(item: $detailTask) { task in
            PrepDetailSheet(task: task)
        }
    }

    private func combinedDisplay(_ amounts: [IngredientAmount]) -> String {
        let byUnit = Dictionary(grouping: amounts, by: \.unit)
        return byUnit.map { unit, items in
            let total = items.reduce(0.0) { $0 + $1.quantity }
            let formatted = total.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", total) : String(format: "%.1f", total)
            return "\(formatted) \(unit.rawValue)"
        }.joined(separator: " + ")
    }
}

// MARK: - Prep Detail Sheet

struct PrepDetailSheet: View {
    let task: PrepTask
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.preparationNote)
                            .font(.miseHeading)
                            .foregroundStyle(Brand.cream)
                        Text(task.recipeName)
                            .font(.miseMeta)
                            .foregroundStyle(Brand.warmTan)
                    }

                    Divider().overlay(Brand.muted.opacity(0.3))

                    if let detail = task.detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(Brand.cream)
                            .lineSpacing(4)
                    }
                }
                .padding()
            }
            .background(Brand.midnight)
            .navigationTitle("How to")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Brand.warmTan)
                }
            }
        }
    }
}
