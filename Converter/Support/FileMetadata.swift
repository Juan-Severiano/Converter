import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Cheap, best-effort metadata reads used to populate the conversion window's preview — never
/// decodes the full image.
enum FileMetadata {
    static func pixelSize(of url: URL) -> CGSize? {
        if
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
        {
            return CGSize(width: width, height: height)
        }
        // SVG isn't an ImageIO format; fall back to AppKit's own notion of its intrinsic size.
        return NSImage(contentsOf: url)?.size
    }

    static func byteSize(of url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
