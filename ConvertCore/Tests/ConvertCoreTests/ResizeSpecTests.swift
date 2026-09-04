import CoreGraphics
import Testing
@testable import ConvertCore

@Suite("ResizeSpec")
struct ResizeSpecTests {
    @Test(".original resolves to the source's own size")
    func originalResolvesToSourceSize() {
        let spec = ResizeSpec.original
        #expect(spec.resolvedSize(originalSize: CGSize(width: 1024, height: 768)) == CGSize(width: 1024, height: 768))
    }

    @Test("a preset resolves to its own fixed size regardless of source size")
    func presetResolvesToItsOwnSize() {
        let spec = ResizeSpec.preset(width: 256, height: 256)
        #expect(spec.resolvedSize(originalSize: CGSize(width: 1024, height: 768)) == CGSize(width: 256, height: 256))
    }

    @Test("updating width recalculates height when aspect ratio is locked")
    func updatingWidthRecalculatesHeightWhenLocked() {
        let spec = ResizeSpec.custom(width: 1024, height: 1024, maintainAspectRatio: true)
        let aspectRatio: CGFloat = 1920.0 / 1080.0 // a 16:9 original

        let updated = spec.updatingWidth(1920, originalAspectRatio: aspectRatio)

        #expect(updated.width == 1920)
        #expect(updated.height == 1080)
    }

    @Test("updating height recalculates width when aspect ratio is locked")
    func updatingHeightRecalculatesWidthWhenLocked() {
        let spec = ResizeSpec.custom(width: 1024, height: 1024, maintainAspectRatio: true)
        let aspectRatio: CGFloat = 1920.0 / 1080.0

        let updated = spec.updatingHeight(1080, originalAspectRatio: aspectRatio)

        #expect(updated.width == 1920)
        #expect(updated.height == 1080)
    }

    @Test("width and height are independent once aspect ratio is unlocked")
    func widthAndHeightAreIndependentWhenUnlocked() {
        let spec = ResizeSpec.custom(width: 1024, height: 1024, maintainAspectRatio: false)
        let aspectRatio: CGFloat = 1920.0 / 1080.0

        let updated = spec.updatingWidth(500, originalAspectRatio: aspectRatio)

        #expect(updated.width == 500)
        #expect(updated.height == 1024)
    }

    @Test("width and height never collapse to zero or below")
    func neverProducesNonPositiveDimensions() {
        let spec = ResizeSpec.custom(width: 100, height: 100, maintainAspectRatio: false)

        let updated = spec.updatingWidth(0, originalAspectRatio: 1)

        #expect(updated.width >= 1)
    }
}
