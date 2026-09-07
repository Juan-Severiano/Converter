//
//  AppModel.swift
//  Converter
//
//  Owns every open conversion session and handles the `convert://open-job` handoff from the
//  Finder Sync extension.
//

import Combine
import ConvertCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private var sessions: [UUID: ConversionSession] = [:]
    @Published var pendingWindowRequest: UUID?
    @Published var incomingJobErrorMessage: String?

    private let sharedDefaults = UserDefaults.standard

    var defaultQuality: Int {
        let stored = sharedDefaults.integer(forKey: "defaultQuality")
        return stored == 0 ? 85 : stored
    }

    /// Handles a `convert://open-job` URL opened by the Finder Sync extension.
    func handleIncomingURL(_ url: URL) {
        do {
            NSLog("[DEBUG-finderhandoff] app received URL")
            let pendingJob = try FinderJobURL.job(from: url)
            NSLog("[DEBUG-finderhandoff] app decoded files=\(pendingJob.files.count) format=\(pendingJob.targetFormat.rawValue)")

            var files: [ConversionSourceFile] = []
            for pendingFile in pendingJob.files {
                let fileURL = pendingFile.sourceURL
                files.append(
                    ConversionSourceFile(
                        url: fileURL,
                        fileName: fileURL.lastPathComponent,
                        pixelSize: FileMetadata.pixelSize(of: fileURL),
                        byteSize: FileMetadata.byteSize(of: fileURL)
                    )
                )
            }

            let session = ConversionSession(
                files: files,
                targetFormat: pendingJob.targetFormat,
                defaultQuality: pendingJob.quality ?? defaultQuality
            )
            sessions[session.id] = session
            pendingWindowRequest = session.id
        } catch {
            NSLog("[DEBUG-finderhandoff] app failed: \(error)")
            incomingJobErrorMessage = "Convert couldn't open the file(s) sent from Finder."
        }
    }

    func makeSession(forDroppedFiles urls: [URL], targetFormat: OutputFormat) -> ConversionSession {
        let files = urls.map { url in
            ConversionSourceFile(
                url: url,
                fileName: url.lastPathComponent,
                pixelSize: FileMetadata.pixelSize(of: url),
                byteSize: FileMetadata.byteSize(of: url)
            )
        }
        let session = ConversionSession(files: files, targetFormat: targetFormat, defaultQuality: defaultQuality)
        sessions[session.id] = session
        return session
    }

    func session(for id: UUID) -> ConversionSession? {
        sessions[id]
    }

    func removeSession(_ id: UUID) {
        sessions[id] = nil
    }
}
