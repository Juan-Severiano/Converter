import CoreGraphics

/// How Convert should size the output image, independent of which format it's encoded to.
public struct ResizeSpec: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, Equatable, Sendable, CaseIterable {
        case original
        case preset
        case custom
    }

    public var mode: Mode
    public var width: Int
    public var height: Int
    public var maintainAspectRatio: Bool

    public init(mode: Mode, width: Int, height: Int, maintainAspectRatio: Bool = true) {
        self.mode = mode
        self.width = max(0, width)
        self.height = max(0, height)
        self.maintainAspectRatio = maintainAspectRatio
    }

    /// Keep the source's own pixel dimensions.
    public static let original = ResizeSpec(mode: .original, width: 0, height: 0)

    public static func preset(width: Int, height: Int) -> ResizeSpec {
        ResizeSpec(mode: .preset, width: width, height: height)
    }

    public static func custom(width: Int, height: Int, maintainAspectRatio: Bool = true) -> ResizeSpec {
        ResizeSpec(mode: .custom, width: width, height: height, maintainAspectRatio: maintainAspectRatio)
    }

    /// The pixel size to render at, given the source image's natural size.
    public func resolvedSize(originalSize: CGSize) -> CGSize {
        switch mode {
        case .original:
            return originalSize
        case .preset, .custom:
            return CGSize(width: max(1, width), height: max(1, height))
        }
    }

    /// Applies a new width, recomputing height to match `originalAspectRatio` when locked.
    public func updatingWidth(_ newWidth: Int, originalAspectRatio: CGFloat) -> ResizeSpec {
        var copy = self
        copy.width = max(1, newWidth)
        if maintainAspectRatio, originalAspectRatio > 0 {
            copy.height = max(1, Int((CGFloat(copy.width) / originalAspectRatio).rounded()))
        }
        return copy
    }

    /// Applies a new height, recomputing width to match `originalAspectRatio` when locked.
    public func updatingHeight(_ newHeight: Int, originalAspectRatio: CGFloat) -> ResizeSpec {
        var copy = self
        copy.height = max(1, newHeight)
        if maintainAspectRatio, originalAspectRatio > 0 {
            copy.width = max(1, Int((CGFloat(copy.height) * originalAspectRatio).rounded()))
        }
        return copy
    }
}
