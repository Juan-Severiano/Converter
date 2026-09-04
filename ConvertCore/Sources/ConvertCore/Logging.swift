import os

/// Local-only diagnostic logging. Never transmitted anywhere — Convert has no analytics or network calls.
enum ConvertLog {
    static let conversion = Logger(subsystem: "com.juansev.Converter", category: "conversion")
}
