import SwiftUI
import SwiftData

// MARK: - Restaurant Journal View

struct RestaurantJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RestaurantJournalEntry.dateVisited, order: .reverse) private var entries: [RestaurantJournalEntry]
    @Query(sort: \RestaurantWantToTry.dateAdded, order: .reverse) private var wantToTry: [RestaurantWantToTry]

    @State private var selectedSegment = 0
    @State private var showingAddEntry = false
    @State private var showingAddWantToTry = false

    var body: some View {
        NavigationStack {
            VStack {
                Picker("View", selection: $selectedSegment) {
                    Text("Journal").tag(0)
                    Text("Want to Try").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if selectedSegment == 0 {
                    journalList
                } else {
                    wantToTryList
                }
            }
            .navigationTitle("Restaurant Journal")
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") {
                        if selectedSegment == 0 {
                            showingAddEntry = true
                        } else {
                            showingAddWantToTry = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddRestaurantEntryView()
            }
            .sheet(isPresented: $showingAddWantToTry) {
                AddWantToTryView()
            }
        }
    }

    private var journalList: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "fork.knife.circle",
                    description: Text("Log your restaurant visits here.")
                )
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.restaurantName)
                                .fontWeight(.semibold)
                            Spacer()
                            if let rating = entry.rating {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                            }
                        }

                        if let location = entry.location {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text(entry.dateVisited, style: .date)
                            if let cuisine = entry.cuisine {
                                Text(cuisine.rawValue.capitalized)
                            }
                            if let price = entry.priceRange {
                                Text(price.displayString)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let review = entry.review {
                            Text(review)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(entries[offset])
                    }
                }
            }
        }
    }

    private var wantToTryList: some View {
        List {
            if wantToTry.isEmpty {
                ContentUnavailableView(
                    "No Restaurants Saved",
                    systemImage: "bookmark",
                    description: Text("Save restaurants you want to visit.")
                )
            } else {
                ForEach(wantToTry) { restaurant in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(restaurant.restaurantName)
                                .fontWeight(.medium)
                            Spacer()
                            if restaurant.hasVisited {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }

                        if let location = restaurant.location {
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let reason = restaurant.reason {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(wantToTry[offset])
                    }
                }
            }
        }
    }
}

// MARK: - Add Restaurant Entry

struct AddRestaurantEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var cuisine: Cuisine = .other
    @State private var rating = 3
    @State private var review = ""
    @State private var priceRange: PriceRange = .moderate

    var body: some View {
        NavigationStack {
            Form {
                TextField("Restaurant Name", text: $name)
                TextField("Location", text: $location)

                Picker("Cuisine", selection: $cuisine) {
                    ForEach(Cuisine.allCases, id: \.self) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }

                Picker("Price Range", selection: $priceRange) {
                    ForEach(PriceRange.allCases, id: \.self) { p in
                        Text(p.displayString).tag(p)
                    }
                }

                Section("Rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                            }
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }
                    .sensoryFeedback(.selection, trigger: rating)
                }

                Section("Review") {
                    TextField("What did you think?", text: $review, axis: .vertical)
                        .lineLimit(5)
                }
            }
            .navigationTitle("New Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = RestaurantJournalEntry(
                            restaurantName: name,
                            location: location.isEmpty ? nil : location,
                            cuisine: cuisine,
                            rating: rating,
                            review: review.isEmpty ? nil : review,
                            priceRange: priceRange
                        )
                        modelContext.insert(entry)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Want to Try

struct AddWantToTryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var location = ""
    @State private var reason = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Restaurant Name", text: $name)
                TextField("Location", text: $location)
                TextField("Why do you want to try it?", text: $reason, axis: .vertical)
            }
            .navigationTitle("Want to Try")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = RestaurantWantToTry(
                            restaurantName: name,
                            location: location.isEmpty ? nil : location,
                            reason: reason.isEmpty ? nil : reason
                        )
                        modelContext.insert(entry)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
