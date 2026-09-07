import Foundation

/// Captures Finder's selected URLs while its contextual menu is being built.
/// Finder does not guarantee that `selectedItemURLs()` remains populated when a submenu action
/// fires, so the extension must hand the original snapshot to the app instead of asking again.
public struct FinderSelectionSnapshot: Sendable, Equatable {
    public let fileURLs: [URL]

    public init(fileURLs: [URL]) {
        self.fileURLs = fileURLs
    }

    public func pendingJob(
        targetFormat: OutputFormat,
        quality: Int? = nil
    ) -> PendingJob {
        let files = fileURLs.map(PendingFile.init(sourceURL:))
        return PendingJob(files: files, targetFormat: targetFormat, quality: quality)
    }
}
