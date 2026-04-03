import UIKit

// MARK: - Photo Storage Service

/// Manages recipe photo files on disk.
/// Photos are stored as JPEG files in the app's Documents/RecipePhotos directory,
/// named by UUID so paths are deterministic and writes are idempotent.
enum PhotoStorageService {

    // MARK: - Directory

    private static var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("RecipePhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Helpers

    /// Full URL for a stored photo filename.
    static func url(for filename: String) -> URL {
        photosDirectory.appendingPathComponent(filename)
    }

    // MARK: - Write

    /// Saves JPEG data to disk for the given UUID, returning the filename.
    /// Idempotent — overwrites silently if the file already exists.
    @discardableResult
    static func save(_ data: Data, id: UUID) throws -> String {
        let filename = "\(id.uuidString).jpg"
        try data.write(to: url(for: filename), options: .atomic)
        return filename
    }

    // MARK: - Read

    /// Loads a photo from disk on a background thread, returning a UIImage.
    static func loadImage(filename: String) async -> UIImage? {
        let fileURL = url(for: filename)
        return await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)
        }.value
    }

    // MARK: - Delete

    /// Removes the photo file from disk. Silent no-op if the file is missing.
    static func delete(filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}

// MARK: - ModelContext + Photo Deletion

import SwiftData

extension ModelContext {
    /// Deletes the on-disk file before removing the SwiftData record.
    func deletePhoto(_ photo: RecipePhoto) {
        PhotoStorageService.delete(filename: photo.imageFilename)
        delete(photo)
    }

    /// Deletes all photo files for a recipe before removing the record.
    func deleteRecipe(_ recipe: Recipe) {
        for photo in recipe.photos {
            PhotoStorageService.delete(filename: photo.imageFilename)
        }
        for entry in recipe.cookingLog {
            if let photo = entry.photo {
                PhotoStorageService.delete(filename: photo.imageFilename)
            }
        }
        delete(recipe)
    }
}
