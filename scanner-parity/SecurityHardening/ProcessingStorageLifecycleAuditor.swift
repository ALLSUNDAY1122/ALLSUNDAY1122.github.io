import Foundation

public enum ProcessingStorageLifecycleIssue: String, Codable, Sendable, CaseIterable {
    case managedImportNotBackupExcluded
    case managedImportNotPurgeable
    case processingWorkspaceNotPurged
    case cameraPurposeStringNotRepresented
}

public struct ProcessingStorageLifecycleReport: Codable, Equatable, Sendable {
    public let issues: [ProcessingStorageLifecycleIssue]
    public var pass: Bool { issues.isEmpty }
}

public struct ProcessingStorageLifecycleAuditor: Sendable {
    public init() {}

    public func audit(
        mediaImportSource: String,
        productFlowStoreSource: String,
        productionRuntimeSource: String,
        appResourceTexts: [String]
    ) -> ProcessingStorageLifecycleReport {
        var issues: [ProcessingStorageLifecycleIssue] = []

        let usesManagedImports = mediaImportSource.contains("applicationSupportDirectory") && mediaImportSource.contains("Imports")
        if usesManagedImports && !mediaImportSource.contains("isExcludedFromBackup = true") {
            issues.append(.managedImportNotBackupExcluded)
        }
        if usesManagedImports && !(mediaImportSource.contains("discardImportedAssets") && mediaImportSource.contains("removeItem")) {
            issues.append(.managedImportNotPurgeable)
        }

        let usesPersistentWorkspace = productFlowStoreSource.contains("applicationSupportDirectory")
        let writesIntermediateStages = ["01-frame-extraction", "02-image-correction", "03-page-audit", "04-ocr"].allSatisfy {
            productionRuntimeSource.contains($0)
        }
        if usesPersistentWorkspace && writesIntermediateStages {
            let hasWorkspacePurge = productFlowStoreSource.contains("removeItem(at: workspace") ||
                productFlowStoreSource.contains("removeItem(at: workspaceRoot") ||
                productFlowStoreSource.contains("purgeProcessingWorkspace") ||
                productFlowStoreSource.contains("cleanupProcessingWorkspace")
            if !hasWorkspacePurge {
                issues.append(.processingWorkspaceNotPurged)
            }
        }

        let usesCamera = mediaImportSource.contains("AVCaptureDevice") || mediaImportSource.contains("AVCaptureSession")
        let resourceText = appResourceTexts.joined(separator: "\n")
        if usesCamera && !resourceText.contains("NSCameraUsageDescription") {
            issues.append(.cameraPurposeStringNotRepresented)
        }

        return .init(issues: Array(Set(issues)).sorted { $0.rawValue < $1.rawValue })
    }
}
