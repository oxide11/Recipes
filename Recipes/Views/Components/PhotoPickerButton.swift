import SwiftUI
import PhotosUI

// MARK: - Photo Picker Button
//
// Wraps PhotosPicker with a label that depends only on a plain Bool.
// PhotosPicker's label closure is @Sendable, so it cannot safely capture
// @MainActor-isolated @State properties from a parent view. Passing the
// state as a Sendable Bool parameter sidesteps the data-race warning.

struct PhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label(
                hasPhoto ? "Change Photo" : "Add Photo",
                systemImage: hasPhoto ? "camera.badge.ellipsis" : "camera.badge.plus"
            )
        }
    }
}

// MARK: - Import-style variant (shows "Photo Selected" confirmation)

struct ImportPhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            if hasPhoto {
                Label("Photo Selected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        }
    }
}
