import Foundation
import RPixelCore
import Dispatch

func drawWatermark() {
    print("""
       ____  ____  _          _ 
      |  _ \\|  _ \\(_)_  _____| |
      | |_) | |_) | \\ \\/ / _ \\ |
      |  _ <|  __/| |>  <  __/ |
      |_| \\_\\_|   |_/_/\\_\\___|_|

    """)
}

func printHelp() {
    print("""
    Usage: RPixel [options] <files/directories...>

    Options:
      -d, --debug        Set transparent pixel alpha to 255 for visual inspection
      -r, --recursive    Recursively scan directories for PNG files
      --install          Install the Finder right-click Quick Action and CLI symlink
      --uninstall        Uninstall the Finder right-click Quick Action
      -h, --help         Show this help message

    Examples:
      RPixel character.png item.png
      RPixel -d textures/
      RPixel --install
    """)
}

// Check if stdout is an interactive terminal
let isInteractive = isatty(fileno(stdout)) != 0

var args = Array(CommandLine.arguments.dropFirst())
var debug = false
var recursive = true // default to recursive for modern Mac workflows

// Parse options
if let debugIdx = args.firstIndex(where: { $0 == "-d" || $0 == "--debug" }) {
    debug = true
    args.remove(at: debugIdx)
}

if let recIdx = args.firstIndex(where: { $0 == "-r" || $0 == "--recursive" }) {
    recursive = true
    args.remove(at: recIdx)
}

if args.contains("-h") || args.contains("--help") {
    drawWatermark()
    printHelp()
    exit(0)
}

if args.contains("--install") {
    drawWatermark()
    print("Installing Finder Quick Action...")
    do {
        let path = try QuickActionManager.install()
        print("✓ Successfully installed Finder Quick Action to:")
        print("  \(path.path)")
        print("\nYou can now right-click any PNG in Finder -> Quick Actions -> Fix Alpha with RPixel!")
    } catch {
        print("✗ Failed to install Quick Action: \(error.localizedDescription)")
    }

    let binaryURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let (symlinkSuccess, symlinkPath) = QuickActionManager.installCLISymlink(from: binaryURL)
    if symlinkSuccess {
        print("✓ Created CLI symlink at \(symlinkPath)")
    }
    exit(0)
}

if args.contains("--uninstall") {
    drawWatermark()
    print("Uninstalling Finder Quick Action...")
    do {
        try QuickActionManager.uninstall()
        print("✓ Successfully uninstalled Finder Quick Action.")
    } catch {
        print("✗ Failed to uninstall Quick Action: \(error.localizedDescription)")
    }
    exit(0)
}

let isQuiet = args.contains("-q") || args.contains("--quiet")
if let qIdx = args.firstIndex(where: { $0 == "-q" || $0 == "--quiet" }) {
    args.remove(at: qIdx)
}

if !isQuiet {
    drawWatermark()
}

if args.isEmpty {
    if !isQuiet {
        print("Drop png files on the app or provide paths to fix them!\n")
        printHelp()
    }
    exit(0)
}

if !isQuiet {
    print("Processing your files, please wait!")
}

let startTime = CFAbsoluteTimeGetCurrent()
let resolved = FileResolver.resolve(paths: args, recursive: recursive)

if !isQuiet {
    for missing in resolved.missingPaths {
        print("Ignoring \"\(missing)\" - It does not exist!")
    }

    for skipped in resolved.skippedNonPNGURLs {
        print("Ignoring \"\(skipped.lastPathComponent)\" - Only PNG files are accepted!")
    }
}

let filesToProcess = resolved.pngURLs
let lock = NSLock()
var filesFixed = 0
var filesFailed = resolved.skippedCount

let fixer = AlphaFixer.shared

if !filesToProcess.isEmpty {
    let queue = DispatchQueue(label: "com.rpixel.cli.worker", attributes: .concurrent)
    let group = DispatchGroup()

    for fileURL in filesToProcess {
        group.enter()
        queue.async {
            let result = fixer.fixImage(at: fileURL, debug: debug)
            lock.lock()
            if result.success {
                filesFixed += 1
            } else {
                filesFailed += 1
                if !isQuiet, let err = result.errorMessage {
                    print("Could not fix \"\(fileURL.lastPathComponent)\": \(err)")
                }
            }
            lock.unlock()
            group.leave()
        }
    }

    group.wait()
}

let elapsed = CFAbsoluteTimeGetCurrent() - startTime

if !isQuiet {
    print("")
    if filesFixed > 0 {
        print(String(format: "Successfully fixed %d images in %.4f seconds!", filesFixed, elapsed))
    } else {
        print("No files were able to be fixed!")
    }

    if filesFailed > 0 {
        print("Skipped \(filesFailed) files that couldn't be fixed!")
    }
}

// Send system banner notification when run non-interactively or from Automator
let isFinderInvocation = isatty(fileno(stdin)) == 0 || ProcessInfo.processInfo.environment["AUTOMATOR_RUN"] != nil
if isFinderInvocation {
    if filesFixed > 0 {
        NotificationHelper.sendNotification(
            title: "RPixel",
            subtitle: "Alpha Bleeding Resolved",
            message: String(format: "Successfully fixed %d images in %.2fs", filesFixed, elapsed)
        )
    } else if filesFailed > 0 {
        NotificationHelper.sendNotification(
            title: "RPixel",
            subtitle: "No Images Fixed",
            message: "None of the selected images contained transparent borders to fix."
        )
    }
}
