import Foundation

/// One file within a `PendingJob`: a security-scoped bookmark to its *containing folder* (not the
/// file itself), plus the file's own name. A folder-level bookmark is what actually grants the main
/// app permission to write the converted file back into that same folder under App Sandbox — a
/// file-level bookmark alone would only grant access to that one existing file, not to creating a
/// new sibling next to it.
public struct PendingFile: Codable, Equatable, Sendable {
    public let folderBookmark: Data
    public let fileName: String

    public init(folderBookmark: Data, fileName: String) {
        self.folderBookmark = folderBookmark
        self.fileName = fileName
    }
}

/// What the Finder Sync extension hands off to the main app: the files the user picked in Finder,
/// via security-scoped bookmarks the sandboxed app can actually act on, plus the conversion options.
public struct PendingJob: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var files: [PendingFile]
    public var targetFormat: OutputFormat
    public var resize: ResizeSpec
    public var quality: Int?
    public var keepOriginal: Bool

    public init(
        id: UUID = UUID(),
        files: [PendingFile],
        targetFormat: OutputFormat,
        resize: ResizeSpec = .original,
        quality: Int? = nil,
        keepOriginal: Bool = true
    ) {
        self.id = id
        self.files = files
        self.targetFormat = targetFormat
        self.resize = resize
        self.quality = quality.map { max(1, min(100, $0)) }
        self.keepOriginal = keepOriginal
    }
}
