import Combine
import ConvertCore
import CoreGraphics
import Foundation

struct ConversionSourceFile {
    let url: URL
    let fileName: String
    let pixelSize: CGSize?
    let byteSize: Int64
}

enum ConversionSessionState {
    case configuring
    case converting(completed: Int, total: Int)
    case finished(succeeded: [ConversionResult], failed: [(url: URL, error: ConversionError)])
    case cancelled
}

/// Per-window state backing one "Convert to X" configuration + progress view.
@MainActor
final class ConversionSession: ObservableObject, Identifiable {
    let id = UUID()
    let files: [ConversionSourceFile]

    @Published var targetFormat: OutputFormat
    /// True when this session came from Finder's standalone "Resize" item: the format is the
    /// selection's own, kept as-is, so the UI reads "Resize" rather than "Convert to X".
    let isResizeOnly: Bool
    @Published var resizeMode: ResizeSpec.Mode = .original
    @Published var customWidth: Int
    @Published var customHeight: Int
    @Published var maintainAspectRatio = true
    @Published var quality: Int
    @Published private(set) var state: ConversionSessionState = .configuring

    private var runningTask: Task<Void, Never>?

    init(
        files: [ConversionSourceFile],
        targetFormat: OutputFormat,
        defaultQuality: Int,
        isResizeOnly: Bool = false
    ) {
        self.files = files
        self.targetFormat = targetFormat
        self.isResizeOnly = isResizeOnly
        self.quality = max(1, min(100, defaultQuality))

        let originalSize = files.first?.pixelSize ?? CGSize(width: 512, height: 512)
        self.customWidth = max(1, Int(originalSize.width))
        self.customHeight = max(1, Int(originalSize.height))
    }

    var state_: ConversionSessionState { state }

    private var originalAspectRatio: CGFloat {
        guard let size = files.first?.pixelSize, size.height > 0 else { return 1 }
        return size.width / size.height
    }

    private var resolvedResize: ResizeSpec {
        switch resizeMode {
        case .original:
            .original
        case .preset, .custom:
            ResizeSpec(mode: resizeMode, width: customWidth, height: customHeight, maintainAspectRatio: maintainAspectRatio)
        }
    }

    func applyPreset(width: Int, height: Int) {
        resizeMode = .preset
        customWidth = width
        customHeight = height
    }

    func setCustomWidth(_ newWidth: Int) {
        resizeMode = .custom
        let spec = ResizeSpec.custom(width: customWidth, height: customHeight, maintainAspectRatio: maintainAspectRatio)
            .updatingWidth(newWidth, originalAspectRatio: originalAspectRatio)
        customWidth = spec.width
        customHeight = spec.height
    }

    func setCustomHeight(_ newHeight: Int) {
        resizeMode = .custom
        let spec = ResizeSpec.custom(width: customWidth, height: customHeight, maintainAspectRatio: maintainAspectRatio)
            .updatingHeight(newHeight, originalAspectRatio: originalAspectRatio)
        customWidth = spec.width
        customHeight = spec.height
    }

    func start() {
        guard case .configuring = state else { return }

        let request = ConversionRequest(
            sourceFileURLs: files.map(\.url),
            targetFormat: targetFormat,
            resize: resolvedResize,
            quality: targetFormat.supportsQuality ? quality : nil
        )
        state = .converting(completed: 0, total: files.count)

        runningTask = Task {
            var succeeded: [ConversionResult] = []
            var failed: [(url: URL, error: ConversionError)] = []
            var completed = 0

            for await event in BatchProcessor.run(request: request) {
                switch event {
                case .started:
                    break
                case .fileSucceeded(_, let total, let result):
                    completed += 1
                    succeeded.append(result)
                    state = .converting(completed: completed, total: total)
                case .fileFailed(_, let total, let url, let error):
                    completed += 1
                    failed.append((url, error))
                    state = .converting(completed: completed, total: total)
                case .finished:
                    break
                }
            }

            state = Task.isCancelled ? .cancelled : .finished(succeeded: succeeded, failed: failed)
        }
    }

    func cancel() {
        runningTask?.cancel()
    }

}
