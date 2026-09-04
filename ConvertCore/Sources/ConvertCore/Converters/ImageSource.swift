import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// A decoded image, able to render itself at an arbitrary target pixel size.
protocol ImageSource {
    var originalPixelSize: CGSize { get }
    func renderCGImage(at targetSize: CGSize) throws -> CGImage
}

/// Any ImageIO-decodable raster format (PNG, JPEG, HEIC, TIFF, GIF, BMP, WebP). Resizing happens
/// after decoding, by resampling the already-decoded bitmap.
struct RasterImageSource: ImageSource {
    let cgImage: CGImage
    let originalPixelSize: CGSize

    init(fileURL: URL) throws {
        guard
            let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ConversionError.sourceUnreadable
        }
        self.cgImage = image
        self.originalPixelSize = CGSize(width: image.width, height: image.height)
    }

    func renderCGImage(at targetSize: CGSize) throws -> CGImage {
        ResizeEngine.resize(cgImage, to: targetSize)
    }
}

/// SVG isn't an ImageIO format. AppKit's `NSImage` renders SVG natively, so vector content is
/// rasterized directly at the requested output size instead of resizing an intermediate bitmap.
struct VectorImageSource: ImageSource {
    let nsImage: NSImage
    let originalPixelSize: CGSize

    init(fileURL: URL) throws {
        guard let image = NSImage(contentsOf: fileURL) else {
            throw ConversionError.sourceUnreadable
        }
        self.nsImage = image
        self.originalPixelSize = image.size
    }

    func renderCGImage(at targetSize: CGSize) throws -> CGImage {
        let width = max(1, Int(targetSize.width.rounded()))
        let height = max(1, Int(targetSize.height.rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.destinationWriteFailed(underlying: "Could not create a rasterization context for SVG")
        }

        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        nsImage.draw(
            in: CGRect(x: 0, y: 0, width: width, height: height),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let image = context.makeImage() else {
            throw ConversionError.destinationWriteFailed(underlying: "Could not rasterize SVG at the target size")
        }
        return image
    }
}

enum ImageSourceFactory {
    static func make(fileURL: URL, kind: FileKind) throws -> any ImageSource {
        switch kind {
        case .svg:
            try VectorImageSource(fileURL: fileURL)
        default:
            try RasterImageSource(fileURL: fileURL)
        }
    }
}
