import Foundation
import Testing
@testable import ConvertCore

@Suite("Finder job URL")
struct FinderJobURLTests {
    @Test("round-trips a selected file URL through Convert's private URL scheme")
    func roundTripsJob() throws {
        let job = PendingJob(
            files: [PendingFile(sourceURL: URL(fileURLWithPath: "/Users/example/Desktop/foto com espaço.png"))],
            targetFormat: .webp,
            quality: 85
        )

        let url = try FinderJobURL.make(job: job)

        #expect(try FinderJobURL.job(from: url) == job)
    }
}
