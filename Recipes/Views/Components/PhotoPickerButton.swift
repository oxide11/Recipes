import SwiftUI
import PhotosUI

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Picker Button
//
// Shows a confirmation dialog to choose between camera and photo library.

struct PhotoPickerButton: View {
    @Binding var selection: PhotosPickerItem?
    let hasPhoto: Bool

    /// Optionally trigger the picker from an external boolean (e.g. from a Menu item).
    var isPresented: Binding<Bool>? = nil
    /// Called when a photo is taken directly with the camera.
    var onCameraImage: ((UIImage) -> Void)? = nil

    @State private var showingDialog = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var cameraImage: UIImage?

    var body: some View {
        Button {
            showingDialog = true
        } label: {
            Label(
                hasPhoto ? "Change Photo" : "Add Photo",
                systemImage: hasPhoto ? "camera.badge.ellipsis" : "camera.badge.plus"
            )
        }
        .confirmationDialog("Add Photo", isPresented: $showingDialog) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingLibrary = true }
            Button("Cancel", role: .cancel) {}
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
        .onChange(of: isPresented?.wrappedValue ?? false) { _, triggered in
            if triggered {
                showingDialog = true
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

    @State private var showingDialog = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var cameraImage: UIImage?

    var body: some View {
        Button {
            showingDialog = true
        } label: {
            if hasPhoto {
                Label("Photo Selected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showingDialog) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingLibrary = true }
            Button("Cancel", role: .cancel) {}
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
