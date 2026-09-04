import Foundation

/// Holds sandboxed read/write access to a folder for as long as it's needed, released explicitly
/// with `release()` (typically in a `defer`, once every file in that folder has been converted).
public struct SecurityScopedFolderAccess {
    public let folderURL: URL
    private let stopAccessing: @Sendable () -> Void

    fileprivate init(folderURL: URL, stopAccessing: @escaping @Sendable () -> Void) {
        self.folderURL = folderURL
        self.stopAccessing = stopAccessing
    }

    public func fileURL(named fileName: String) -> URL {
        folderURL.appendingPathComponent(fileName)
    }

    public func release() {
        stopAccessing()
    }
}

/// Bridges a Finder-selected file across the sandbox boundary between the Finder Sync extension
/// and the main app: the extension mints a bookmark for the file's folder (while it still has
/// Finder-selection access), and the app later resolves it to gain write access itself.
public enum SecurityScopedBookmark {
    public static func makeFolderBookmark(for fileURL: URL) throws -> Data {
        let folderURL = fileURL.deletingLastPathComponent()
        do {
            return try folderURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw ConversionError.sourceUnreadable
        }
    }

    public static func resolveFolderAccess(_ bookmark: Data) throws -> SecurityScopedFolderAccess {
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw ConversionError.sourceUnreadable
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw ConversionError.sourceUnreadable
        }
        return SecurityScopedFolderAccess(folderURL: url) {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
