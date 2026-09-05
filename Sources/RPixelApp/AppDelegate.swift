import AppKit
import Foundation
import RPixelCore

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var onFilesDropped: (([URL]) -> Void)?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
    }

    public func application(_ application: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        onFilesDropped?(urls)
    }

    /// Handles Finder Services requests when registered in Info.plist
    @objc public func fixAlphaService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let items = pboard.pasteboardItems else { return }

        var fileURLs: [URL] = []
        for item in items {
            if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                fileURLs.append(url)
            }
        }

        if fileURLs.isEmpty {
            if let filenames = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
                fileURLs = filenames.map { URL(fileURLWithPath: $0) }
            }
        }

        guard !fileURLs.isEmpty else { return }

        let resolved = FileResolver.resolve(paths: fileURLs.map { $0.path }, recursive: true)
        let fixer = AlphaFixer.shared

        let startTime = CFAbsoluteTimeGetCurrent()
        var fixedCount = 0

        for url in resolved.pngURLs {
            let result = fixer.fixImage(at: url, debug: false)
            if result.success {
                fixedCount += 1
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        if fixedCount > 0 {
            NotificationHelper.sendNotification(
                title: "RPixel",
                subtitle: "Alpha Bleeding Resolved",
                message: String(format: "Successfully fixed %d images in %.2fs", fixedCount, elapsed)
            )
        }
    }
}
