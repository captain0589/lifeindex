import UIKit

/// Manages food photo storage in the app's documents directory
class FoodImageManager {
    static let shared = FoodImageManager()

    private let fileManager = FileManager.default
    private let imageDirectory: URL

    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imageDirectory = documentsPath.appendingPathComponent("FoodImages", isDirectory: true)

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
            debugLog("[FoodImageManager] Failed to create JPEG data")
            return nil
        }

        do {
            try data.write(to: fileURL)
            debugLog("[FoodImageManager] Saved image: \(fileName)")
            return fileName
        } catch {
            debugLog("[FoodImageManager] Failed to save image: \(error)")
            return nil
        }
    }

    // MARK: - Load Image

    /// Loads an image by filename
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = imageDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            debugLog("[FoodImageManager] Image not found: \(fileName)")
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
            debugLog("[FoodImageManager] Deleted image: \(fileName)")
        } catch {
            debugLog("[FoodImageManager] Failed to delete image: \(error)")
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

    /// Returns total size of all stored images in bytes
    func totalStorageUsed() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(atPath: imageDirectory.path) else {
            return 0
        }

        var totalSize: Int64 = 0
        for file in files {
            let filePath = imageDirectory.appendingPathComponent(file).path
            if let attrs = try? fileManager.attributesOfItem(atPath: filePath),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    /// Deletes all stored images
    func clearAllImages() {
        guard let files = try? fileManager.contentsOfDirectory(atPath: imageDirectory.path) else {
            return
        }

        for file in files {
            deleteImage(fileName: file)
        }
        debugLog("[FoodImageManager] Cleared all images")
    }
}
