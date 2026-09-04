import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit

/// Encodes a decoded image into the bytes for a given `OutputFormat`.
enum ImageEncoder {
    static func encode(_ cgImage: CGImage, format: OutputFormat, quality: Int?) throws -> Data {
        switch format {
        case .jpeg, .png, .tiff, .heic:
            try encodeWithImageIO(cgImage, format: format, quality: quality)
        case .webp:
            try WebPImageEncoder.encode(cgImage, quality: quality ?? 85)
        case .pdf:
            try encodePDF(cgImage)
        }
    }

    private static func encodeWithImageIO(_ cgImage: CGImage, format: OutputFormat, quality: Int?) throws -> Data {
        guard let utType = format.imageIODestinationType else {
            throw ConversionError.unsupportedOutputFormat(format)
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, utType.identifier as CFString, 1, nil) else {
            throw ConversionError.destinationWriteFailed(underlying: "CGImageDestinationCreateWithData returned nil for \(utType.identifier)")
        }

        var properties: [CFString: Any] = [:]
        if format.supportsQuality, let quality {
            properties[kCGImageDestinationLossyCompressionQuality] = Double(quality) / 100.0
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.destinationWriteFailed(underlying: "CGImageDestinationFinalize failed for \(utType.identifier)")
        }
        return data as Data
    }

    private static func encodePDF(_ cgImage: CGImage) throws -> Data {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let nsImage = NSImage(cgImage: cgImage, size: size)
        guard let page = PDFPage(image: nsImage) else {
            throw ConversionError.destinationWriteFailed(underlying: "PDFPage(image:) returned nil")
        }
        let document = PDFDocument()
        document.insert(page, at: 0)
        guard let data = document.dataRepresentation() else {
            throw ConversionError.destinationWriteFailed(underlying: "PDFDocument.dataRepresentation() returned nil")
        }
        return data
    }
}
