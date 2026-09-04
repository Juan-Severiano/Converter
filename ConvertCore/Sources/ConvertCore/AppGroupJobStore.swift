import Foundation

/// Reads and writes `PendingJob`s in the App Group container shared between the main app and the
/// Finder Sync extension — the actual handoff mechanism behind `convert://open-job?id=...`.
public enum AppGroupJobStore {
    public static let appGroupIdentifier = "group.com.juansev.Converter"

    public enum StoreError: Error, Sendable {
        case containerUnavailable
    }

    public static func write(_ job: PendingJob, fileManager: FileManager = .default) throws {
        let directory = try pendingJobsDirectory(fileManager: fileManager)
        let url = directory.appendingPathComponent("\(job.id.uuidString).json")
        let data = try JSONEncoder().encode(job)
        try data.write(to: url, options: .atomic)
    }

    public static func read(id: UUID, fileManager: FileManager = .default) throws -> PendingJob {
        let directory = try pendingJobsDirectory(fileManager: fileManager)
        let url = directory.appendingPathComponent("\(id.uuidString).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PendingJob.self, from: data)
    }

    public static func remove(id: UUID, fileManager: FileManager = .default) {
        guard let directory = try? pendingJobsDirectory(fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: directory.appendingPathComponent("\(id.uuidString).json"))
    }

    private static func pendingJobsDirectory(fileManager: FileManager) throws -> URL {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw StoreError.containerUnavailable
        }
        let directory = container.appendingPathComponent("PendingJobs", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
