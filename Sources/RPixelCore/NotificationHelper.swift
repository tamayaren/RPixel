import Foundation

public enum NotificationHelper {
    /// Dispatches a native macOS banner notification with optional sound
    public static func sendNotification(
        title: String = "RPixel",
        subtitle: String = "",
        message: String,
        sound: String? = "Glass"
    ) {
        var script = "display notification \"\(escapeAppleScript(message))\" with title \"\(escapeAppleScript(title))\""
        if !subtitle.isEmpty {
            script += " subtitle \"\(escapeAppleScript(subtitle))\""
        }
        if let sound = sound, !sound.isEmpty {
            script += " sound name \"\(sound)\""
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    private static func escapeAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
