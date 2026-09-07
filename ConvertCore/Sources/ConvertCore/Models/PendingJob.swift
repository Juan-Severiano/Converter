import Foundation

/// One file within a `PendingJob`.
///
/// Convert's development build deliberately runs outside App Sandbox, so the Finder extension can
/// pass the selected file URL straight to the main app and the main app can create a sibling file.
public struct PendingFile: Codable, Equatable, Sendable {
    public let sourceURL: URL

    public init(sourceURL: URL) {
        self.sourceURL = sourceURL
    }
}

/// What the Finder Sync extension hands off to the main app: the files the user picked in Finder,
/// plus the conversion options.
public struct PendingJob: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var files: [PendingFile]
    public var targetFormat: OutputFormat
    public var resize: ResizeSpec
    public var quality: Int?
    public var keepOriginal: Bool
    /// True when this job came from Finder's standalone "Resize" item rather than a "Convert to
    /// X" pick — `targetFormat` is then just the selection's own format, kept as-is.
    public var isResizeOnly: Bool

    public init(
        id: UUID = UUID(),
        files: [PendingFile],
        targetFormat: OutputFormat,
        resize: ResizeSpec = .original,
        quality: Int? = nil,
        keepOriginal: Bool = true,
        isResizeOnly: Bool = false
    ) {
        self.id = id
        self.files = files
        self.targetFormat = targetFormat
        self.resize = resize
        self.quality = quality.map { max(1, min(100, $0)) }
        self.keepOriginal = keepOriginal
        self.isResizeOnly = isResizeOnly
    }
}
