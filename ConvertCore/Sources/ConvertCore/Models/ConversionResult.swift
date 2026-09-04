import CoreGraphics
import Foundation

/// What a single successful `ConversionEngine.convert(job:)` produced.
public struct ConversionResult: Equatable, Sendable {
    public let sourceURL: URL
    public let outputURL: URL
    public let originalPixelSize: CGSize?
    public let outputPixelSize: CGSize?
    public let originalByteCount: Int64
    public let outputByteCount: Int64

    public init(
        sourceURL: URL,
        outputURL: URL,
        originalPixelSize: CGSize?,
        outputPixelSize: CGSize?,
        originalByteCount: Int64,
        outputByteCount: Int64
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.originalPixelSize = originalPixelSize
        self.outputPixelSize = outputPixelSize
        self.originalByteCount = originalByteCount
        self.outputByteCount = outputByteCount
    }
}
