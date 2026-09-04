import CoreGraphics
import Foundation
import WebP

/// ImageIO can read WebP but, as of this SDK, cannot encode it (verified via
/// `CGImageDestinationCopyTypeIdentifiers()`) — so WebP output goes through libwebp directly.
enum WebPImageEncoder {
    static func encode(_ cgImage: CGImage, quality: Int) throws -> Data {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4

        var buffer = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ConversionError.destinationWriteFailed(underlying: "Could not create an RGBA bitmap context for WebP encoding")
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // libwebp's RGBA importer expects straight (non-premultiplied) alpha; CGContext only
        // draws premultiplied, so unpremultiply each pixel before handing the buffer over.
        unpremultiply(&buffer)

        let clampedQuality = Float(max(1, min(100, quality)))
        let config = WebPEncoderConfig.preset(.default, quality: clampedQuality)

        do {
            return try buffer.withUnsafeBufferPointer { pointer in
                try WebPEncoder().encode(
                    pointer,
                    format: .rgba,
                    config: config,
                    originWidth: width,
                    originHeight: height,
                    stride: bytesPerRow
                )
            }
        } catch {
            throw ConversionError.destinationWriteFailed(underlying: "libwebp encode failed: \(error)")
        }
    }

    private static func unpremultiply(_ buffer: inout [UInt8]) {
        var index = 0
        let count = buffer.count
        while index < count {
            let alpha = buffer[index + 3]
            if alpha != 0, alpha != 255 {
                let a = Double(alpha) / 255.0
                buffer[index] = clampedByte(Double(buffer[index]) / a)
                buffer[index + 1] = clampedByte(Double(buffer[index + 1]) / a)
                buffer[index + 2] = clampedByte(Double(buffer[index + 2]) / a)
            }
            index += 4
        }
    }

    private static func clampedByte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, value.rounded())))
    }
}
