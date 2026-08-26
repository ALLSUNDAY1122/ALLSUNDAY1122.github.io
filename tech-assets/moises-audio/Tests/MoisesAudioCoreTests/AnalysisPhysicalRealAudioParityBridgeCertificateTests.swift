import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioParityBridgeCertificateTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func certificate(
        physicalSessionID: String = "physical-session-w48",
        declaredRoot: String
    ) -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        .init(
            bridgeID: "bridge-w48",
            expectationRootSHA256: sha("1"),
            w47PackageRootSHA256: sha("2"),
            w47PackageBytesSHA256: sha("3"),
            manifestID: "manifest-w48",
            manifestSHA256: sha("4"),
            runtimeBindingSHA256: sha("5"),
            physicalSessionID: physicalSessionID,
            auditedProjectReportSHA256: sha("6"),
            w46BindingSHA256: sha("7"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: sha("8"),
            limitations: AnalysisPhysicalRealAudioParityBridge.limitations,
            declaredCertificateRootSHA256: declaredRoot
        )
    }

    func testCertificateRootRecomputesAndValidates() throws {
        let provisional = certificate(declaredRoot: sha("0"))
        let root = try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(provisional)
        let final = certificate(declaredRoot: root)

        XCTAssertEqual(try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(final), root)
        XCTAssertTrue(AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(final))
    }

    func testCertificateMutationCannotReuseOldDeclaredRoot() throws {
        let provisional = certificate(declaredRoot: sha("0"))
        let root = try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(provisional)
        let original = certificate(declaredRoot: root)
        let tampered = certificate(physicalSessionID: "substituted-session", declaredRoot: root)

        XCTAssertTrue(AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(original))
        XCTAssertFalse(AnalysisPhysicalRealAudioParityBridgeCertificateValidator.validate(tampered))
    }
}
