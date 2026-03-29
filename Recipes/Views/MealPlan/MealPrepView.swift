import SwiftUI

// MARK: - Meal Prep View

struct MealPrepView: View {
    let meals: [PlannedMeal]
    let date: Date

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection
                    progressSection

                    let sections = MealPrepPlanGenerator.groupedByCategory(taskGroups)
                    ForEach(sections, id: \.category) { section in
                        categorySection(section.category, groups: section.groups)
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
            Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.miseHeading)
                .foregroundStyle(Brand.cream)

            Text("\(recipeCount) recipes · \(totalTaskCount) prep tasks")
                .font(.miseMeta)
                .foregroundStyle(Brand.muted)

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

    // MARK: - Category Section

    private func categorySection(_ category: PrepCategory, groups: [PrepTaskGroup]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: category.systemImage)
                    .font(.caption)
                    .foregroundStyle(Brand.warmTan)
                Text(category.rawValue)
                    .miseSectionHeader()
            }
            .padding(.top, 4)

            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                ingredientGroupCard(groupIndex: findGroupIndex(group))
            }
        }
    }

    private func findGroupIndex(_ group: PrepTaskGroup) -> Int {
        taskGroups.firstIndex(where: { $0.id == group.id }) ?? 0
    }

    private func ingredientGroupCard(groupIndex: Int) -> some View {
        let group = taskGroups[groupIndex]

        return VStack(alignment: .leading, spacing: 8) {
            // Ingredient header with total
            HStack {
                Text(group.ingredientName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Brand.cream)

                Spacer()

                Text(group.totalAmount)
                    .font(.miseMeta)
                    .foregroundStyle(Brand.warmTan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Brand.warmTan.opacity(0.15), in: Capsule())
            }

            // Per-recipe tasks
            ForEach(Array(group.tasks.enumerated()), id: \.element.id) { taskIndex, task in
                taskRow(groupIndex: groupIndex, taskIndex: taskIndex, task: task)
            }
        }
        .padding(12)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 10))
    }

    private func taskRow(groupIndex: Int, taskIndex: Int, task: PrepTask) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                taskGroups[groupIndex].tasks[taskIndex].isCompleted.toggle()
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(task.isCompleted ? Brand.herbGreen : Brand.muted)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.recipeName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(task.isCompleted ? Brand.muted : Brand.cream)
                        .strikethrough(task.isCompleted)

                    HStack(spacing: 4) {
                        Text(task.amount.displayString)
                            .font(.miseMeta)
                            .foregroundStyle(Brand.warmTan.opacity(task.isCompleted ? 0.5 : 1))

                        Text("·")
                            .foregroundStyle(Brand.muted)

                        Text(task.preparationNote)
                            .font(.miseMeta)
                            .foregroundStyle(Brand.muted)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
