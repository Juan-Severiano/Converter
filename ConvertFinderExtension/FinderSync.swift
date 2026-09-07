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
        let resizeFormat = FileTypeDetector.resizeOnlyFormat(forFiles: selectedURLs)
        guard !formats.isEmpty || resizeFormat != nil else { return nil }

        let menu = NSMenu(title: "")

        if let resizeFormat {
            let resizeItem = NSMenuItem(title: "Resize", action: #selector(resize(_:)), keyEquivalent: "")
            resizeItem.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: nil)
            resizeItem.tag = OutputFormat.allCases.firstIndex(of: resizeFormat) ?? -1
            menu.addItem(resizeItem)
        }

        if !formats.isEmpty {
            let convertItem = NSMenuItem(title: "Convert", action: nil, keyEquivalent: "")
            convertItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)

            let submenu = NSMenu(title: "Convert")
            for format in formats {
                let item = NSMenuItem(title: format.displayName, action: #selector(convert(_:)), keyEquivalent: "")
                // Finder Sync supports `tag` for menu payloads. It does not guarantee preservation of
                // target or representedObject when it transfers an NSMenu across the extension boundary.
                item.tag = OutputFormat.allCases.firstIndex(of: format) ?? -1
                submenu.addItem(item)
            }
            convertItem.submenu = submenu
            menu.addItem(convertItem)
        }

        return menu
    }

    @objc func convert(_ sender: NSMenuItem) {
        handOff(formatTag: sender.tag, isResizeOnly: false, logTag: "convert")
    }

    @objc func resize(_ sender: NSMenuItem) {
        handOff(formatTag: sender.tag, isResizeOnly: true, logTag: "resize")
    }

    private func handOff(formatTag: Int, isResizeOnly: Bool, logTag: String) {
        NSLog("[DEBUG-finderhandoff] extension action invoked (\(logTag))")
        guard formatTag >= 0, formatTag < OutputFormat.allCases.count else {
            NSLog("[DEBUG-finderhandoff] extension action missing payload")
            return
        }
        let format = OutputFormat.allCases[formatTag]
        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        NSLog("[DEBUG-finderhandoff] extension selected files=\(selectedURLs.count) format=\(format.rawValue) resizeOnly=\(isResizeOnly)")
        guard !selectedURLs.isEmpty else { return }

        do {
            let job = FinderSelectionSnapshot(fileURLs: selectedURLs)
                .pendingJob(targetFormat: format, isResizeOnly: isResizeOnly)
            let handoffURL = try FinderJobURL.make(job: job)
            let didOpen = NSWorkspace.shared.open(handoffURL)
            NSLog("[DEBUG-finderhandoff] extension files=\(job.files.count) format=\(format.rawValue) open=\(didOpen)")
            guard didOpen else {
                throw NSError(domain: "ConvertFinderExtension", code: 1, userInfo: nil)
            }
        } catch {
            NSLog("[DEBUG-finderhandoff] extension failed: \(error)")
        }
    }
}
