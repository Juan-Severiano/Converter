import Foundation
import Testing
@testable import ConvertCore

@Suite("OutputPathResolver")
struct OutputPathResolverTests {
    @Test("resolves to the same folder with no collision")
    func noCollision() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent("foto.png")
        let resolved = OutputPathResolver.resolve(sourceURL: source, targetFormat: .webp)

        #expect(resolved == dir.appendingPathComponent("foto.webp"))
    }

    @Test("appends (1) when the direct target name already exists")
    func firstCollision() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data().write(to: dir.appendingPathComponent("foto.webp"))

        let source = dir.appendingPathComponent("foto.png")
        let resolved = OutputPathResolver.resolve(sourceURL: source, targetFormat: .webp)

        #expect(resolved == dir.appendingPathComponent("foto (1).webp"))
    }

    @Test("keeps incrementing through consecutive collisions")
    func consecutiveCollisions() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data().write(to: dir.appendingPathComponent("foto.webp"))
        try Data().write(to: dir.appendingPathComponent("foto (1).webp"))
        try Data().write(to: dir.appendingPathComponent("foto (2).webp"))

        let source = dir.appendingPathComponent("foto.png")
        let resolved = OutputPathResolver.resolve(sourceURL: source, targetFormat: .webp)

        #expect(resolved == dir.appendingPathComponent("foto (3).webp"))
    }

    @Test("never reuses an existing file's exact path")
    func resolvedPathIsAlwaysFree() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        for name in ["foto.webp", "foto (1).webp"] {
            try Data().write(to: dir.appendingPathComponent(name))
        }

        let source = dir.appendingPathComponent("foto.jpg")
        let resolved = OutputPathResolver.resolve(sourceURL: source, targetFormat: .webp)

        #expect(!FileManager.default.fileExists(atPath: resolved.path))
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
