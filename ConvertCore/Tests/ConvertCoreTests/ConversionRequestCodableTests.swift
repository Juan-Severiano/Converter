import Foundation
import Testing
@testable import ConvertCore

/// `ConversionRequest` is the exact JSON contract the Finder Sync extension writes into the shared
/// App Group container and the main app reads back — a schema break here fails silently in
/// production (the app just never opens the job), so it gets its own round-trip test.
@Suite("ConversionRequest Codable round-trip")
struct ConversionRequestCodableTests {
    @Test("encodes and decodes back to an equal value")
    func roundTrips() throws {
        let request = ConversionRequest(
            sourceFileURLs: [
                URL(fileURLWithPath: "/Users/test/Desktop/foto.png"),
                URL(fileURLWithPath: "/Users/test/Desktop/outra foto.png"),
            ],
            targetFormat: .webp,
            resize: .preset(width: 512, height: 512),
            quality: 90,
            keepOriginal: true
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(ConversionRequest.self, from: data)

        #expect(decoded == request)
    }

    @Test("quality is clamped to 1...100 on construction")
    func qualityIsClamped() {
        let tooHigh = ConversionRequest(sourceFileURLs: [], targetFormat: .jpeg, quality: 500)
        let tooLow = ConversionRequest(sourceFileURLs: [], targetFormat: .jpeg, quality: -10)

        #expect(tooHigh.quality == 100)
        #expect(tooLow.quality == 1)
    }

    @Test("expands into one job per source file, preserving shared options")
    func makeJobsExpandsPerFile() {
        let request = ConversionRequest(
            sourceFileURLs: [
                URL(fileURLWithPath: "/tmp/a.png"),
                URL(fileURLWithPath: "/tmp/b.png"),
            ],
            targetFormat: .heic,
            quality: 70
        )

        let jobs = request.makeJobs()

        #expect(jobs.count == 2)
        #expect(jobs.allSatisfy { $0.targetFormat == .heic && $0.quality == 70 })
        #expect(Set(jobs.map(\.sourceURL)) == Set(request.sourceFileURLs))
    }
}
