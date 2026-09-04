import CoreGraphics
import Foundation

/// The single entry point for turning one source file into one converted file.
///
/// This is the seam the test suite exercises directly: it routes through `FileTypeDetector`,
/// the right `ImageSource`/`ImageEncoder` pair, and `OutputPathResolver`, using real files on
/// disk and real ImageIO/PDFKit/libwebp calls — nothing here is mocked.
public enum ConversionEngine {
    public static func convert(job: ConversionJob) async throws -> ConversionResult {
        try Task.checkCancellation()

        guard let kind = FileTypeDetector.detect(fileURL: job.sourceURL) else {
            throw ConversionError.unsupportedInputFormat
        }
        guard FileTypeDetector.availableOutputFormats(for: kind).contains(job.targetFormat) else {
            throw ConversionError.unsupportedOutputFormat(job.targetFormat)
        }

        let originalByteCount = byteCount(at: job.sourceURL)

        let source: any ImageSource
        do {
            source = try ImageSourceFactory.make(fileURL: job.sourceURL, kind: kind)
        } catch let error as ConversionError {
            throw error
        } catch {
            throw ConversionError.sourceUnreadable
        }

        try Task.checkCancellation()

        let targetSize = job.resize.resolvedSize(originalSize: source.originalPixelSize)
        let renderedImage = try source.renderCGImage(at: targetSize)

        try Task.checkCancellation()

        let encodedData: Data
        do {
            encodedData = try ImageEncoder.encode(renderedImage, format: job.targetFormat, quality: job.quality)
        } catch let error as ConversionError {
            ConvertLog.conversion.error("Encoding failed for \(job.sourceURL.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            throw error
        } catch {
            ConvertLog.conversion.error("Encoding failed for \(job.sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw ConversionError.destinationWriteFailed(underlying: error.localizedDescription)
        }

        try Task.checkCancellation()

        let destinationURL = OutputPathResolver.resolve(sourceURL: job.sourceURL, targetFormat: job.targetFormat)
        try writeAtomically(encodedData, to: destinationURL)

        return ConversionResult(
            sourceURL: job.sourceURL,
            outputURL: destinationURL,
            originalPixelSize: source.originalPixelSize,
            outputPixelSize: CGSize(width: renderedImage.width, height: renderedImage.height),
            originalByteCount: originalByteCount,
            outputByteCount: Int64(encodedData.count)
        )
    }

    private static func byteCount(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else { return 0 }
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func writeAtomically(_ data: Data, to destinationURL: URL) throws {
        let tempURL = destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(".convert-\(UUID().uuidString)")
            .appendingPathExtension(destinationURL.pathExtension)

        do {
            try data.write(to: tempURL, options: .atomic)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
                throw ConversionError.insufficientDiskSpace
            }
            ConvertLog.conversion.error("Writing output failed: \(nsError.localizedDescription, privacy: .public)")
            throw ConversionError.destinationWriteFailed(underlying: nsError.localizedDescription)
        }
    }
}
