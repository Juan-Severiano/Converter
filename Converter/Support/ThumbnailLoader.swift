import AppKit
import Foundation
import ImageIO

/// Runs off the main actor deliberately — thumbnail decoding is the one part of this view that's
/// worth keeping away from the main thread, even for a small preview.
nonisolated enum ThumbnailLoader {
    static func loadThumbnail(for url: URL, maxPixelSize: CGFloat = 240) -> NSImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }
        // SVG isn't an ImageIO format; AppKit renders it directly.
        return NSImage(contentsOf: url)
    }
}
