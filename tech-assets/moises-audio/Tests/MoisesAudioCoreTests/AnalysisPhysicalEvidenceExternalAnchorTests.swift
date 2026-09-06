import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalEvidenceExternalAnchorTests: XCTestCase {
    private let publicationID = "batch-w42"
    private let transferID = "transfer-w42"
    private let anchorID = "hq-anchor-w42"

    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private var runs: [AnalysisPhysicalEvidenceBatchRunSummary] {
        [
            .init(runID: "run-a", workloadExecutionID: "exec-a", w39BundleRootSHA256: sha("a")),
            .init(runID: "run-b", workloadExecutionID: "exec-b", w39BundleRootSHA256: sha("b"))
        ]
    }

    private func anchor(
        sequence: UInt64 = 2,
        transferID: String? = nil,
        w27: String? = nil,
        w38: String? = nil,
        w40: String? = nil,
        w41: String? = nil,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary]? = nil,
        predecessor: String? = nil
    ) -> AnalysisPhysicalEvidenceExternalRootAnchor {
        .init(
            anchorID: anchorID,
            anchorSequence: sequence,
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W42-ROOT-ANCHOR",
            publicationID: publicationID,
            transferID: transferID ?? self.transferID,
            w27RootSHA256: w27 ?? sha("c"),
            w38RootSHA256: w38 ?? sha("d"),
            w40RootSHA256: w40 ?? sha("e"),
            w41RootSHA256: w41 ?? sha("f"),
            runs: runs ?? self.runs,
            predecessorAnchorReceiptRootSHA256: predecessor
        )
    }

    private func manifest(
        transferID: String? = nil,
        w27: String? = nil,
        w38: String? = nil,
        w40: String? = nil,
        w41: String? = nil,
        runs: [AnalysisPhysicalEvidenceBatchRunSummary]? = nil
    ) -> AnalysisPhysicalEvidenceTransferManifest {
        .init(
            transferID: transferID ?? self.transferID,
            publicationID: publicationID,
            w40RootSHA256: w40 ?? sha("e"),
            w27RootSHA256: w27 ?? sha("c"),
            w38RootSHA256: w38 ?? sha("d"),
            runs: runs ?? self.runs,
            items: [],
            declaredTransferRootSHA256: w41 ?? sha("f")
        )
    }

    private func expectation(
        for receipt: AnalysisPhysicalEvidenceAnchorReceipt,
        minimumSequence: UInt64? = nil,
        receiptRoot: String? = nil,
        predecessor: String? = nil
    ) -> AnalysisPhysicalEvidenceAnchorExpectation {
        .init(
            expectedAnchorID: anchorID,
            minimumAnchorSequence: minimumSequence ?? receipt.anchor.anchorSequence,
            expectedAnchorReceiptRootSHA256: receiptRoot ?? receipt.declaredAnchorReceiptRootSHA256,
            expectedPublicationID: publicationID,
            expectedTransferID: transferID,
            expectedPredecessorAnchorReceiptRootSHA256: predecessor
        )
    }

    func testExternalReceiptAndDestinationCertificateAreDeterministic() throws {
        let value = anchor()
        let receiptA = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: value)
        let receiptB = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: value)
        XCTAssertEqual(receiptA, receiptB)

        let expected = expectation(for: receiptA)
        let certificateA = try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
            manifest(), anchorReceipt: receiptA, expectation: expected
        )
        let certificateB = try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
            manifest(), anchorReceipt: receiptA, expectation: expected
        )
        XCTAssertEqual(certificateA, certificateB)
        XCTAssertEqual(certificateA.status, .verifiedAgainstExternalAnchorNonParity)
        XCTAssertEqual(certificateA.expectedW41RootSHA256, sha("f"))
        XCTAssertEqual(certificateA.destinationW41RootSHA256, sha("f"))
        XCTAssertEqual(
            try AnalysisPhysicalEvidenceDestinationCertificateRoot.compute(certificateA),
            certificateA.declaredCertificateRootSHA256
        )
        XCTAssertEqual(
            try AnalysisPhysicalEvidenceDestinationCertificateCodec.decode(
                AnalysisPhysicalEvidenceDestinationCertificateCodec.encode(certificateA)
            ),
            certificateA
        )
    }

    func testOlderReceiptIsRejectedByMinimumSequence() throws {
        let oldReceipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 2))
        let expected = expectation(for: oldReceipt, minimumSequence: 3)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(), anchorReceipt: oldReceipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .staleAnchorSequence)
        }
    }

    func testPinnedReceiptRootRejectsStaleReceiptEvenAtAllowedSequence() throws {
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 3))
        let expected = expectation(for: receipt, minimumSequence: 3, receiptRoot: sha("9"))
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(), anchorReceipt: receipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .staleAnchorReceipt)
        }
    }

    func testSameTransferIDOldInternallyValidRootSetCannotReplayAgainstCurrentAnchor() throws {
        let currentReceipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 4))
        let expected = expectation(for: currentReceipt, minimumSequence: 4)
        let oldPackage = manifest(w41: sha("8"))
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                oldPackage, anchorReceipt: currentReceipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .rootSetMismatch)
        }
    }

    func testDifferentTransferIDReplayIsRejectedBeforeRootAcceptance() throws {
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 4))
        let expected = expectation(for: receipt, minimumSequence: 4)
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(transferID: "transfer-old"), anchorReceipt: receipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .transferIdentityMismatch)
        }
    }

    func testMixedRootSetIsRejected() throws {
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 5))
        let expected = expectation(for: receipt, minimumSequence: 5)
        let mixed = manifest(w27: sha("7"), w38: sha("d"), w40: sha("e"), w41: sha("f"))
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                mixed, anchorReceipt: receipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .rootSetMismatch)
        }
    }

    func testRunInventoryAndExecutionSubstitutionAreRejected() throws {
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 6))
        let expected = expectation(for: receipt, minimumSequence: 6)
        let substitutedRuns = [
            AnalysisPhysicalEvidenceBatchRunSummary(
                runID: "run-a",
                workloadExecutionID: "exec-other",
                w39BundleRootSHA256: sha("a")
            ),
            runs[1]
        ]
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(runs: substitutedRuns), anchorReceipt: receipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .runInventoryMismatch)
        }
    }

    func testPredecessorReceiptChainMismatchFailsClosed() throws {
        let receipt = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(
            anchor: anchor(sequence: 7, predecessor: sha("1"))
        )
        let expected = expectation(for: receipt, minimumSequence: 7, predecessor: sha("2"))
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(), anchorReceipt: receipt, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .predecessorAnchorMismatch)
        }
    }

    func testReceiptWithForgedDeclaredRootFailsBeforeDestinationComparison() throws {
        let valid = try AnalysisPhysicalEvidenceAnchorReceiptIssuer.issue(anchor: anchor(sequence: 8))
        let forged = AnalysisPhysicalEvidenceAnchorReceipt(
            anchor: valid.anchor,
            declaredAnchorReceiptRootSHA256: sha("0")
        )
        let expected = AnalysisPhysicalEvidenceAnchorExpectation(
            expectedAnchorID: anchorID,
            minimumAnchorSequence: 8,
            expectedAnchorReceiptRootSHA256: sha("0"),
            expectedPublicationID: publicationID,
            expectedTransferID: transferID,
            expectedPredecessorAnchorReceiptRootSHA256: nil
        )
        XCTAssertThrowsError(
            try AnalysisPhysicalEvidenceDestinationAnchorVerifier.verifyAlreadyValidatedTransfer(
                manifest(), anchorReceipt: forged, expectation: expected
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisPhysicalEvidenceExternalAnchorError, .anchorReceiptRootMismatch)
        }
    }
}
