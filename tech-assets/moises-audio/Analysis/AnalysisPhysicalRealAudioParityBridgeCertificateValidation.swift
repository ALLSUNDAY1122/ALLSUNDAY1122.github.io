import Foundation

public enum AnalysisPhysicalRealAudioParityBridgeCertificateValidator {
    private struct RootPayload: Codable {
        let schemaVersion: Int
        let status: AnalysisPhysicalRealAudioParityBridgeCertificateStatus
        let bridgeID: String
        let expectationRootSHA256: String
        let w47PackageRootSHA256: String
        let w47PackageBytesSHA256: String
        let manifestID: String
        let manifestSHA256: String
        let runtimeBindingSHA256: String
        let physicalSessionID: String
        let auditedProjectReportSHA256: String
        let w46BindingSHA256: String
        let w46AdjudicationStatus: AnalysisAnalysisParityAdjudicationStatus
        let w46AdjudicationReportRootSHA256: String
        let limitations: [String]
    }

    public static func certificateSHA256(
        _ certificate: AnalysisPhysicalRealAudioParityBridgeCertificate
    ) throws -> String {
        try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(RootPayload(
            schemaVersion: certificate.schemaVersion,
            status: certificate.status,
            bridgeID: certificate.bridgeID,
            expectationRootSHA256: certificate.expectationRootSHA256,
            w47PackageRootSHA256: certificate.w47PackageRootSHA256,
            w47PackageBytesSHA256: certificate.w47PackageBytesSHA256,
            manifestID: certificate.manifestID,
            manifestSHA256: certificate.manifestSHA256,
            runtimeBindingSHA256: certificate.runtimeBindingSHA256,
            physicalSessionID: certificate.physicalSessionID,
            auditedProjectReportSHA256: certificate.auditedProjectReportSHA256,
            w46BindingSHA256: certificate.w46BindingSHA256,
            w46AdjudicationStatus: certificate.w46AdjudicationStatus,
            w46AdjudicationReportRootSHA256: certificate.w46AdjudicationReportRootSHA256,
            limitations: certificate.limitations
        ))
    }

    public static func validate(
        _ certificate: AnalysisPhysicalRealAudioParityBridgeCertificate,
        expectation: AnalysisPhysicalRealAudioParityBridgeExpectation? = nil,
        adjudicationReport: AnalysisAnalysisParityAdjudicationReport? = nil
    ) -> Bool {
        let hashes = [
            certificate.expectationRootSHA256,
            certificate.w47PackageRootSHA256,
            certificate.w47PackageBytesSHA256,
            certificate.manifestSHA256,
            certificate.runtimeBindingSHA256,
            certificate.auditedProjectReportSHA256,
            certificate.w46BindingSHA256,
            certificate.w46AdjudicationReportRootSHA256,
            certificate.declaredCertificateRootSHA256
        ]
        guard certificate.schemaVersion == 1,
              certificate.status == .nonParityBridgeExecuted,
              !certificate.bridgeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !certificate.manifestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !certificate.physicalSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              certificate.limitations == AnalysisPhysicalRealAudioParityBridge.limitations,
              hashes.allSatisfy(isSHA256),
              let computed = try? certificateSHA256(certificate),
              computed == certificate.declaredCertificateRootSHA256 else {
            return false
        }

        if let expectation {
            guard expectation.schemaVersion == 1,
                  expectation.authority == AnalysisPhysicalRealAudioParityBridge.requiredAuthority,
                  let expectationRoot = try? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(expectation),
                  expectationRoot == certificate.expectationRootSHA256,
                  expectation.bridgeID == certificate.bridgeID,
                  expectation.expectedW47PackageRootSHA256 == certificate.w47PackageRootSHA256,
                  expectation.expectedW47PackageBytesSHA256 == certificate.w47PackageBytesSHA256,
                  expectation.expectedManifestID == certificate.manifestID,
                  expectation.expectedManifestSHA256 == certificate.manifestSHA256,
                  expectation.expectedRuntimeBindingSHA256 == certificate.runtimeBindingSHA256,
                  expectation.expectedPhysicalSessionID == certificate.physicalSessionID,
                  expectation.expectedAuditedProjectReportSHA256 == certificate.auditedProjectReportSHA256,
                  expectation.expectedW46BindingSHA256 == certificate.w46BindingSHA256 else {
                return false
            }
        }

        if let adjudicationReport {
            guard AnalysisAnalysisParityAdjudicationReportValidator.validate(adjudicationReport),
                  adjudicationReport.status == certificate.w46AdjudicationStatus,
                  adjudicationReport.declaredReportRootSHA256 == certificate.w46AdjudicationReportRootSHA256 else {
                return false
            }
        }
        return true
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains(Int($0.value)) || (97...102).contains(Int($0.value))
        }
    }
}
