import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import ConvertCore

/// Exercises the single high-level seam, `ConversionEngine.convert(job:)`, end-to-end against real
/// files in a temp directory. Nothing here is mocked — ImageIO, PDFKit and libwebp all run for real.
@Suite("ConversionEngine")
struct ConversionEngineTests {
    @Test("PNG converts to WebP, keeping the original untouched")
    func pngConvertsToWebPAndKeepsOriginal() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try writePNGFixture(in: dir, name: "foto.png", width: 8, height: 8)
        let originalData = try Data(contentsOf: source)

        let job = ConversionJob(sourceURL: source, targetFormat: .webp)
        let result = try await ConversionEngine.convert(job: job)

        #expect(result.outputURL == dir.appendingPathComponent("foto.webp"))
        #expect(FileManager.default.fileExists(atPath: result.outputURL.path))
        #expect(result.outputByteCount > 0)
        #expect(result.outputPixelSize == CGSize(width: 8, height: 8))

        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(try Data(contentsOf: source) == originalData)
    }

    @Test("a resize preset changes the output's pixel dimensions")
    func resizePresetChangesOutputDimensions() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try writePNGFixture(in: dir, name: "foto.png", width: 64, height: 64)
        let job = ConversionJob(sourceURL: source, targetFormat: .jpeg, resize: .preset(width: 16, height: 16), quality: 90)

        let result = try await ConversionEngine.convert(job: job)

        #expect(result.outputPixelSize == CGSize(width: 16, height: 16))
    }

    @Test("a second conversion to the same target name is saved alongside as (1), not overwritten")
    func secondConversionDoesNotOverwriteFirst() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try writePNGFixture(in: dir, name: "foto.png", width: 4, height: 4)
        let job = ConversionJob(sourceURL: source, targetFormat: .jpeg, quality: 90)

        let first = try await ConversionEngine.convert(job: job)
        let second = try await ConversionEngine.convert(job: job)

        #expect(first.outputURL != second.outputURL)
        #expect(second.outputURL == dir.appendingPathComponent("foto (1).jpg"))
        #expect(FileManager.default.fileExists(atPath: first.outputURL.path))
        #expect(FileManager.default.fileExists(atPath: second.outputURL.path))
    }

    @Test("converting a file to its own format is rejected")
    func rejectsConvertingToOwnFormat() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = try writePNGFixture(in: dir, name: "foto.png", width: 4, height: 4)
        let job = ConversionJob(sourceURL: source, targetFormat: .png)

        do {
            _ = try await ConversionEngine.convert(job: job)
            Issue.record("Expected .unsupportedOutputFormat(.png) to be thrown")
        } catch let error as ConversionError {
            #expect(error == .unsupportedOutputFormat(.png))
        }
    }

    @Test("a missing source file fails with a friendly, non-crashing error")
    func missingSourceFails() async {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).png")
        let job = ConversionJob(sourceURL: missing, targetFormat: .jpeg)

        do {
            _ = try await ConversionEngine.convert(job: job)
            Issue.record("Expected a ConversionError to be thrown for a missing source file")
        } catch is ConversionError {
            // expected
        } catch {
            Issue.record("Expected a ConversionError, got \(error)")
        }
    }

    @Test("BatchProcessor converts every file in a request and reports completion")
    func batchProcessorConvertsEveryFile() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sources = try (0 ..< 3).map { try writePNGFixture(in: dir, name: "foto\($0).png", width: 4, height: 4) }
        let request = ConversionRequest(sourceFileURLs: sources, targetFormat: .jpeg, quality: 80)

        var succeeded = 0
        var sawFinished = false
        for await event in BatchProcessor.run(request: request) {
            switch event {
            case .fileSucceeded: succeeded += 1
            case .finished: sawFinished = true
            default: break
            }
        }

        #expect(succeeded == 3)
        #expect(sawFinished)
    }

    // MARK: - Fixtures

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes a small real PNG with a translucent gradient, so tests exercise genuine ImageIO
    /// decode/encode and the WebP encoder's alpha unpremultiplication — not a hand-crafted byte fixture.
    private func writePNGFixture(in directory: URL, name: String, width: Int, height: Int) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestFixtureError.contextCreationFailed
        }

        for y in 0 ..< height {
            for x in 0 ..< width {
                let alpha = CGFloat(x + 1) / CGFloat(width)
                context.setFillColor(red: CGFloat(x) / CGFloat(width), green: CGFloat(y) / CGFloat(height), blue: 0.4, alpha: alpha)
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }

        guard let cgImage = context.makeImage() else {
            throw TestFixtureError.imageCreationFailed
        }

        let url = directory.appendingPathComponent(name)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw TestFixtureError.destinationCreationFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestFixtureError.finalizeFailed
        }
        return url
    }

    private enum TestFixtureError: Error {
        case contextCreationFailed
        case imageCreationFailed
        case destinationCreationFailed
        case finalizeFailed
    }
}
