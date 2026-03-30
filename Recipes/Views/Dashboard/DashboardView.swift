import SwiftUI
import SwiftData

// MARK: - Dashboard Design Tokens

private enum DashboardStyle {
    static let obsidian = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let cardBackground = Color(white: 0.12)
    static let produce = Color(hex: "2ECC71")
    static let meat = Color(hex: "E74C3C")
    static let grains = Color(hex: "F5B041")

    static let aiGlow = AngularGradient(
        colors: [.cyan, .purple, .orange, .green, .cyan],
        center: .center
    )
}

// MARK: - Dashboard Tab

enum DashboardTab: String, CaseIterable {
    case mise, pantry, recipes, plan, shop

    var icon: String {
        switch self {
        case .mise:    return "sparkles"
        case .pantry:  return "archivebox"
        case .recipes: return "book.closed"
        case .plan:    return "calendar"
        case .shop:    return "cart"
        }
    }

    var label: String {
        switch self {
        case .mise:    return "Mise"
        case .pantry:  return "Pantry"
        case .recipes: return "Recipes"
        case .plan:    return "Plan"
        case .shop:    return "Shop"
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \PantryItem.expirationDate) private var pantryItems: [PantryItem]
    @Query private var plannedMeals: [PlannedMeal]
    @Query private var recipes: [Recipe]
    @Query private var receipts: [GroceryReceipt]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab: DashboardTab = .mise

    private var todaysMeals: [PlannedMeal] {
        let today = Calendar.current.startOfDay(for: Date())
        return plannedMeals.filter {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    private var expiringItems: [PantryItem] {
        pantryItems.filter { $0.isExpiringSoon && !$0.isExpired }
    }

    private var weeklySpend: Double {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return receipts.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.totalAmount }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DashboardStyle.obsidian
                .ignoresSafeArea()

            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }

            customTabBar
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                aiInsightCard
                todaysMealsSection
                weeklyBudgetSection
            }
            .padding()
            .padding(.bottom, 90) // Tab bar clearance
        }
    }

    // MARK: - iPad Layout (Multi-Column)

    private var iPadLayout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                aiInsightCard

                HStack(alignment: .top, spacing: 20) {
                    // Left column — meals
                    VStack(alignment: .leading, spacing: 16) {
                        todaysMealsSection
                    }
                    .frame(maxWidth: .infinity)

                    // Right column — budget + quick stats
                    VStack(alignment: .leading, spacing: 16) {
                        weeklyBudgetSection
                        quickStatsCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical)
            .padding(.bottom, 90)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
                    .foregroundStyle(.white)

                Text(dateString)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Spacer()

            Button {
                selectedTab = .shop
            } label: {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good Morning."
        case 12..<17: return "Good Afternoon."
        case 17..<22: return "Good Evening."
        default:      return "Good Night."
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: .now)
    }

    // MARK: - AI Insight Card

    private var aiInsightCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("AI Insight")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)

                if expiringItems.isEmpty {
                    Text("All pantry items are fresh. You're on top of it!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                } else {
                    let names = expiringItems.prefix(3).map(\.name).joined(separator: ", ")
                    Text("Pantry expiring: \(names). Tap to find recipes!")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                }

                Text("View Recipes")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.cyan)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DashboardStyle.aiGlow, lineWidth: 2)
        )
    }

    // MARK: - Today's Meals

    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Meals")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            if todaysMeals.isEmpty {
                // Show mock cards when no meals planned
                MealCardView(
                    meal: .init(type: "Lunch", name: "Quinoa Salad", iconColor: DashboardStyle.produce)
                )
                MealCardView(
                    meal: .init(type: "Dinner", name: "Pan-Seared Chicken", iconColor: DashboardStyle.meat)
                )
            } else {
                ForEach(todaysMeals, id: \.id) { meal in
                    MealCardView(
                        meal: .init(
                            type: meal.mealType.displayName,
                            name: meal.recipe?.title ?? "Unplanned",
                            iconColor: colorForMealType(meal.mealType)
                        )
                    )
                }
            }
        }
    }

    private func colorForMealType(_ type: MealType) -> Color {
        switch type {
        case .breakfast: return .orange
        case .lunch:     return DashboardStyle.produce
        case .dinner:    return DashboardStyle.meat
        case .snack:     return DashboardStyle.grains
        default:         return Brand.warmTan
        }
    }

    // MARK: - Weekly Budget

    private var weeklyBudgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Budget")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            BudgetCardView(totalSpend: weeklySpend, receipts: receipts)
        }
    }

    // MARK: - Quick Stats (iPad only)

    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Stats")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                statItem(value: "\(recipes.count)", label: "Recipes", icon: "book.closed", color: Brand.warmTan)
                statItem(value: "\(pantryItems.count)", label: "Pantry Items", icon: "archivebox", color: DashboardStyle.produce)
                statItem(value: "\(todaysMeals.count)", label: "Today's Meals", icon: "fork.knife", color: DashboardStyle.grains)
            }
            .padding()
            .background(DashboardStyle.cardBackground, in: .rect(cornerRadius: 16))
        }
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            .ultraThinMaterial,
            in: .rect(topLeadingRadius: 20, topTrailingRadius: 20)
        )
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Meal Card View

