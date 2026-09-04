/// The image format Convert detected for a source file.
public enum FileKind: String, CaseIterable, Sendable {
    case png
    case jpeg
    case heic
    case tiff
    case gif
    case bmp
    case webp
    case svg

    /// The output format that mirrors this input kind, if any — excluded from that
    /// file's own list of available conversion targets (no PNG→PNG, etc).
    var matchingOutputFormat: OutputFormat? {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .tiff: .tiff
        case .webp: .webp
        case .gif, .bmp, .svg: nil
        }
    }
}
