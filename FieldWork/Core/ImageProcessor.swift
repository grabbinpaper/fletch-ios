import UIKit

struct ImageProcessor {

    /// Compress an image by resizing the longest edge and applying JPEG compression.
    /// Typical output: 150–300 KB from a 4–12 MB original.
    static func compress(
        _ image: UIImage,
        maxDimension: CGFloat = 1200,
        quality: CGFloat = 0.72
    ) -> Data? {
        let resized = resizeImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    /// Generate a small square thumbnail for grid display.
    /// Typical output: 10–20 KB.
    static func generateThumbnail(_ image: UIImage, size: CGFloat = 200) -> Data? {
        let shortest = min(image.size.width, image.size.height)
        let cropRect = CGRect(
            x: (image.size.width - shortest) / 2,
            y: (image.size.height - shortest) / 2,
            width: shortest,
            height: shortest
        )

        guard let cgImage = image.cgImage,
              let cropped = cgImage.cropping(to: cropRect) else {
            // Fall back to simple resize
            let resized = resizeImage(image, maxDimension: size)
            return resized.jpegData(compressionQuality: 0.7)
        }

        let croppedImage = UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        let resized = resizeImage(croppedImage, maxDimension: size)
        return resized.jpegData(compressionQuality: 0.7)
    }

    /// Composite a markup drawing over a base photo.
    static func compositeMarkup(base: UIImage, markup: UIImage) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: base.size)
        return renderer.image { _ in
            base.draw(at: .zero)
            markup.draw(in: CGRect(origin: .zero, size: base.size))
        }
    }

    // MARK: - Private

    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)

        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
