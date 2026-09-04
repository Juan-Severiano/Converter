import Foundation
import Testing
@testable import ConvertCore

@Suite("FileTypeDetector")
struct FileTypeDetectorTests {
    @Test(
        "detects kind from extension",
        arguments: [
            ("photo.png", FileKind.png),
            ("photo.jpg", .jpeg),
            ("photo.jpeg", .jpeg),
            ("photo.heic", .heic),
            ("photo.tiff", .tiff),
            ("photo.gif", .gif),
            ("photo.bmp", .bmp),
            ("photo.webp", .webp),
            ("photo.svg", .svg),
        ]
    )
    func detectsKindFromExtension(name: String, expected: FileKind) {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        #expect(FileTypeDetector.detect(fileURL: url) == expected)
    }

    @Test("unsupported extensions are not detected")
    func unsupportedExtensionReturnsNil() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        #expect(FileTypeDetector.detect(fileURL: url) == nil)
    }

    @Test(
        "available output formats match the approved matrix",
        arguments: [
            (FileKind.png, [OutputFormat.jpeg, .webp, .heic, .tiff, .pdf]),
            (.jpeg, [.png, .webp, .heic, .tiff, .pdf]),
            (.heic, [.jpeg, .png, .webp, .tiff, .pdf]),
            (.tiff, [.jpeg, .png, .webp, .heic, .pdf]),
            (.gif, [.jpeg, .png, .webp, .heic, .tiff, .pdf]),
            (.bmp, [.jpeg, .png, .webp, .heic, .tiff, .pdf]),
            (.webp, [.jpeg, .png, .heic, .tiff, .pdf]),
            (.svg, [.jpeg, .png, .webp, .heic, .tiff, .pdf]),
        ]
    )
    func availableOutputFormatsMatchesMatrix(kind: FileKind, expected: [OutputFormat]) {
        #expect(FileTypeDetector.availableOutputFormats(for: kind) == expected)
    }

    @Test("no format ever offers converting a file to its own kind")
    func neverOffersSameFormatAsInput() {
        for kind in FileKind.allCases {
            let formats = FileTypeDetector.availableOutputFormats(for: kind)
            if let own = kind.matchingOutputFormat {
                #expect(!formats.contains(own))
            }
        }
    }

    @Test("mixed selection intersects available formats and excludes each input's own format")
    func intersectionOfMixedSelectionExcludesEachInputsOwnFormat() {
        let png = URL(fileURLWithPath: "/tmp/a.png")
        let jpeg = URL(fileURLWithPath: "/tmp/b.jpg")
        let formats = FileTypeDetector.availableOutputFormats(forFiles: [png, jpeg])
        #expect(formats == [.webp, .heic, .tiff, .pdf])
    }

    @Test("a single unsupported file collapses the batch intersection to empty")
    func unsupportedFileInBatchYieldsNoFormats() {
        let png = URL(fileURLWithPath: "/tmp/a.png")
        let text = URL(fileURLWithPath: "/tmp/notes.txt")
        #expect(FileTypeDetector.availableOutputFormats(forFiles: [png, text]).isEmpty)
    }
}
