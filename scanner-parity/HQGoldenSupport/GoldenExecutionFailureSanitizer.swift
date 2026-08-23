import Foundation

public enum GoldenExecutionFailureSanitizer {
    public static func sanitize(message: String, redactedPaths: [String]) -> String {
        var sanitized = message
        let paths = redactedPaths
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }

        for path in paths {
            sanitized = sanitized.replacingOccurrences(of: path, with: "<REDACTED_PATH>")
            let fileURL = URL(fileURLWithPath: path).absoluteString
            sanitized = sanitized.replacingOccurrences(of: fileURL, with: "<REDACTED_URL>")
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty {
            sanitized = sanitized.replacingOccurrences(of: home, with: "<HOME>")
            sanitized = sanitized.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.absoluteString, with: "<HOME_URL>")
        }
        return sanitized
    }
}
