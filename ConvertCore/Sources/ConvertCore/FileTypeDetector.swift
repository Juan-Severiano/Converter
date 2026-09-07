import Foundation
import UniformTypeIdentifiers

/// Detects a file's image kind and reports which output formats Convert can produce for it.
///
/// This is the single source of truth both the Finder Sync extension (building its "Convert"
/// submenu) and the app (its drag-and-drop format picker) consult, so the two entry points can
/// never disagree about what's offered for a given file.
public enum FileTypeDetector {
    public static func detect(fileURL: URL) -> FileKind? {
        kind(for: resolvedType(for: fileURL))
    }

    /// The output formats available for a single file, in a stable display order.
    public static func availableOutputFormats(for fileURL: URL) -> [OutputFormat] {
        guard let kind = detect(fileURL: fileURL) else { return [] }
        return availableOutputFormats(for: kind)
    }

    /// The output formats available for a given detected kind, in a stable display order.
    public static func availableOutputFormats(for kind: FileKind) -> [OutputFormat] {
        OutputFormat.allCases.filter { $0 != kind.matchingOutputFormat }
    }

    /// The formats compatible with every file in a multi-selection (intersection), for batch conversion.
    /// Files Convert doesn't recognize contribute no formats, collapsing the intersection to empty.
    public static func availableOutputFormats(forFiles fileURLs: [URL]) -> [OutputFormat] {
        guard let first = fileURLs.first else { return [] }
        var common = Set(availableOutputFormats(for: first))
        for url in fileURLs.dropFirst() where !common.isEmpty {
            common.formIntersection(availableOutputFormats(for: url))
        }
        return OutputFormat.allCases.filter { common.contains($0) }
    }

    /// The format a resize-only pass would re-encode to: the selection's own shared format, so
    /// resizing never silently changes what the files are. `nil` when the selection is empty,
    /// mixes formats, or is a format Convert can't re-encode to (GIF, BMP, SVG).
    public static func resizeOnlyFormat(forFiles fileURLs: [URL]) -> OutputFormat? {
        guard let first = fileURLs.first, let firstKind = detect(fileURL: first) else { return nil }
        for url in fileURLs.dropFirst() {
            guard detect(fileURL: url) == firstKind else { return nil }
        }
        return firstKind.matchingOutputFormat
    }

    private static func resolvedType(for fileURL: URL) -> UTType? {
        if let values = try? fileURL.resourceValues(forKeys: [.contentTypeKey]), let type = values.contentType {
            return type
        }
        return UTType(filenameExtension: fileURL.pathExtension.lowercased())
    }

    private static func kind(for type: UTType?) -> FileKind? {
        guard let type else { return nil }
        if type.conforms(to: .png) { return .png }
        if type.conforms(to: .jpeg) { return .jpeg }
        if let heic = UTType("public.heic"), type.conforms(to: heic) { return .heic }
        if let heif = UTType("public.heif"), type.conforms(to: heif) { return .heic }
        if type.conforms(to: .tiff) { return .tiff }
        if type.conforms(to: .gif) { return .gif }
        if type.conforms(to: .bmp) { return .bmp }
        if let webp = UTType("org.webmproject.webp"), type.conforms(to: webp) { return .webp }
        if let svg = UTType("public.svg-image"), type.conforms(to: svg) { return .svg }
        return nil
    }
}
