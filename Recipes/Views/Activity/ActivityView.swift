import SwiftUI

// MARK: - Activity Segments

private enum ActivitySegment: String, CaseIterable {
    case stats     = "Cooking Stats"
    case nutrition = "Nutrition"
    case journal   = "Journal"
}

// MARK: - Activity View

/// Combined tab: Cooking Stats · Nutrition · Journal.
/// Groups lower-frequency features under one roof.
struct ActivityView: View {
    @State private var segment: ActivitySegment = .stats

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("Section", selection: $segment) {
                ForEach(ActivitySegment.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Content
            switch segment {
            case .stats:
                MetricsView()
            case .nutrition:
                NavigationStack {
                    NutritionTrackingView()
                        .navigationTitle("Nutrition")
                }
            case .journal:
                RestaurantJournalView()
            }
        }
    }
}
