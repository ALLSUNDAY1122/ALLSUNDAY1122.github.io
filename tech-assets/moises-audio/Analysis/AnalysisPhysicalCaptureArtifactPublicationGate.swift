import Foundation

public enum AnalysisPhysicalCaptureArtifactPublicationGate {
    public static func publishValidated(
        bundle: AnalysisPhysicalCaptureArtifactBundle,
        archiveRootURL: URL,
        fileManager: FileManager = .default
    ) throws -> AnalysisPhysicalCaptureArtifactPublicationReceipt {
        let validation = AnalysisPhysicalCaptureArtifactBundleValidator.validate(bundle)
        guard validation.valid else {
            throw AnalysisPhysicalCaptureArtifactStagingError.invalidBundle
        }
        return try AnalysisPhysicalCaptureArtifactStager.publish(
            bundle: bundle,
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )
    }
}