struct MealCardView: View {
    struct MealData {
        let type: String
        let name: String
        let iconColor: Color
    }

    let meal: MealData

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.type)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.gray)
                Text(meal.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(.white)
            }

            Spacer()

            Circle()
                .fill(meal.iconColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(meal.iconColor)
                }
        }
        .padding()
        .background(DashboardStyle.cardBackground, in: .rect(cornerRadius: 16))
        .contextMenu {
            Button {
                // Mark as cooked
            } label: {
                Label("Cooked", systemImage: "checkmark")
            }
            Button {
                // Swap meal
            } label: {
                Label("Swap", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
}

// MARK: - Budget Card View

struct BudgetCardView: View {
    let totalSpend: Double
    let receipts: [GroceryReceipt]

    private var recentDays: [(label: String, amount: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var days: [(String, Double)] = []

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayReceipts = receipts.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let total = dayReceipts.reduce(0) { $0 + $1.totalAmount }
            guard total > 0 else { continue }

            let label: String
            if offset == 0 { label = "Today" }
            else if offset == 1 { label = "Yesterday" }
            else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                label = formatter.string(from: date)
            }
            days.append((label, total))
        }

        return days.isEmpty
            ? [("Today", 5), ("Sunday", 20)] // Mock data fallback
            : days
    }

    var body: some View {
        HStack(spacing: 20) {
            // Donut chart
            donutChart
                .frame(width: 100, height: 100)

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(recentDays.prefix(4).enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(index == 0 ? DashboardStyle.produce : DashboardStyle.grains)
                            .frame(width: 8, height: 8)
                        Text("\(day.label) ($\(Int(day.amount)))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(DashboardStyle.cardBackground, in: .rect(cornerRadius: 16))
    }

    private var donutChart: some View {
        let displaySpend = totalSpend > 0 ? totalSpend : 25.0
        let budget = 500.0
        let fraction = min(displaySpend / budget, 1.0)

        return ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            Circle()
                .trim(from: 0, to: fraction * 0.6)
                .stroke(DashboardStyle.produce, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: fraction * 0.6, to: fraction)
                .stroke(DashboardStyle.grains, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("$\(Int(displaySpend))")
                .font(.system(.body, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview Mock Data

private struct MockMealData {
    static let lunch = MealCardView.MealData(
        type: "Lunch", name: "Quinoa Salad", iconColor: DashboardStyle.produce
    )
    static let dinner = MealCardView.MealData(
        type: "Dinner", name: "Pan-Seared Chicken", iconColor: DashboardStyle.meat
    )
}

#Preview("Dashboard - iPhone") {
    DashboardView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
}

#Preview("Dashboard - iPad") {
    DashboardView()
        .modelContainer(for: Recipe.self, inMemory: true)
        .environment(AIServiceRouter())
        .previewDevice("iPad Pro (12.9-inch)")
}
