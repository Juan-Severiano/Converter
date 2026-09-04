/// Everything that can go wrong during a conversion, paired with a plain-language explanation.
///
/// The associated technical detail on `destinationWriteFailed` (e.g. a raw `CGImageDestinationFinalize`
/// failure) is for the local debug log only — `message` never surfaces it.
public enum ConversionError: Error, Equatable, Sendable {
    case unsupportedInputFormat
    case unsupportedOutputFormat(OutputFormat)
    case sourceUnreadable
    case insufficientDiskSpace
    case destinationWriteFailed(underlying: String)
    case cancelled

    public var title: String {
        switch self {
        case .unsupportedInputFormat: "Couldn't read this file"
        case .unsupportedOutputFormat: "Couldn't convert this file"
        case .sourceUnreadable: "Couldn't open this file"
        case .insufficientDiskSpace: "Not enough disk space"
        case .destinationWriteFailed: "Couldn't save the converted file"
        case .cancelled: "Conversion cancelled"
        }
    }

    public var message: String {
        switch self {
        case .unsupportedInputFormat:
            "This file's format isn't recognized by Convert."
        case .unsupportedOutputFormat(let format):
            "The \(format.displayName) format isn't supported for this image."
        case .sourceUnreadable:
            "The original file appears to be damaged or is no longer available."
        case .insufficientDiskSpace:
            "There isn't enough free space on this disk to save the converted file."
        case .destinationWriteFailed:
            "Something went wrong while saving the converted file."
        case .cancelled:
            "The conversion was cancelled before it finished."
        }
    }

    public var recoveryAction: String? {
        switch self {
        case .unsupportedOutputFormat: "Try another format"
        case .sourceUnreadable, .destinationWriteFailed: "Try again"
        case .unsupportedInputFormat, .insufficientDiskSpace, .cancelled: nil
        }
    }
}
