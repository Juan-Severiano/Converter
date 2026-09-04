//
//  ConversionConfigView.swift
//  Converter
//
//  The compact window shown after picking a target format, either from Finder's Convert submenu
//  or after choosing a format for dropped files.
//

import AppKit
import ConvertCore
import SwiftUI

struct ConversionConfigView: View {
    @ObservedObject var session: ConversionSession
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Convert to \(session.targetFormat.displayName)")
                .font(.title3.weight(.semibold))

            fileSummary

            if case .configuring = session.state_ {
                sizeSection
                if session.targetFormat.supportsQuality {
                    qualitySection
                }
            }

            Divider()

            footer
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 320)
        .task {
            thumbnail = await loadThumbnail()
        }
    }

    private var fileSummary: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                if session.files.count == 1, let file = session.files.first {
                    Text(file.fileName)
                        .lineLimit(1)
                    Text(subtitle(for: file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(session.files.count) files")
                    Text(session.files.map(\.fileName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func subtitle(for file: ConversionSourceFile) -> String {
        var parts: [String] = []
        if let size = file.pixelSize {
            parts.append("\(Int(size.width)) × \(Int(size.height))")
        }
        parts.append(ByteCountFormatter.string(fromByteCount: file.byteSize, countStyle: .file))
        return parts.joined(separator: " • ")
    }

    // MARK: - Size

    private enum SizeChoice: Hashable {
        case original, s128, s256, s512, s1024, custom
    }

    private var sizeChoiceBinding: Binding<SizeChoice> {
        Binding(
            get: {
                switch session.resizeMode {
                case .original: return .original
                case .custom: return .custom
                case .preset:
                    switch (session.customWidth, session.customHeight) {
                    case (128, 128): return .s128
                    case (256, 256): return .s256
                    case (512, 512): return .s512
                    case (1024, 1024): return .s1024
                    default: return .custom
                    }
                }
            },
            set: { choice in
                switch choice {
                case .original: session.resizeMode = .original
                case .s128: session.applyPreset(width: 128, height: 128)
                case .s256: session.applyPreset(width: 256, height: 256)
                case .s512: session.applyPreset(width: 512, height: 512)
                case .s1024: session.applyPreset(width: 1024, height: 1024)
                case .custom: session.resizeMode = .custom
                }
            }
        )
    }

    private var widthBinding: Binding<Int> {
        Binding(get: { session.customWidth }, set: { session.setCustomWidth($0) })
    }

    private var heightBinding: Binding<Int> {
        Binding(get: { session.customHeight }, set: { session.setCustomHeight($0) })
    }

    private static let dimensionFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Size preset", selection: sizeChoiceBinding) {
                Text("Original").tag(SizeChoice.original)
                Text("128 × 128").tag(SizeChoice.s128)
                Text("256 × 256").tag(SizeChoice.s256)
                Text("512 × 512").tag(SizeChoice.s512)
                Text("1024 × 1024").tag(SizeChoice.s1024)
                Text("Custom").tag(SizeChoice.custom)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 180)

            HStack(spacing: 8) {
                TextField("Width", value: widthBinding, formatter: Self.dimensionFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Width")
                Text("×")
                    .foregroundStyle(.secondary)
                TextField("Height", value: heightBinding, formatter: Self.dimensionFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Height")
            }

            Toggle("Maintain aspect ratio", isOn: $session.maintainAspectRatio)
        }
    }

    // MARK: - Quality

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quality")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(session.quality)%")
                    .font(.subheadline.monospacedDigit())
            }
            Slider(
                value: Binding(get: { Double(session.quality) }, set: { session.quality = Int($0) }),
                in: 1...100,
                step: 1
            )
            .accessibilityValue("\(session.quality) percent")
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch session.state_ {
        case .configuring:
            HStack {
                Spacer()
                Button("Cancel") { closeWindow() }
                    .keyboardShortcut(.cancelAction)
                Button("Convert") { session.start() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }

        case .converting(let completed, let total):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(completed), total: Double(max(total, 1))) {
                    Text("Converting…")
                }
                Text("\(completed) of \(total) file\(total == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel") { session.cancel() }
                }
            }

        case .finished(let succeeded, let failed):
            VStack(alignment: .leading, spacing: 8) {
                if failed.isEmpty {
                    Label("Done — \(succeeded.count) file\(succeeded.count == 1 ? "" : "s") converted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(failureTitle(succeeded: succeeded.count, failed: failed), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    if failed.count == 1, let recovery = failed[0].error.recoveryAction {
                        Text("\(failed[0].error.message) \(recovery).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Spacer()
                    Button("Done") { closeWindow() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                }
            }

        case .cancelled:
            HStack {
                Text("Cancelled")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { closeWindow() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func failureTitle(succeeded: Int, failed: [(url: URL, error: ConversionError)]) -> String {
        if succeeded == 0 {
            return failed.count == 1 ? failed[0].error.title : "Couldn't convert \(failed.count) files"
        }
        return "\(succeeded) converted, \(failed.count) failed"
    }

    private func closeWindow() {
        appModel.removeSession(session.id)
        dismiss()
    }

    private func loadThumbnail() async -> NSImage? {
        guard let first = session.files.first else { return nil }
        return await Task.detached(priority: .userInitiated) {
            ThumbnailLoader.loadThumbnail(for: first.url)
        }.value
    }
}
