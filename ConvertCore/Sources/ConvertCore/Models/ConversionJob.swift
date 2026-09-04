import Foundation

/// A single file's conversion instructions — the unit `ConversionEngine.convert(job:)` consumes.
public struct ConversionJob: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sourceURL: URL
    public var targetFormat: OutputFormat
    public var resize: ResizeSpec
    public var quality: Int?
    public var keepOriginal: Bool

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        targetFormat: OutputFormat,
        resize: ResizeSpec = .original,
        quality: Int? = nil,
        keepOriginal: Bool = true
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.targetFormat = targetFormat
        self.resize = resize
        self.quality = quality.map { max(1, min(100, $0)) }
        self.keepOriginal = keepOriginal
    }
}
