import SwiftUI
import SwiftData
import MapKit

// MARK: - Restaurant Journal View

struct RestaurantJournalView: View {
    enum InitialTab { case journal, wantToTry }

    var initialTab: InitialTab = .journal

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RestaurantJournalEntry.dateVisited, order: .reverse) private var entries: [RestaurantJournalEntry]
    @Query(sort: \RestaurantWantToTry.dateAdded, order: .reverse) private var wantToTry: [RestaurantWantToTry]

    @State private var selectedSegment = 0
    @State private var showingAddEntry = false
    @State private var showingAddWantToTry = false
    @State private var entryToDelete: RestaurantJournalEntry?
    @State private var wantToTryToDelete: RestaurantWantToTry?
    @State private var showingMap = false
    @State private var selectedEntry: RestaurantJournalEntry?
    @State private var selectedWantToTry: RestaurantWantToTry?

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
            .onAppear { selectedSegment = initialTab == .wantToTry ? 1 : 0 }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingMap = true
                    } label: {
                        Image(systemName: "globe.americas")
                    }
                    .accessibilityLabel("View Map")

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
            .sheet(isPresented: $showingMap) {
                RestaurantMapView(entries: entries, wantToTry: wantToTry)
            }
            .sheet(item: $selectedEntry) { entry in
                RestaurantEntryDetailView(entry: entry)
            }
            .sheet(item: $selectedWantToTry) { restaurant in
                WantToTryDetailView(restaurant: restaurant)
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
                                StarRatingView(rating: rating)
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

                        if !entry.dishesOrdered.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "fork.knife")
                                    .font(.caption2)
                                    .foregroundStyle(Brand.warmTan)
                                Text(entry.dishesOrdered.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        if let review = entry.review {
                            Text(review)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedEntry = entry }
                    .contextMenu {
                        ShareLink(
                            item: shareText(for: entry),
                            subject: Text(entry.restaurantName),
                            message: Text("Check out \(entry.restaurantName)!")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        ShareLink(
                            item: recommendText(for: entry),
                            subject: Text("Restaurant Recommendation"),
                            message: Text("I recommend \(entry.restaurantName)")
                        ) {
                            Label("Recommend", systemImage: "hand.thumbsup")
                        }

                        if entry.hasCoordinates {
                            Button {
                                openInMaps(entry.restaurantName, latitude: entry.latitude!, longitude: entry.longitude!)
                            } label: {
                                Label("View on Map", systemImage: "map")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Entry",
            isPresented: .init(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    entryToDelete = nil
                }
            }
        } message: {
            Text("Delete your review of \"\(entryToDelete?.restaurantName ?? "")\"?")
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
                                    .foregroundStyle(Brand.herbGreen)
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
                    .contentShape(Rectangle())
                    .onTapGesture { selectedWantToTry = restaurant }
                    .contextMenu {
                        ShareLink(
                            item: "Check out \(restaurant.restaurantName)\(restaurant.location.map { " in \($0)" } ?? "")!",
                            subject: Text(restaurant.restaurantName)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        if restaurant.hasCoordinates {
                            Button {
                                openInMaps(restaurant.restaurantName, latitude: restaurant.latitude!, longitude: restaurant.longitude!)
                            } label: {
                                Label("View on Map", systemImage: "map")
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            wantToTryToDelete = restaurant
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Restaurant",
            isPresented: .init(
                get: { wantToTryToDelete != nil },
                set: { if !$0 { wantToTryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = wantToTryToDelete {
                    modelContext.delete(item)
                    wantToTryToDelete = nil
                }
            }
        } message: {
            Text("Remove \"\(wantToTryToDelete?.restaurantName ?? "")\" from your list?")
        }
    }

    // MARK: - Helpers

    private func shareText(for entry: RestaurantJournalEntry) -> String {
        var text = entry.restaurantName
        if let location = entry.location { text += " — \(location)" }
        if let cuisine = entry.cuisine { text += " (\(cuisine.rawValue.capitalized))" }
        if let rating = entry.rating { text += " \(String(repeating: "⭐️", count: rating))" }
        if let review = entry.review { text += "\n\(review)" }
        return text
    }

    private func recommendText(for entry: RestaurantJournalEntry) -> String {
        var text = "I recommend \(entry.restaurantName)"
        if let location = entry.location { text += " in \(location)" }
        if let cuisine = entry.cuisine { text += " for \(cuisine.rawValue.capitalized) food" }
        text += "!"
        if let review = entry.review {
            let excerpt = review.prefix(100)
            text += " \"\(excerpt)\(review.count > 100 ? "..." : "")\""
        }
        return text
    }

    private func openInMaps(_ name: String, latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = name
        item.openInMaps()
    }
}

// MARK: - Restaurant Map View

struct RestaurantMapView: View {
    let entries: [RestaurantJournalEntry]
    let wantToTry: [RestaurantWantToTry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map {
                ForEach(entries.filter(\.hasCoordinates)) { entry in
                    Annotation(entry.restaurantName, coordinate: CLLocationCoordinate2D(
                        latitude: entry.latitude!,
                        longitude: entry.longitude!
                    )) {
                        VStack(spacing: 2) {
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Brand.herbGreen)
                            Text(entry.restaurantName)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }

                ForEach(wantToTry.filter(\.hasCoordinates)) { restaurant in
                    Annotation(restaurant.restaurantName, coordinate: CLLocationCoordinate2D(
                        latitude: restaurant.latitude!,
                        longitude: restaurant.longitude!
                    )) {
                        VStack(spacing: 2) {
                            Image(systemName: "bookmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Brand.warmTan)
                            Text(restaurant.restaurantName)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Restaurant Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Visited", systemImage: "fork.knife.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.herbGreen)
                    Label("Want to Try", systemImage: "bookmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.warmTan)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
                .padding()
            }
        }
    }
}

// MARK: - Location Search Helper

/// Resolved place data from MKLocalSearch, including auto-populated fields.
struct ResolvedPlace: @unchecked Sendable {
    let name: String
    let address: String?
    let coordinate: CLLocationCoordinate2D
    let phoneNumber: String?
    let url: URL?
    let mapItem: MKMapItem

    /// Heuristic cuisine inference from point-of-interest category or name.
    var inferredCuisine: Cuisine? {
        let lower = name.lowercased()
        if lower.contains("sushi") || lower.contains("ramen") || lower.contains("izakaya") { return .japanese }
        if lower.contains("pizza") || lower.contains("trattoria") || lower.contains("osteria") { return .italian }
        if lower.contains("taco") || lower.contains("burrito") { return .mexican }
        if lower.contains("curry") || lower.contains("tandoori") || lower.contains("masala") { return .indian }
        if lower.contains("pho") || lower.contains("banh mi") { return .vietnamese }
        if lower.contains("bibimbap") || lower.contains("korean") { return .korean }
        if lower.contains("dim sum") || lower.contains("szechuan") || lower.contains("wok") { return .chinese }
        if lower.contains("thai") || lower.contains("pad thai") { return .thai }
        if lower.contains("bistro") || lower.contains("brasserie") || lower.contains("crêpe") { return .french }
        return nil
    }

    /// Heuristic price range inference.
    var inferredPriceRange: PriceRange? {
        let lower = name.lowercased()
        if lower.contains("fine") || lower.contains("gourmet") { return .fine }
        if lower.contains("bistro") || lower.contains("steakhouse") { return .upscale }
        return nil
    }
}

@Observable
@MainActor
class LocationSearchService {
    var results: [MKLocalSearchCompletion] = []
    private var completer: MKLocalSearchCompleter
    private var delegate: SearchDelegate?

    init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = .pointOfInterest
        let del = SearchDelegate()
        del.parent = self
        delegate = del
        completer.delegate = del
    }

    func search(_ query: String) {
        completer.queryFragment = query
    }

    func resolveCoordinates(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first?.location.coordinate
        } catch {
            return nil
        }
    }

    func resolvePlace(for completion: MKLocalSearchCompletion) async -> ResolvedPlace? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .pointOfInterest
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let address = item.address?.shortAddress ?? item.address?.fullAddress
            return ResolvedPlace(
                name: item.name ?? completion.title,
                address: address,
                coordinate: item.location.coordinate,
                phoneNumber: item.phoneNumber,
                url: item.url,
                mapItem: item
            )
        } catch {
            return nil
        }
    }

    private class SearchDelegate: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
        weak var parent: LocationSearchService?

        @MainActor
        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            parent?.results = completer.results
        }
    }
}

// MARK: - Restaurant Entry Detail View

struct RestaurantEntryDetailView: View {
    @Bindable var entry: RestaurantJournalEntry
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let rating = entry.rating {
                        StarRatingView(rating: rating, font: .title2)
                    }
                    if let cuisine = entry.cuisine {
                        LabeledContent("Cuisine", value: cuisine.rawValue.capitalized)
                    }
                    if let price = entry.priceRange {
                        LabeledContent("Price", value: price.displayString)
                    }
                    if let location = entry.location {
                        LabeledContent("Location", value: location)
                    }
                    LabeledContent("Visited", value: entry.dateVisited.formatted(date: .long, time: .omitted))
                }

                if !entry.dishesOrdered.isEmpty {
                    Section("Dishes Ordered") {
                        ForEach(entry.dishesOrdered, id: \.name) { dish in
                            DishEntryRow(dish: dish)
                        }
                    }
                }

                if let review = entry.review, !review.isEmpty {
                    Section("Review") {
                        Text(review)
                            .font(.body)
                    }
                }
            }
            .navigationTitle(entry.restaurantName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditRestaurantEntryView(entry: entry)
            }
        }
    }
}

// MARK: - Edit Restaurant Entry View

struct EditRestaurantEntryView: View {
    @Bindable var entry: RestaurantJournalEntry
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var location: String
    @State private var cuisine: Cuisine
    @State private var rating: Int
    @State private var review: String
    @State private var priceRange: PriceRange

    init(entry: RestaurantJournalEntry) {
        self.entry = entry
        _name = State(initialValue: entry.restaurantName)
        _location = State(initialValue: entry.location ?? "")
        _cuisine = State(initialValue: entry.cuisine ?? .other)
        _rating = State(initialValue: entry.rating ?? 3)
        _review = State(initialValue: entry.review ?? "")
        _priceRange = State(initialValue: entry.priceRange ?? .moderate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Restaurant") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                }
                Section("Details") {
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
                }
                Section("Rating") {
                    StarRatingView(rating: rating, font: .title2) { rating = $0 }
                        .sensoryFeedback(.selection, trigger: rating)
                }
                Section("Review") {
                    TextField("What did you think?", text: $review, axis: .vertical)
                        .lineLimit(5)
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.restaurantName = name
                        entry.location = location.isEmpty ? nil : location
                        entry.cuisine = cuisine
                        entry.rating = rating
                        entry.review = review.isEmpty ? nil : review
                        entry.priceRange = priceRange
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Want to Try Detail View

struct WantToTryDetailView: View {
    @Bindable var restaurant: RestaurantWantToTry
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let location = restaurant.location {
                        LabeledContent("Location", value: location)
                    }
                    if let cuisine = restaurant.cuisine {
                        LabeledContent("Cuisine", value: cuisine.rawValue.capitalized)
                    }
                    LabeledContent("Added", value: restaurant.dateAdded.formatted(date: .long, time: .omitted))
                    if restaurant.hasVisited {
                        Label("Marked as visited", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Brand.herbGreen)
                            .font(.subheadline)
                    }
                }
                if let reason = restaurant.reason, !reason.isEmpty {
                    Section("Why I Want to Try It") {
                        Text(reason)
                    }
                }
                if let urlString = restaurant.sourceURL, let url = URL(string: urlString) {
                    Section {
                        Link(destination: url) {
                            Label("View Source", systemImage: "link")
                        }
                    }
                }
            }
            .navigationTitle(restaurant.restaurantName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditWantToTryView(restaurant: restaurant)
            }
        }
    }
}

// MARK: - Edit Want to Try View

struct EditWantToTryView: View {
    @Bindable var restaurant: RestaurantWantToTry
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var location: String
    @State private var cuisine: Cuisine
    @State private var reason: String
    @State private var hasVisited: Bool

    init(restaurant: RestaurantWantToTry) {
        self.restaurant = restaurant
        _name       = State(initialValue: restaurant.restaurantName)
        _location   = State(initialValue: restaurant.location ?? "")
        _cuisine    = State(initialValue: restaurant.cuisine ?? .other)
        _reason     = State(initialValue: restaurant.reason ?? "")
        _hasVisited = State(initialValue: restaurant.hasVisited)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Restaurant") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                }
                Section("Details") {
                    Picker("Cuisine", selection: $cuisine) {
                        ForEach(Cuisine.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }
                }
                Section("Notes") {
                    TextField("Why do you want to try it?", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Toggle("Mark as Visited", isOn: $hasVisited)
                } footer: {
                    Text("Once visited, you can add a full journal entry from the Journal tab.")
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        restaurant.restaurantName = name
                        restaurant.location   = location.isEmpty ? nil : location
                        restaurant.cuisine    = cuisine
                        restaurant.reason     = reason.isEmpty ? nil : reason
                        restaurant.hasVisited = hasVisited
                        dismiss()
                    }
                    .disabled(name.isEmpty)
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
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @State private var locationSearch = LocationSearchService()
    @State private var showingSearchResults = false
    @State private var resolvedPlace: ResolvedPlace?
    @State private var dishes: [DishEntry] = []
    @State private var showingAddDish = false
    @State private var selectedPhoneNumber: String?
    @State private var selectedMapsURL: String?

    var body: some View {
        NavigationStack {
            Form {
                // Restaurant search
                Section("Restaurant") {
                    TextField("Restaurant Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count >= 3 {
                                locationSearch.search(newValue)
                                showingSearchResults = true
                            } else {
                                showingSearchResults = false
                            }
                        }

                    if showingSearchResults && !locationSearch.results.isEmpty {
                        ForEach(locationSearch.results.prefix(5), id: \.self) { result in
                            Button {
                                Task { await selectRestaurant(result) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .font(.subheadline)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                // Details (auto-populated, editable)
                Section("Details") {
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

                    if selectedLatitude != nil {
                        Label("Location set", systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Brand.herbGreen)
                    }
                }

                // Open in Maps
                if let resolvedPlace {
                    Section {
                        Button {
                            resolvedPlace.mapItem.openInMaps()
                        } label: {
                            Label("Open in Apple Maps", systemImage: "map.fill")
                        }

                        if let phone = resolvedPlace.phoneNumber {
                            LabeledContent("Phone", value: phone)
                        }
                    }
                }

                // Rating
                Section("Rating") {
                    StarRatingView(rating: rating, font: .title2) { rating = $0 }
                        .sensoryFeedback(.selection, trigger: rating)
                }

                // Dishes Ordered
                Section("Dishes Ordered") {
                    ForEach(dishes, id: \.name) { dish in
                        DishEntryRow(dish: dish)
                    }
                    .onDelete { indices in
                        dishes.remove(atOffsets: indices)
                    }

                    Button {
                        showingAddDish = true
                    } label: {
                        Label("Add Dish", systemImage: "plus.circle")
                    }
                }

                // Review
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
                            priceRange: priceRange,
                            latitude: selectedLatitude,
                            longitude: selectedLongitude,
                            phoneNumber: selectedPhoneNumber,
                            mapsURL: selectedMapsURL
                        )
                        entry.dishesOrdered = dishes
                        modelContext.insert(entry)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddDish) {
                AddDishView { dish in
                    dishes.append(dish)
                }
            }
        }
    }

    private func selectRestaurant(_ result: MKLocalSearchCompletion) async {
        name = result.title
        showingSearchResults = false
        if let place = await locationSearch.resolvePlace(for: result) {
            resolvedPlace = place
            location = place.address ?? "\(result.title), \(result.subtitle)"
            selectedLatitude = place.coordinate.latitude
            selectedLongitude = place.coordinate.longitude
            selectedPhoneNumber = place.phoneNumber
            selectedMapsURL = place.url?.absoluteString
            if let inferredCuisine = place.inferredCuisine {
                cuisine = inferredCuisine
            }
            if let inferredPrice = place.inferredPriceRange {
                priceRange = inferredPrice
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
    @State private var cuisine: Cuisine = .other
    @State private var reason = ""
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @State private var locationSearch = LocationSearchService()
    @State private var showingSearchResults = false
    @State private var resolvedPlace: ResolvedPlace?

    var body: some View {
        NavigationStack {
            Form {
                // Restaurant search
                Section("Restaurant") {
                    TextField("Restaurant Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count >= 3 {
                                locationSearch.search(newValue)
                                showingSearchResults = true
                            } else {
                                showingSearchResults = false
                            }
                        }

                    if showingSearchResults && !locationSearch.results.isEmpty {
                        ForEach(locationSearch.results.prefix(5), id: \.self) { result in
                            Button {
                                Task { await selectRestaurant(result) }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(result.title)
                                        .font(.subheadline)
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                Section("Details") {
                    TextField("Location", text: $location)

                    Picker("Cuisine", selection: $cuisine) {
                        ForEach(Cuisine.allCases, id: \.self) { c in
                            Text(c.rawValue.capitalized).tag(c)
                        }
                    }

                    if selectedLatitude != nil {
                        Label("Location set", systemImage: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Brand.herbGreen)
                    }
                }

                // Open in Maps
                if let resolvedPlace {
                    Section {
                        Button {
                            resolvedPlace.mapItem.openInMaps()
                        } label: {
                            Label("Open in Apple Maps", systemImage: "map.fill")
                        }
                    }
                }

                Section("Reason") {
                    TextField("Why do you want to try it?", text: $reason, axis: .vertical)
                }
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
                            cuisine: cuisine,
                            reason: reason.isEmpty ? nil : reason,
                            latitude: selectedLatitude,
                            longitude: selectedLongitude
                        )
                        modelContext.insert(entry)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func selectRestaurant(_ result: MKLocalSearchCompletion) async {
        name = result.title
        showingSearchResults = false
        if let place = await locationSearch.resolvePlace(for: result) {
            resolvedPlace = place
            location = place.address ?? "\(result.title), \(result.subtitle)"
            selectedLatitude = place.coordinate.latitude
            selectedLongitude = place.coordinate.longitude
            if let inferredCuisine = place.inferredCuisine {
                cuisine = inferredCuisine
            }
        }
    }
}

// MARK: - Dish Entry Row

struct DishEntryRow: View {
    let dish: DishEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(dish.name)
                    .fontWeight(.medium)
                Spacer()
                if let rating = dish.rating {
                    StarRatingView(rating: rating)
                }
            }

            if let notes = dish.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if dish.wouldOrderAgain {
                    Label("Would order again", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundStyle(Brand.herbGreen)
                }
                if dish.wantToRecreate {
                    Label("Want to recreate", systemImage: "frying.pan")
                        .font(.caption2)
                        .foregroundStyle(Brand.warmTan)
                }
            }
        }
    }
}

// MARK: - Add Dish View

struct AddDishView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var rating = 3
    @State private var notes = ""
    @State private var wouldOrderAgain = true
    @State private var wantToRecreate = false

    let onSave: (DishEntry) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Dish Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3)

                Section("Rating") {
                    StarRatingView(rating: rating, font: .title2) { rating = $0 }
                        .sensoryFeedback(.selection, trigger: rating)
                }

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3)
                Toggle("Would Order Again", isOn: $wouldOrderAgain)
                Toggle("Want to Recreate at Home", isOn: $wantToRecreate)
            }
            .navigationTitle("Add Dish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let dish = DishEntry(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            rating: rating,
                            notes: notes.isEmpty ? nil : notes,
                            wouldOrderAgain: wouldOrderAgain,
                            wantToRecreate: wantToRecreate
                        )
                        onSave(dish)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
