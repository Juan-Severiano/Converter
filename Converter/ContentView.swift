//
//  ContentView.swift
//  Converter
//
//  Created by Francisco Juan on 03/09/26.
//

import ConvertCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openWindow) private var openWindow

    @State private var droppedURLs: [URL] = []
    @State private var isTargeted = false

    private var availableFormats: [OutputFormat] {
        FileTypeDetector.availableOutputFormats(forFiles: droppedURLs)
    }

    var body: some View {
        Group {
            if droppedURLs.isEmpty {
                dropArea
            } else {
                filePickerArea
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 320)
        .onChange(of: appModel.pendingWindowRequest) { _, newValue in
            guard let id = newValue else { return }
            openWindow(id: "conversion", value: id)
            appModel.pendingWindowRequest = nil
        }
        .alert("Couldn't open file", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.incomingJobErrorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appModel.incomingJobErrorMessage != nil },
            set: { isPresented in if !isPresented { appModel.incomingJobErrorMessage = nil } }
        )
    }

    private var dropArea: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("Drop files here")
                .font(.title3.weight(.medium))
            Text("PNG, JPEG, HEIC, TIFF, GIF, BMP, WebP, or SVG")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.3))
        )
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Drop files here to convert")
    }

    private var filePickerArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(droppedURLs.count) file\(droppedURLs.count == 1 ? "" : "s") ready")
                .font(.headline)

            List(droppedURLs, id: \.self) { url in
                Label(url.lastPathComponent, systemImage: "doc")
            }
            .listStyle(.inset)
            .frame(minHeight: 120)

            if availableFormats.isEmpty {
                Text("These files don't share a format Convert can produce.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Convert to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(availableFormats) { format in
                        Button(format.displayName) {
                            beginConversion(to: format)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Start Over") {
                    droppedURLs = []
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock()
                    collected.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            droppedURLs = collected
        }
    }

    private func beginConversion(to format: OutputFormat) {
        let session = appModel.makeSession(forDroppedFiles: droppedURLs, targetFormat: format)
        droppedURLs = []
        openWindow(id: "conversion", value: session.id)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
