import Foundation

public enum PrivacyFindingCategory: String, Codable, Sendable {
    case network
    case analytics
    case externalAI
    case localCLI
    case appleLocalFramework
    case remotePackageDependency
    case sensitivePersistence
}

public enum PrivacyRiskLevel: String, Codable, Sendable {
    case info
    case review
    case privacyRisk
    case egressRisk
}

public struct PrivacyAuditFinding: Codable, Equatable, Sendable {
    public let path: String
    public let line: Int
    public let category: PrivacyFindingCategory
    public let risk: PrivacyRiskLevel
    public let ruleID: String
    public let token: String
    public let excerpt: String
}

public struct PrivacyAuditReport: Codable, Equatable, Sendable {
    public let scannedFiles: Int
    public let findings: [PrivacyAuditFinding]
    public let productionEgressRisks: [PrivacyAuditFinding]
    public let releaseBlockingFindings: [PrivacyAuditFinding]
    public let hqReleaseGateRequired: Bool

    public init(scannedFiles: Int, findings: [PrivacyAuditFinding]) {
        self.scannedFiles = scannedFiles
        self.findings = findings
        self.productionEgressRisks = findings.filter { $0.risk == .egressRisk }
        self.releaseBlockingFindings = findings.filter { $0.risk == .egressRisk || $0.risk == .privacyRisk }
        self.hqReleaseGateRequired = true
    }
}

public struct PrivacyAuditRule: Sendable, Equatable {
    public let id: String
    public let category: PrivacyFindingCategory
    public let risk: PrivacyRiskLevel
    public let tokens: [String]
    public let caseSensitive: Bool

    public init(id: String, category: PrivacyFindingCategory, risk: PrivacyRiskLevel, tokens: [String], caseSensitive: Bool = false) {
        self.id = id
        self.category = category
        self.risk = risk
        self.tokens = tokens
        self.caseSensitive = caseSensitive
    }
}

public struct PrivacyStaticAuditor: Sendable {
    public let rules: [PrivacyAuditRule]
    public let excludedPathFragments: [String]

    public init(
        extraDenylist: [String] = [],
        extraAllowlist: [String] = [],
        excludedPathFragments: [String] = ["/Tests/", "/PrivacyAudit/PrivacyStaticAuditor.swift"]
    ) {
        var builtins: [PrivacyAuditRule] = [
            .init(id: "network-api", category: .network, risk: .egressRisk,
                  tokens: ["URLSession", "URLRequest", "NWConnection", "webSocketTask", "Alamofire", "AsyncHTTPClient"]),
            .init(id: "network-cli", category: .network, risk: .egressRisk,
                  tokens: ["curl ", "curl\"", "wget ", "https://api.", "http://api."]),
            .init(id: "analytics-sdk", category: .analytics, risk: .egressRisk,
                  tokens: ["FirebaseAnalytics", "Analytics.logEvent", "Mixpanel", "Amplitude", "SentrySDK", "PostHog", "TelemetryDeck", "Datadog", "AppCenter"]),
            .init(id: "external-ai", category: .externalAI, risk: .egressRisk,
                  tokens: ["api.openai.com", "OpenAI(", "Anthropic", "api.anthropic.com", "generativelanguage.googleapis.com", "Gemini", "Replicate", "api-inference.huggingface.co", "/chat/completions"]),
            .init(id: "local-cli", category: .localCLI, risk: .review,
                  tokens: ["Process()", "Process(", "executableURL", "tesseract", "ocrmypdf", "python3", "ffmpeg", "swiftc", "xcrun"]),
            .init(id: "apple-local-framework", category: .appleLocalFramework, risk: .info,
                  tokens: ["import Vision", "import VisionKit", "import PDFKit", "import CoreGraphics", "import CoreImage", "import AVFoundation", "import ImageIO", "import NaturalLanguage", "import Accelerate"]),
            .init(id: "remote-package", category: .remotePackageDependency, risk: .review,
                  tokens: [".package(url:", ".package(url :"])
        ]
        if !extraDenylist.isEmpty {
            builtins.append(.init(id: "custom-denylist", category: .network, risk: .egressRisk, tokens: extraDenylist))
        }
        let allow = Set(extraAllowlist.map { $0.lowercased() })
        self.rules = builtins.map { rule in
            let effectiveTokens = rule.risk == .egressRisk
                ? rule.tokens
                : rule.tokens.filter { !allow.contains($0.lowercased()) }
            return PrivacyAuditRule(id: rule.id, category: rule.category, risk: rule.risk,
                                    tokens: effectiveTokens, caseSensitive: rule.caseSensitive)
        }
        self.excludedPathFragments = excludedPathFragments
    }

    public func audit(files: [String: String]) -> PrivacyAuditReport {
        var findings: [PrivacyAuditFinding] = []
        var scanned = 0
        for (path, content) in files.sorted(by: { $0.key < $1.key }) {
            if excludedPathFragments.contains(where: { path.contains($0) }) { continue }
            scanned += 1
            findings.append(contentsOf: scan(path: path, content: content))
        }
        return PrivacyAuditReport(scannedFiles: scanned, findings: findings.sorted {
            if $0.path == $1.path { return $0.line < $1.line }
            return $0.path < $1.path
        })
    }

    public func auditDirectory(_ root: URL) throws -> PrivacyAuditReport {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return PrivacyAuditReport(scannedFiles: 0, findings: [])
        }
        var files: [String: String] = [:]
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let ext = url.pathExtension.lowercased()
            guard ["swift", "m", "mm", "h", "json", "yml", "yaml", "plist", "sh"].contains(ext) || url.lastPathComponent == "Package.swift" else { continue }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            files[url.path.replacingOccurrences(of: root.path, with: "")] = text
        }
        return audit(files: files)
    }

    private func scan(path: String, content: String) -> [PrivacyAuditFinding] {
        let lines = content.components(separatedBy: .newlines)
        var out: [PrivacyAuditFinding] = []
        for (idx, line) in lines.enumerated() {
            for rule in rules {
                for token in rule.tokens {
                    let matched = rule.caseSensitive
                        ? line.contains(token)
                        : line.range(of: token, options: [.caseInsensitive]) != nil
                    if matched {
                        out.append(.init(path: path, line: idx + 1, category: rule.category, risk: rule.risk,
                                         ruleID: rule.id, token: token, excerpt: String(line.prefix(240))))
                    }
                }
            }
        }
        return out
    }

    public static func markdown(report: PrivacyAuditReport) -> String {
        var lines = [
            "# Privacy Static Audit Report", "",
            "- scanned_files: \(report.scannedFiles)",
            "- egress_risk_findings: \(report.productionEgressRisks.count)",
            "- release_blocking_findings: \(report.releaseBlockingFindings.count)",
            "- hq_release_gate_required: \(report.hqReleaseGateRequired)", "", "## Findings"
        ]
        if report.findings.isEmpty {
            lines.append("- none")
        } else {
            for f in report.findings {
                lines.append("- [\(f.risk.rawValue)] \(f.category.rawValue) \(f.path):\(f.line) `\(f.ruleID)` token=`\(f.token)`")
            }
        }
        lines += ["", "Static audit is evidence only. Final Privacy PASS/FAIL is owned by HQ Release Gate."]
        return lines.joined(separator: "\n")
    }
}
