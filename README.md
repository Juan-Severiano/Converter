# Convert

A small, native macOS utility for converting images — straight from Finder or by dropping files onto the app.

<p align="center">
  <img src="Converter/ConverterIcon.icon/Assets/converter.png" width="128" alt="Convert app icon" />
</p>

## Features

- **Finder integration** — right-click one or more images in Finder and choose *Convert* to pick an output format, no need to open the app first.
- **Drag and drop** — drop files onto the Convert window to start a conversion.
- **Formats** — converts from PNG, JPEG, HEIC, TIFF, GIF, BMP, WebP, or SVG to JPEG, PNG, WebP, HEIC, TIFF, or PDF.
- **Batch conversion** — convert multiple files at once with live progress.
- **Jumps straight to the file** — opening from Finder skips the idle drop screen and takes you right to the conversion window, like Preview.

## Installation

Download the latest signed `.dmg` from [Releases](../../releases), open it, and drag **Convert** into `/Applications`.

## Requirements

- macOS 26 or later

## Development

Open `Converter.xcodeproj` in Xcode and run the **Converter** scheme.

The project is split into:

- **Converter** — the SwiftUI app (conversion window, settings).
- **ConvertFinderExtension** — the Finder Sync extension that adds the *Convert* context menu.
- **ConvertCore** — shared Swift package with the conversion engine, format detection, and batch processing logic.

## Releasing

See [docs/release-signing.md](docs/release-signing.md) for how signing, notarization, and the `.dmg` release pipeline work.
