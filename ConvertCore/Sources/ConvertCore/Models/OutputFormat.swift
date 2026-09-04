import UniformTypeIdentifiers

/// A format Convert can produce as conversion output.
public enum OutputFormat: String, Codable, CaseIterable, Sendable, Identifiable {
    case jpeg
    case png
    case webp
    case heic
    case tiff
    case pdf

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .webp: "WebP"
        case .heic: "HEIC"
        case .tiff: "TIFF"
        case .pdf: "PDF"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .webp: "webp"
        case .heic: "heic"
        case .tiff: "tiff"
        case .pdf: "pdf"
        }
    }

    /// Whether this format has a lossy-compression quality knob worth exposing in the UI.
    public var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp, .heic: true
        case .png, .tiff, .pdf: false
        }
    }

    /// UTType used with ImageIO's CGImageDestination. `nil` for formats encoded through a different API.
    var imageIODestinationType: UTType? {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: UTType("public.heic")
        case .tiff: .tiff
        case .webp, .pdf: nil
        }
    }
}
