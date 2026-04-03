import SwiftUI

// MARK: - Recipe Photo Image

/// Async-loading view for a single RecipePhoto.
/// Shows a placeholder while the image loads from disk, then cross-fades in.
struct RecipePhotoImage: View {
    let photo: RecipePhoto
    var contentMode: ContentMode = .fill

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .task(id: photo.imageFilename) {
            uiImage = await PhotoStorageService.loadImage(filename: photo.imageFilename)
        }
    }
}
