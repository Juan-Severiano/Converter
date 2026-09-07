import Foundation

/// A batch conversion request covering one or more files with shared target format and options.
///
/// This is the payload handed off between the Finder Sync extension and the main app (encoded as
/// JSON in Convert's local handoff folder), and the shape drag-and-drop batches use internally.
public struct ConversionRequest: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sourceFileURLs: [URL]
    public var targetFormat: OutputFormat
    public var resize: ResizeSpec
    public var quality: Int?
    public var keepOriginal: Bool

    public init(
        id: UUID = UUID(),
        sourceFileURLs: [URL],
        targetFormat: OutputFormat,
        resize: ResizeSpec = .original,
        quality: Int? = nil,
        keepOriginal: Bool = true
    ) {
        self.id = id
        self.sourceFileURLs = sourceFileURLs
        self.targetFormat = targetFormat
        self.resize = resize
        self.quality = quality.map { max(1, min(100, $0)) }
        self.keepOriginal = keepOriginal
    }

    /// Expands the batch into one `ConversionJob` per source file.
    public func makeJobs() -> [ConversionJob] {
        sourceFileURLs.map { url in
            ConversionJob(
                sourceURL: url,
                targetFormat: targetFormat,
                resize: resize,
                quality: quality,
                keepOriginal: keepOriginal
            )
        }
    }
}
