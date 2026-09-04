import Foundation

/// Progress events `BatchProcessor` emits while converting a `ConversionRequest`.
public enum BatchEvent: Sendable {
    case started(total: Int)
    case fileSucceeded(index: Int, total: Int, result: ConversionResult)
    case fileFailed(index: Int, total: Int, sourceURL: URL, error: ConversionError)
    case finished
}
