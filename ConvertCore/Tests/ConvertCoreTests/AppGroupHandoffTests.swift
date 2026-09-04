import Foundation
import Testing
@testable import ConvertCore

/// Covers the folder-level security-scoped bookmark round trip on its own: outside an App Group
/// container it can't exercise the real sandboxed extension→app path, but a plain temp folder still
/// verifies bookmark creation/resolution and that the resolved URL points at the right place.
@Suite("Security-scoped folder bookmarks")
struct SecurityScopedBookmarkTests {
    @Test("resolves back to the same folder and can address a file within it")
    func resolvesBackToSameFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("foto.png")
        try Data([0x89]).write(to: file)

        let bookmark = try SecurityScopedBookmark.makeFolderBookmark(for: file)
        let access = try SecurityScopedBookmark.resolveFolderAccess(bookmark)
        defer { access.release() }

        #expect(access.folderURL.standardizedFileURL == dir.standardizedFileURL)
        #expect(access.fileURL(named: "foto.png").standardizedFileURL == file.standardizedFileURL)
    }
}

@Suite("PendingJob Codable round-trip")
struct PendingJobCodableTests {
    @Test("encodes and decodes back to an equal value")
    func roundTrips() throws {
        let job = PendingJob(
            files: [PendingFile(folderBookmark: Data([1, 2, 3]), fileName: "foto.png")],
            targetFormat: .webp,
            resize: .preset(width: 512, height: 512),
            quality: 85
        )

        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(PendingJob.self, from: data)

        #expect(decoded == job)
    }
}
