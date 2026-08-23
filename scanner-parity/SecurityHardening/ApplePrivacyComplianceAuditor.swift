import Foundation

public enum ApplePrivacyComplianceIssue: Equatable, Sendable {
    case missingPrivacyManifest
    case trackingEnabled
    case trackingDomainsPresent
    case collectedDataDeclared
    case missingCameraUsageDescription
    case missingPhotoLibraryUsageDescription
    case requiredReasonAPINeedsDeclaration(String)
    case invalidPrivacyManifest(String)
}

public struct ApplePrivacyComplianceReport: Equatable, Sendable {
    public let issues: [ApplePrivacyComplianceIssue]
    public let detectedRequiredReasonCategories: [String]
    public var isFailClosedPass: Bool { issues.isEmpty }
}

public struct ApplePrivacyComplianceAuditor: Sendable {
    public init() {}

    public func audit(
        sourceFiles: [String: String],
        infoPlist: String?,
        privacyManifest: String?
    ) -> ApplePrivacyComplianceReport {
        var issues: [ApplePrivacyComplianceIssue] = []
        let joined = sourceFiles.values.joined(separator: "\n")

        let requiredCategories = detectRequiredReasonCategories(in: joined)
        guard let privacyManifest else {
            return .init(issues: [.missingPrivacyManifest] + requiredCategories.map { .requiredReasonAPINeedsDeclaration($0) },
                         detectedRequiredReasonCategories: requiredCategories)
        }

        if !privacyManifest.contains("<key>NSPrivacyTracking</key>") {
            issues.append(.invalidPrivacyManifest("NSPrivacyTracking missing"))
        }
        if privacyManifest.contains("<key>NSPrivacyTracking</key>\n  <true/>") ||
            privacyManifest.contains("<key>NSPrivacyTracking</key>\n\t<true/>") {
            issues.append(.trackingEnabled)
        }
        if let trackingDomains = arrayBody(for: "NSPrivacyTrackingDomains", in: privacyManifest),
           trackingDomains.range(of: "<string>", options: .caseInsensitive) != nil {
            issues.append(.trackingDomainsPresent)
        }
        if let collected = arrayBody(for: "NSPrivacyCollectedDataTypes", in: privacyManifest),
           collected.range(of: "<dict>", options: .caseInsensitive) != nil {
            issues.append(.collectedDataDeclared)
        }

        for category in requiredCategories where !privacyManifest.contains(category) {
            issues.append(.requiredReasonAPINeedsDeclaration(category))
        }

        if sourceNeedsCamera(joined), !(infoPlist?.contains("NSCameraUsageDescription") ?? false) {
            issues.append(.missingCameraUsageDescription)
        }
        if sourceNeedsPhotoLibrary(joined), !(infoPlist?.contains("NSPhotoLibraryUsageDescription") ?? false) {
            issues.append(.missingPhotoLibraryUsageDescription)
        }

        return .init(issues: issues, detectedRequiredReasonCategories: requiredCategories)
    }

    public func detectRequiredReasonCategories(in source: String) -> [String] {
        var categories: Set<String> = []
        if source.contains("UserDefaults") {
            categories.insert("NSPrivacyAccessedAPICategoryUserDefaults")
        }
        if source.contains("systemUptime") || source.contains("mach_absolute_time") {
            categories.insert("NSPrivacyAccessedAPICategorySystemBootTime")
        }
        if source.contains("volumeAvailableCapacity") || source.contains("systemFreeSize") || source.contains("systemSize") {
            categories.insert("NSPrivacyAccessedAPICategoryDiskSpace")
        }
        if source.contains("creationDate") || source.contains("contentModificationDate") || source.contains("fileModificationDate") {
            categories.insert("NSPrivacyAccessedAPICategoryFileTimestamp")
        }
        return categories.sorted()
    }

    private func sourceNeedsCamera(_ source: String) -> Bool {
        source.contains("AVCaptureDevice") || source.contains("AVCaptureSession") || source.contains("UIImagePickerController.SourceType.camera")
    }

    private func sourceNeedsPhotoLibrary(_ source: String) -> Bool {
        source.contains("PHPhotoLibrary") || source.contains("PHPickerViewController") || source.contains("UIImagePickerController.SourceType.photoLibrary")
    }

    private func arrayBody(for key: String, in plist: String) -> String? {
        guard let keyRange = plist.range(of: "<key>\(key)</key>"),
              let start = plist.range(of: "<array>", range: keyRange.upperBound..<plist.endIndex),
              let end = plist.range(of: "</array>", range: start.upperBound..<plist.endIndex) else { return nil }
        return String(plist[start.upperBound..<end.lowerBound])
    }
}
