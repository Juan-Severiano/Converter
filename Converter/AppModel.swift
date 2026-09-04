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

    private let sharedDefaults = UserDefaults(suiteName: AppGroupJobStore.appGroupIdentifier)

    var defaultQuality: Int {
        let stored = sharedDefaults?.integer(forKey: "defaultQuality") ?? 0
        return stored == 0 ? 85 : stored
    }

    /// Handles `convert://open-job?id=<uuid>`, opened by the Finder Sync extension after it wrote
    /// a `PendingJob` into the shared App Group container.
    func handleIncomingURL(_ url: URL) {
        guard
            url.scheme == "convert", url.host == "open-job",
            let idString = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value,
            let id = UUID(uuidString: idString)
        else { return }

        do {
            let pendingJob = try AppGroupJobStore.read(id: id)
            AppGroupJobStore.remove(id: id)

            var files: [ConversionSourceFile] = []
            var accesses: [SecurityScopedFolderAccess] = []
            for pendingFile in pendingJob.files {
                let access = try SecurityScopedBookmark.resolveFolderAccess(pendingFile.folderBookmark)
                accesses.append(access)
                let fileURL = access.fileURL(named: pendingFile.fileName)
                files.append(
                    ConversionSourceFile(
                        url: fileURL,
                        fileName: pendingFile.fileName,
                        pixelSize: FileMetadata.pixelSize(of: fileURL),
                        byteSize: FileMetadata.byteSize(of: fileURL)
                    )
                )
            }

            let session = ConversionSession(
                files: files,
                targetFormat: pendingJob.targetFormat,
                defaultQuality: pendingJob.quality ?? defaultQuality,
                folderAccesses: accesses
            )
            sessions[session.id] = session
            pendingWindowRequest = session.id
        } catch {
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
        sessions[id]?.releaseSecurityScopedAccess()
        sessions[id] = nil
    }
}
