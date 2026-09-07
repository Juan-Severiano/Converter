import Foundation
import Testing
@testable import ConvertCore

@Suite("PendingJob Codable round-trip")
struct PendingJobCodableTests {
    @Test("encodes and decodes back to an equal value")
    func roundTrips() throws {
        let job = PendingJob(
            files: [PendingFile(sourceURL: URL(fileURLWithPath: "/Users/test/Desktop/foto.png"))],
            targetFormat: .webp,
            resize: .preset(width: 512, height: 512),
            quality: 85
        )

        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(PendingJob.self, from: data)

        #expect(decoded == job)
    }
}
