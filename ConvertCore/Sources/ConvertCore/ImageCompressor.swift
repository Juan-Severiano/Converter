import CoreGraphics
import Foundation

/// Automatic "just make it smaller" compression, the way compressjpeg.com or TinyPNG work: no
/// quality number to pick, just a smallest-file-that-still-looks-right result.
///
/// The approach is a knee-of-the-curve search: start near the top of the quality range and keep
/// stepping down as long as each step still buys a meaningful size reduction, stopping the moment
/// returns diminish. That avoids both leaving easy savings on the table (a flat quality: 85) and
/// over-compressing into visible artifacts (quality: 40) for images that didn't need it.
enum ImageCompressor {
    /// Quality ceiling first, then decreasing steps to search for the diminishing-returns point.
    private static let candidateQualities = [90, 80, 70, 60, 50, 40]

    /// The minimum fractional size reduction a quality step must deliver to be worth taking.
    private static let minimumStepReduction = 0.08

    static func compress(_ image: CGImage, format: OutputFormat) throws -> Data {
        var bestData = try ImageEncoder.encode(image, format: format, quality: candidateQualities[0])

        for quality in candidateQualities.dropFirst() {
            let candidateData = try ImageEncoder.encode(image, format: format, quality: quality)
            guard bestData.count > 0 else { break }
            let reduction = 1 - Double(candidateData.count) / Double(bestData.count)
            guard reduction >= minimumStepReduction else { break }
            bestData = candidateData
        }

        return bestData
    }
}
