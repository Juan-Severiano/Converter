//
//  FinderSync.swift
//  ConvertFinderExtension
//
//  Deliberately thin: builds the "Convert" contextual menu and, on click, hands the selected
//  files off to the main app. No decoding, resizing, or encoding happens in this process.
//

import Cocoa
import ConvertCore
import FinderSync

class FinderSync: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = Self.watchedDirectoryURLs()

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didMountNotification, object: nil)
        center.addObserver(self, selector: #selector(volumesChanged), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    /// Home folder + every mounted volume, so "Convert" shows up almost everywhere — the scope a
    /// context-menu-only Finder Sync extension (no badges) can afford, matching what utilities
    /// like Keka or BetterZip watch for the same reason. Kept behind one function so a future
    /// Settings screen can make this configurable without touching the rest of the extension.
    private static func watchedDirectoryURLs() -> Set<URL> {
        var urls: Set<URL> = [FileManager.default.homeDirectoryForCurrentUser]
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        urls.formUnion(mounted)
        return urls
    }

    @objc private func volumesChanged() {
        FIFinderSyncController.default().directoryURLs = Self.watchedDirectoryURLs()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }

        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard !selectedURLs.isEmpty else { return nil }

        let formats = FileTypeDetector.availableOutputFormats(forFiles: selectedURLs)
        guard !formats.isEmpty else { return nil }

        let convertItem = NSMenuItem(title: "Convert", action: nil, keyEquivalent: "")
        convertItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)

        let submenu = NSMenu(title: "Convert")
        for format in formats {
            let item = NSMenuItem(title: format.displayName, action: #selector(convert(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            submenu.addItem(item)
        }
        convertItem.submenu = submenu

        let menu = NSMenu(title: "")
        menu.addItem(convertItem)
        return menu
    }

    @objc private func convert(_ sender: NSMenuItem) {
        guard
            let rawFormat = sender.representedObject as? String,
            let format = OutputFormat(rawValue: rawFormat)
        else { return }

        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard !selectedURLs.isEmpty else { return }

        do {
            let files = try selectedURLs.map { url in
                PendingFile(folderBookmark: try SecurityScopedBookmark.makeFolderBookmark(for: url), fileName: url.lastPathComponent)
            }
            let job = PendingJob(files: files, targetFormat: format)
            try AppGroupJobStore.write(job)

            var components = URLComponents()
            components.scheme = "convert"
            components.host = "open-job"
            components.queryItems = [URLQueryItem(name: "id", value: job.id.uuidString)]
            if let url = components.url {
                NSWorkspace.shared.open(url)
            }
        } catch {
            NSLog("Convert extension: failed to hand off job — \(error)")
        }
    }
}
