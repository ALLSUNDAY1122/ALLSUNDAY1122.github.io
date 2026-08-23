import Foundation

public enum SensitiveDataIssueKind: String, Codable, Sendable {
    case sensitiveLogging
    case cachePersistence
    case unsafeTemporaryLifecycle
    case networkBoundary
}

public struct SensitiveDataIssue: Codable, Equatable, Sendable {
    public let path: String
    public let line: Int
    public let kind: SensitiveDataIssueKind
    public let excerpt: String
}

public struct SensitiveDataStaticAudit: Sendable {
    public init() {}

    public func audit(files: [String: String]) -> [SensitiveDataIssue] {
        var issues: [SensitiveDataIssue] = []
        for (path, content) in files.sorted(by: { $0.key < $1.key }) {
            if path.contains("/Tests/") || path.contains("/SecurityHardening/") || path.contains("/PrivacyAudit/") { continue }
            for (index, line) in content.components(separatedBy: .newlines).enumerated() {
                let lower = line.lowercased()
                let sensitive = ["ocr", ".text", "pageimage", "imageurl", "sourcevideo", "bookpackage"].contains { lower.contains($0) }
                let logging = ["print(", "logger.", "os_log", "nslog("].contains { lower.contains($0) }
                if sensitive && logging {
                    issues.append(.init(path: path, line: index + 1, kind: .sensitiveLogging, excerpt: String(line.prefix(240))))
                }
                if sensitive && (lower.contains("cachesdirectory") || lower.contains("urlcache") || lower.contains("nscache")) {
                    issues.append(.init(path: path, line: index + 1, kind: .cachePersistence, excerpt: String(line.prefix(240))))
                }
                if sensitive && ["urlsession", "urlrequest", "nwconnection", "uploadtask", "datatask"].contains(where: lower.contains) {
                    issues.append(.init(path: path, line: index + 1, kind: .networkBoundary, excerpt: String(line.prefix(240))))
                }
            }
        }
        return issues
    }
}
