import Foundation

public struct ResolvedFiles: Sendable {
    public let pngURLs: [URL]
    public let totalCandidateFiles: Int
    public let skippedNonPNGURLs: [URL]
    public let missingPaths: [String]

    public var skippedCount: Int {
        return (totalCandidateFiles - pngURLs.count) + missingPaths.count
    }

    public init(
        pngURLs: [URL],
        totalCandidateFiles: Int,
        skippedNonPNGURLs: [URL],
        missingPaths: [String]
    ) {
        self.pngURLs = pngURLs
        self.totalCandidateFiles = totalCandidateFiles
        self.skippedNonPNGURLs = skippedNonPNGURLs
        self.missingPaths = missingPaths
    }
}

public enum FileResolver {
    public static func isPNGFile(url: URL) -> Bool {
        return url.pathExtension.compare("png", options: .caseInsensitive) == .orderedSame
    }

    /// Resolves an array of path arguments into valid PNG URLs and statistics.
    /// - Parameters:
    ///   - paths: Array of file or directory path strings.
    ///   - recursive: Whether to recursively scan subdirectories.
    /// - Returns: ResolvedFiles containing URLs to process and skipped files.
    public static func resolve(paths: [String], recursive: Bool = true) -> ResolvedFiles {
        var pngURLs: [URL] = []
        var skippedNonPNGURLs: [URL] = []
        var missingPaths: [String] = []
        var totalCandidates = 0

        let fm = FileManager.default

        for rawPath in paths {
            let expandedPath = NSString(string: rawPath).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else {
                missingPaths.append(rawPath)
                continue
            }

            if !isDir.boolValue {
                totalCandidates += 1
                if isPNGFile(url: url) {
                    pngURLs.append(url)
                } else {
                    skippedNonPNGURLs.append(url)
                }
            } else {
                // Directory traversal
                if recursive {
                    if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                        for case let fileURL as URL in enumerator {
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                               resourceValues.isRegularFile == true {
                                totalCandidates += 1
                                if isPNGFile(url: fileURL) {
                                    pngURLs.append(fileURL)
                                } else {
                                    skippedNonPNGURLs.append(fileURL)
                                }
                            }
                        }
                    }
                } else {
                    if let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                        for fileURL in contents {
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                               resourceValues.isRegularFile == true {
                                totalCandidates += 1
                                if isPNGFile(url: fileURL) {
                                    pngURLs.append(fileURL)
                                } else {
                                    skippedNonPNGURLs.append(fileURL)
                                }
                            }
                        }
                    }
                }
            }
        }

        return ResolvedFiles(
            pngURLs: pngURLs,
            totalCandidateFiles: totalCandidates,
            skippedNonPNGURLs: skippedNonPNGURLs,
            missingPaths: missingPaths
        )
    }
}
