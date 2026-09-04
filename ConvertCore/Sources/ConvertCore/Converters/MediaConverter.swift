/// The shape every media converter (image, and future video/audio/PDF-input/document converters)
/// conforms to, so `ConversionEngine` can dispatch to whichever one handles a given `FileKind`
/// without the rest of the app knowing which concrete converter did the work.
///
/// Only image conversion is implemented in this version; this protocol is the extension point
/// the next media type plugs into.
protocol MediaConverter: Sendable {
    func convert(job: ConversionJob) async throws -> ConversionResult
}
