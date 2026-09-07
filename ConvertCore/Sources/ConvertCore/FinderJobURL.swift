import Foundation

/// Encodes a Finder conversion request in Convert's private URL scheme.
///
/// The Finder Sync extension is sandboxed so macOS can register it, while the main app is not
/// sandboxed and writes the sibling output file. Passing the job in this local URL avoids an App
/// Group while keeping the extension itself discoverable by Finder.
public enum FinderJobURL {
    public enum Error: Swift.Error, Sendable, Equatable {
        case invalidURL
        case invalidPayload
    }

    public static func make(job: PendingJob) throws -> URL {
        let data = try JSONEncoder().encode(job)
        var components = URLComponents()
        components.scheme = "convert"
        components.host = "open-job"
        components.queryItems = [
            URLQueryItem(name: "payload", value: data.base64EncodedString()),
        ]
        guard let url = components.url else { throw Error.invalidURL }
        return url
    }

    public static func job(from url: URL) throws -> PendingJob {
        guard
            url.scheme == "convert",
            url.host == "open-job",
            let encodedPayload = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "payload" })?.value,
            let data = Data(base64Encoded: encodedPayload)
        else {
            throw Error.invalidPayload
        }
        return try JSONDecoder().decode(PendingJob.self, from: data)
    }
}
