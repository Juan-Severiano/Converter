import Foundation

/// Picks where a converted file should be written: always next to the original, never overwriting it.
public enum OutputPathResolver {
    /// Resolves `photo.png` → `photo.webp`, or `photo (1).webp`, `photo (2).webp`, ... if that name
    /// is already taken — matching Finder's own "Copy" naming, so a collision never destroys or
    /// silently replaces an existing file.
    public static func resolve(sourceURL: URL, targetFormat: OutputFormat, fileManager: FileManager = .default) -> URL {
        let directory = sourceURL.deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        var candidate = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(targetFormat.fileExtension)

        var suffix = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName) (\(suffix))")
                .appendingPathExtension(targetFormat.fileExtension)
            suffix += 1
        }
        return candidate
    }
}
