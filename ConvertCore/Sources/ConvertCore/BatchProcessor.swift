import Foundation

/// Fans a `ConversionRequest` out into concurrent per-file jobs and streams progress as they land.
///
/// Cancellation is cooperative: ending the stream (e.g. the UI's Cancel button stops consuming it)
/// cancels the underlying task, which `ConversionEngine.convert(job:)` observes between steps —
/// no partially-written file is ever left behind, since writes only land via an atomic move.
public enum BatchProcessor {
    public static func run(request: ConversionRequest) -> AsyncStream<BatchEvent> {
        let jobs = request.makeJobs()
        return AsyncStream { continuation in
            let task = Task {
                continuation.yield(.started(total: jobs.count))

                await withTaskGroup(of: (Int, Result<ConversionResult, ConversionError>).self) { group in
                    for (index, job) in jobs.enumerated() {
                        group.addTask {
                            do {
                                let result = try await ConversionEngine.convert(job: job)
                                return (index, .success(result))
                            } catch let error as ConversionError {
                                return (index, .failure(error))
                            } catch {
                                return (index, .failure(.destinationWriteFailed(underlying: error.localizedDescription)))
                            }
                        }
                    }

                    for await (index, outcome) in group {
                        guard !Task.isCancelled else { break }
                        switch outcome {
                        case .success(let result):
                            continuation.yield(.fileSucceeded(index: index, total: jobs.count, result: result))
                        case .failure(let error):
                            continuation.yield(.fileFailed(index: index, total: jobs.count, sourceURL: jobs[index].sourceURL, error: error))
                        }
                    }
                }

                continuation.yield(.finished)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
