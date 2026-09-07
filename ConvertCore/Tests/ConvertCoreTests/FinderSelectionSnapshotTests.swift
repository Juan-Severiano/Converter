import Foundation
import Testing
@testable import ConvertCore

@Suite("Finder selection snapshots")
struct FinderSelectionSnapshotTests {
    @Test("creates a pending job from the captured selection without consulting Finder again")
    func createsJobFromSnapshot() {
        let urls = [
            URL(fileURLWithPath: "/Users/example/Desktop/first.png"),
            URL(fileURLWithPath: "/Users/example/Desktop/second.png"),
        ]
        let snapshot = FinderSelectionSnapshot(fileURLs: urls)

        let job = snapshot.pendingJob(targetFormat: .webp)

        #expect(job.targetFormat == .webp)
        #expect(job.files.map(\.sourceURL) == urls)
        #expect(job.files.count == 2)
    }
}
