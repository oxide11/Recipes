import SwiftUI
import PhotosUI

// MARK: - Photo Picker Button
//
// On devices with a camera: renders as a Menu so both "Take Photo" and
// "Choose from Library" are reachable in one tap with no popup dialog.
// On devices without a camera (simulator, some iPads): goes straight to
// the photo library.

struct PhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool

    /// Optionally trigger the library picker from an external boolean (e.g. from a Menu item).
    var isPresented: Binding<Bool>? = nil
    /// Called when a photo is taken directly with the camera.
    var onCameraImage: ((UIImage) -> Void)? = nil

    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var cameraImage: UIImage?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if cameraAvailable {
                Menu {
                    Button("Take Photo", systemImage: "camera") {
                        showingCamera = true
                    }
                    Button("Choose from Library", systemImage: "photo.on.rectangle") {
                        showingLibrary = true
                    }
                } label: {
                    Label(
                        hasPhoto ? "Change Photo" : "Add Photo",
                        systemImage: hasPhoto ? "camera.badge.ellipsis" : "camera.badge.plus"
                    )
                }
            } else {
                Button {
                    showingLibrary = true
                } label: {
                    Label(
                        hasPhoto ? "Change Photo" : "Add Photo",
                        systemImage: hasPhoto ? "camera.badge.ellipsis" : "camera.badge.plus"
                    )
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(image: $cameraImage)
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $selection, matching: .images)
        .onChange(of: cameraImage) {
            if let img = cameraImage {
                onCameraImage?(img)
                cameraImage = nil
            }
        }
        // External trigger (e.g. a toolbar Menu item) goes straight to the library —
        // the caller's menu already acts as the source chooser.
        .onChange(of: isPresented?.wrappedValue ?? false) { _, triggered in
            if triggered {
                showingLibrary = true
                isPresented?.wrappedValue = false
            }
        }
    }
}

// MARK: - Import-style variant (shows "Photo Selected" confirmation)

struct ImportPhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool
    var onCameraImage: ((UIImage) -> Void)? = nil

    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var cameraImage: UIImage?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        Group {
            if cameraAvailable {
                Menu {
                    Button("Take Photo", systemImage: "camera") {
                        showingCamera = true
                    }
                    Button("Choose from Library", systemImage: "photo.on.rectangle") {
                        showingLibrary = true
                    }
                } label: {
                    if hasPhoto {
                        Label("Photo Selected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }
                }
            } else {
                Button {
                    showingLibrary = true
                } label: {
                    if hasPhoto {
                        Label("Photo Selected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker(image: $cameraImage)
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $selection, matching: .images)
        .onChange(of: cameraImage) {
            if let img = cameraImage {
                onCameraImage?(img)
                cameraImage = nil
            }
        }
    }
}
