import Foundation

public enum QuickActionManager {
    public static let workflowName = "Fix Alpha with RPixel.workflow"
    public static let menuTitle = "Fix Alpha with RPixel"

    public static var servicesDirectoryURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Services", isDirectory: true)
    }

    public static var workflowURL: URL {
        return servicesDirectoryURL.appendingPathComponent(workflowName, isDirectory: true)
    }

    public static var isInstalled: Bool {
        let wflowDoc = workflowURL.appendingPathComponent("Contents/Resources/document.wflow")
        return FileManager.default.fileExists(atPath: wflowDoc.path)
    }

    /// Installs or updates the Finder Quick Action in ~/Library/Services/
    @discardableResult
    public static func install() throws -> URL {
        let fm = FileManager.default
        let servicesDir = servicesDirectoryURL

        if !fm.fileExists(atPath: servicesDir.path) {
            try fm.createDirectory(at: servicesDir, withIntermediateDirectories: true)
        }

        let targetWorkflow = workflowURL
        if fm.fileExists(atPath: targetWorkflow.path) {
            try fm.removeItem(at: targetWorkflow)
        }

        let contentsDir = targetWorkflow.appendingPathComponent("Contents", isDirectory: true)
        let resourcesDir = contentsDir.appendingPathComponent("Resources", isDirectory: true)
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Generate Info.plist
        let infoPlist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en_US",
            "CFBundleIdentifier": "com.rpixel.service.fixalpha",
            "CFBundleName": menuTitle,
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1.0",
            "NSServices": [
                [
                    "NSMenuItem": [
                        "default": menuTitle
                    ],
                    "NSMessage": "runWorkflowAsService",
                    "NSRequiredContext": [
                        "NSApplicationIdentifier": "com.apple.finder"
                    ],
                    "NSSendFileTypes": [
                        "public.png",
                        "public.image"
                    ]
                ]
            ]
        ]

        let infoPlistData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
        try infoPlistData.write(to: contentsDir.appendingPathComponent("Info.plist"))

        // Script content executed when user right-clicks
        let scriptBody = """
        RPIXEL_BIN=""
        if [ -x "/Applications/RPixel.app/Contents/MacOS/RPixel" ]; then
            RPIXEL_BIN="/Applications/RPixel.app/Contents/MacOS/RPixel"
        elif [ -x "$HOME/Applications/RPixel.app/Contents/MacOS/RPixel" ]; then
            RPIXEL_BIN="$HOME/Applications/RPixel.app/Contents/MacOS/RPixel"
        elif command -v RPixel >/dev/null 2>&1; then
            RPIXEL_BIN="$(command -v RPixel)"
        elif command -v rpixel >/dev/null 2>&1; then
            RPIXEL_BIN="$(command -v rpixel)"
        elif [ -x "/usr/local/bin/RPixel" ]; then
            RPIXEL_BIN="/usr/local/bin/RPixel"
        elif [ -x "/usr/local/bin/rpixel" ]; then
            RPIXEL_BIN="/usr/local/bin/rpixel"
        elif [ -x "$HOME/.local/bin/RPixel" ]; then
            RPIXEL_BIN="$HOME/.local/bin/RPixel"
        elif [ -x "$HOME/.local/bin/rpixel" ]; then
            RPIXEL_BIN="$HOME/.local/bin/rpixel"
        fi

        if [ -n "$RPIXEL_BIN" ]; then
            "$RPIXEL_BIN" "$@"
        else
            osascript -e 'display alert "RPixel Not Found" message "Please ensure RPixel is installed in /Applications or run ./install.sh."'
        fi
        """

        let actionUUID = UUID().uuidString.uppercased()
        let inputUUID = UUID().uuidString.uppercased()
        let outputUUID = UUID().uuidString.uppercased()

        let documentWflow: [String: Any] = [
            "AMApplicationBuild": "520",
            "AMApplicationVersion": "2.10",
            "AMDocumentVersion": "2",
            "actions": [
                [
                    "action": [
                        "AMAccepts": [
                            "Container": "List",
                            "Optional": false,
                            "Types": ["com.apple.cocoa.path"]
                        ],
                        "AMActionVersion": "2.0.3",
                        "AMApplication": ["Automator"],
                        "AMParameterProperties": [
                            "COMMAND_STRING": [String: Any](),
                            "CheckedForUserDefaultShell": [String: Any](),
                            "inputMethod": [String: Any](),
                            "shell": [String: Any](),
                            "source": [String: Any]()
                        ],
                        "AMProvides": [
                            "Container": "List",
                            "Types": ["com.apple.cocoa.path"]
                        ],
                        "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
                        "ActionName": "Run Shell Script",
                        "ActionParameters": [
                            "COMMAND_STRING": scriptBody,
                            "CheckedForUserDefaultShell": true,
                            "inputMethod": 1, // 1 = passed as arguments ("$@")
                            "shell": "/bin/zsh",
                            "source": ""
                        ],
                        "BundleIdentifier": "com.apple.RunShellScript",
                        "CFBundleVersion": "2.0.3",
                        "CanShowSelectedItemsWhenRun": false,
                        "CanShowWhenRun": true,
                        "Category": ["AMCategoryUtilities"],
                        "Class Name": "RunShellScriptAction",
                        "InputUUID": inputUUID,
                        "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
                        "OutputUUID": outputUUID,
                        "UUID": actionUUID,
                        "UnlocalizedApplications": ["Automator"],
                        "arguments": [
                            "0": ["default value": 0, "name": "inputMethod", "required": "0", "type": "0", "uuid": "0"],
                            "1": ["default value": "", "name": "source", "required": "0", "type": "0", "uuid": "1"],
                            "2": ["default value": false, "name": "CheckedForUserDefaultShell", "required": "0", "type": "0", "uuid": "2"],
                            "3": ["default value": "", "name": "COMMAND_STRING", "required": "0", "type": "0", "uuid": "3"],
                            "4": ["default value": "/bin/sh", "name": "shell", "required": "0", "type": "0", "uuid": "4"]
                        ],
                        "isViewVisible": true,
                        "location": "309.500000:631.000000",
                        "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/en.lproj/main.nib"
                    ],
                    "isViewVisible": true
                ]
            ],
            "connectors": [String: Any](),
            "state": [
                "AMLogTabViewSelectedIndex": 0
            ],
            "workflowMetaData": [
                "serviceApplicationBundleID": "com.apple.finder",
                "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
                "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject.image",
                "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
                "serviceProcessesInput": 0,
                "workflowTypeIdentifier": "com.apple.Automator.servicesMenu"
            ]
        ]

        let documentData = try PropertyListSerialization.data(
            fromPropertyList: documentWflow,
            format: .xml,
            options: 0
        )
        try documentData.write(to: resourcesDir.appendingPathComponent("document.wflow"))

        refreshLaunchServices()
        return targetWorkflow
    }

    /// Uninstalls the Finder Quick Action
    public static func uninstall() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: workflowURL.path) {
            try fm.removeItem(at: workflowURL)
            refreshLaunchServices()
        }
    }

    /// Refreshes macOS LaunchServices to recognize new or removed Services
    public static func refreshLaunchServices() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/touch")
        task.arguments = [servicesDirectoryURL.path]
        try? task.run()
        task.waitUntilExit()

        let lsregisterPaths = [
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        ]

        for path in lsregisterPaths {
            if FileManager.default.fileExists(atPath: path) {
                let ls = Process()
                ls.executableURL = URL(fileURLWithPath: path)
                ls.arguments = ["-R", servicesDirectoryURL.path]
                try? ls.run()
                ls.waitUntilExit()
                break
            }
        }
    }

    /// Installs CLI symlink to /usr/local/bin/RPixel or ~/.local/bin/RPixel
    @discardableResult
    public static func installCLISymlink(from binaryURL: URL) -> (success: Bool, path: String) {
        let fm = FileManager.default

        // Try /usr/local/bin first
        let usrLocalBin = URL(fileURLWithPath: "/usr/local/bin")
        let targetUsrLocal = usrLocalBin.appendingPathComponent("RPixel")
        let targetUsrLocalLower = usrLocalBin.appendingPathComponent("rpixel")

        if fm.isWritableFile(atPath: usrLocalBin.path) || (!fm.fileExists(atPath: targetUsrLocal.path) && fm.isWritableFile(atPath: "/usr/local")) {
            try? fm.removeItem(at: targetUsrLocal)
            try? fm.removeItem(at: targetUsrLocalLower)
            if (try? fm.createSymbolicLink(at: targetUsrLocal, withDestinationURL: binaryURL)) != nil {
                try? fm.createSymbolicLink(at: targetUsrLocalLower, withDestinationURL: binaryURL)
                return (true, targetUsrLocal.path)
            }
        }

        // Fallback to ~/.local/bin
        let userLocalBin = fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin")
        try? fm.createDirectory(at: userLocalBin, withIntermediateDirectories: true)
        let targetUserLocal = userLocalBin.appendingPathComponent("RPixel")
        let targetUserLocalLower = userLocalBin.appendingPathComponent("rpixel")
        try? fm.removeItem(at: targetUserLocal)
        try? fm.removeItem(at: targetUserLocalLower)
        if (try? fm.createSymbolicLink(at: targetUserLocal, withDestinationURL: binaryURL)) != nil {
            try? fm.createSymbolicLink(at: targetUserLocalLower, withDestinationURL: binaryURL)
            return (true, targetUserLocal.path)
        }

        return (false, "")
    }
}
