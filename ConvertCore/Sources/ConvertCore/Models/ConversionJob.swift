import Foundation

/// A single file's conversion instructions — the unit `ConversionEngine.convert(job:)` consumes.
public struct ConversionJob: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sourceURL: URL
    public var targetFormat: OutputFormat
    public var resize: ResizeSpec
    public var quality: Int?
    public var keepOriginal: Bool
    /// When true, `quality` is ignored and `ImageCompressor` picks the size/quality tradeoff.
    public var compress: Bool
    /// True for a standalone Resize job: the engine allows re-encoding to the source's own
    /// format for this case only. A "Convert to X" job targeting its own format stays rejected.
    public var isResizeOnly: Bool

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        targetFormat: OutputFormat,
        resize: ResizeSpec = .original,
        quality: Int? = nil,
        keepOriginal: Bool = true,
        compress: Bool = false,
        isResizeOnly: Bool = false
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.targetFormat = targetFormat
        self.resize = resize
        self.quality = quality.map { max(1, min(100, $0)) }
        self.keepOriginal = keepOriginal
        self.compress = compress
        self.isResizeOnly = isResizeOnly
    }
}
