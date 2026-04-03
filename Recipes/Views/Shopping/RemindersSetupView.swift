import EventKit
import SwiftUI

// MARK: - Reminders Setup View

/// Shown the first time the user opens Shopping, letting them pick an existing
/// Reminders list or create a new one (e.g. "Shopping").
struct RemindersSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var sync: RemindersSync
    var groceryList: GroceryList?

    @State private var calendars: [EKCalendar] = []
    @State private var newListName = "Shopping"
    @State private var isRequesting = false
    @State private var isMigrating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if sync.authorizationStatus == .fullAccess {
                    pickerContent
                } else {
                    permissionContent
                }
            }
            .navigationTitle("Sync with Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                        .disabled(isMigrating)
                }
            }
            .overlay {
                if isMigrating {
                    ZStack {
                        Color(.systemBackground).opacity(0.85)
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Merging lists…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            .onAppear {
                if sync.authorizationStatus == .fullAccess {
                    calendars = sync.availableCalendars()
                }
            }
        }
    }

    // MARK: - Permission Screen

    private var permissionContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(Brand.herbGreen)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Keep your list in sync")
                    .font(.title2.bold())
                Text("Add items via Siri, check them off on Apple Watch — everything stays in sync with Mise automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button {
                Task {
                    isRequesting = true
                    let granted = await sync.requestAccess()
                    isRequesting = false
                    if granted {
                        calendars = sync.availableCalendars()
                    }
                }
            } label: {
                Label(isRequesting ? "Requesting…" : "Allow Reminders Access",
                      systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Brand.herbGreen)
            .disabled(isRequesting)
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }

    // MARK: - List Picker

    private var pickerContent: some View {
        List {
            // Currently linked list
            if let linked = sync.linkedCalendar {
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(cgColor: linked.cgColor))
                            .frame(width: 12, height: 12)
                        Text(linked.title)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Unlink", role: .destructive) {
                            sync.unlink()
                            dismiss()
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("Currently synced to")
                } footer: {
                    Text("\"Hey Siri, add oat milk to my \(linked.title) list\" adds it here.")
                }
            }

            // Create new list
            Section {
                HStack {
                    TextField("List name", text: $newListName)
                    Button("Create") { createAndLink() }
                        .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Create a new list")
            } footer: {
                Text("\"Hey Siri, add oat milk to my \(newListName.isEmpty ? "Shopping" : newListName) list\" will add it here.")
            }

            // Pick existing list
            if !calendars.isEmpty {
                Section("Or use an existing list") {
                    ForEach(calendars, id: \.calendarIdentifier) { calendar in
                        Button {
                            sync.link(to: calendar)
                            runMigrationAndDismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 12, height: 12)
                                Text(calendar.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    private func createAndLink() {
        do {
            try sync.createAndLink(named: newListName.trimmingCharacters(in: .whitespaces))
            runMigrationAndDismiss()
        } catch {
            errorMessage = "Couldn't create list: \(error.localizedDescription)"
        }
    }

    private func runMigrationAndDismiss() {
        guard let list = groceryList else { dismiss(); return }
        isMigrating = true
        Task {
            await sync.performInitialMigration(groceryList: list, context: modelContext)
            dismiss()
        }
    }
}
