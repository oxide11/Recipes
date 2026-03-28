import SwiftUI
import SwiftData

// MARK: - Meal Plan View

struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MealPlan.startDate, order: .reverse) private var mealPlans: [MealPlan]

    @State private var showingCreatePlan = false
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack {
                // Week date picker
                DatePicker(
                    "Week of",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                if let activePlan = activeMealPlan {
                    mealPlanDetail(activePlan)
                } else {
                    ContentUnavailableView(
                        "No Meal Plan",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create a meal plan for this week.")
                    )
                    .frame(maxHeight: .infinity)

                    Button("Create Meal Plan") {
                        showingCreatePlan = true
                    }
                    .buttonStyle(.glass)
                    .padding()
                }
            }
            .navigationTitle("Meal Plan")
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Plan", systemImage: "plus") {
                        showingCreatePlan = true
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlan) {
                CreateMealPlanView()
            }
        }
    }

    private var activeMealPlan: MealPlan? {
        mealPlans.first { plan in
            plan.startDate <= selectedDate && plan.endDate >= selectedDate
        }
    }

    private func mealPlanDetail(_ plan: MealPlan) -> some View {
        List {
            Section("Overview") {
                LabeledContent("Total Prep Time", value: "\(plan.totalPrepTimeMinutes) min")
                if let budget = plan.budgetTarget {
                    LabeledContent("Budget", value: budget, format: .currency(code: "USD"))
                }
                if let cal = plan.calorieTarget {
                    LabeledContent("Daily Calories", value: "\(cal)")
                }
            }

            ForEach(MealType.allCases, id: \.self) { mealType in
                let meals = plan.meals.filter { $0.mealType == mealType }
                if !meals.isEmpty {
                    Section(mealType.rawValue.capitalized) {
                        ForEach(meals) { meal in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(meal.recipe?.title ?? "Unassigned")
                                        .fontWeight(.medium)
                                    Text(meal.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if meal.isCompleted {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Create Meal Plan View

struct CreateMealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 86400)
    @State private var budgetTarget = ""
    @State private var calorieTarget = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Plan Name", text: $name)
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)

                Section("Goals (Optional)") {
                    TextField("Weekly Budget ($)", text: $budgetTarget)
                        .keyboardType(.decimalPad)
                    TextField("Daily Calorie Target", text: $calorieTarget)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let plan = MealPlan(
                            name: name.isEmpty ? "Meal Plan" : name,
                            startDate: startDate,
                            endDate: endDate,
                            budgetTarget: Double(budgetTarget),
                            calorieTarget: Int(calorieTarget)
                        )
                        modelContext.insert(plan)
                        dismiss()
                    }
                }
            }
        }
    }
}
