import UIKit

/// Manages mood photo storage in the app's documents directory
class MoodImageManager {
    static let shared = MoodImageManager()

    private let fileManager = FileManager.default
    private let imageDirectory: URL

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = documentsPath.appendingPathComponent("MoodImages", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: imageDirectory.path) {
            try? fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Save Image

    /// Saves an image and returns the filename
    func saveImage(_ image: UIImage, quality: CGFloat = 0.7) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        // Resize image to max 1200px to save space
        let resizedImage = resizeImage(image, maxDimension: 1200)

        guard let data = resizedImage.jpegData(compressionQuality: quality) else {
            debugLog("[MoodImageManager] Failed to create JPEG data")
            return nil
        }

        do {
            try data.write(to: fileURL)
            debugLog("[MoodImageManager] Saved image: \(fileName)")
            return fileName
        } catch {
            debugLog("[MoodImageManager] Failed to save image: \(error)")
            return nil
        }
    }

    // MARK: - Load Image

    /// Loads an image by filename
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            debugLog("[MoodImageManager] Image not found: \(fileName)")
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Loads a thumbnail (smaller version for lists)
    func loadThumbnail(fileName: String, size: CGFloat = 60) -> UIImage? {
        guard let image = loadImage(fileName: fileName) else { return nil }
        return resizeImage(image, maxDimension: size * UIScreen.main.scale)
    }

    // MARK: - Delete Image

    /// Deletes an image by filename
    func deleteImage(fileName: String) {
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.removeItem(at: fileURL)
            debugLog("[MoodImageManager] Deleted image: \(fileName)")
        } catch {
            debugLog("[MoodImageManager] Failed to delete image: \(error)")
        }
    }

    // MARK: - Helpers

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
