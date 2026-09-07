import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTests: XCTestCase {
    private func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w53-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func custody() -> AnalysisPhysicalRealAudioBridgeConsumptionCustody {
        .init(
            authority: "HQ_LATE_INTEGRATION",
            approvalReference: "HQ-W53-CUSTODY",
            custodyID: "custody-w53"
        )
    }

    private func certificate() throws -> AnalysisPhysicalRealAudioParityBridgeCertificate {
        let provisional = AnalysisPhysicalRealAudioParityBridgeCertificate(
            bridgeID: "bridge-w53",
            expectationRootSHA256: sha("c"),
            w47PackageRootSHA256: sha("a"),
            w47PackageBytesSHA256: sha("4"),
            manifestID: "manifest-w53",
            manifestSHA256: sha("5"),
            runtimeBindingSHA256: sha("6"),
            physicalSessionID: "session-w53",
            auditedProjectReportSHA256: sha("7"),
            w46BindingSHA256: sha("8"),
            w46AdjudicationStatus: .notReadyForHQJudgment,
            w46AdjudicationReportRootSHA256: sha("b"),
            limitations: AnalysisPhysicalRealAudioParityBridge.limitations,
            declaredCertificateRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioParityBridgeCertificateValidator.certificateSHA256(provisional)
        return .init(
            bridgeID: provisional.bridgeID,
            expectationRootSHA256: provisional.expectationRootSHA256,
            w47PackageRootSHA256: provisional.w47PackageRootSHA256,
            w47PackageBytesSHA256: provisional.w47PackageBytesSHA256,
            manifestID: provisional.manifestID,
            manifestSHA256: provisional.manifestSHA256,
            runtimeBindingSHA256: provisional.runtimeBindingSHA256,
            physicalSessionID: provisional.physicalSessionID,
            auditedProjectReportSHA256: provisional.auditedProjectReportSHA256,
            w46BindingSHA256: provisional.w46BindingSHA256,
            w46AdjudicationStatus: provisional.w46AdjudicationStatus,
            w46AdjudicationReportRootSHA256: provisional.w46AdjudicationReportRootSHA256,
            limitations: provisional.limitations,
            declaredCertificateRootSHA256: root
        )
    }

    func testDurableAtomicReplaceExclusiveCreateAndDelete() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: root, fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        let pending = ledger.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName)
        let pendingBytes = Data("{\"pending\":true}".utf8)
        let pendingReceipt = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.replaceAtomically(
            pendingBytes,
            to: pending,
            within: ledger,
            maximumBytes: 4096,
            target: .pendingMarker
        )
        XCTAssertEqual(pendingReceipt.byteCount, pendingBytes.count)
        XCTAssertTrue(pendingReceipt.atomicPublish)
        XCTAssertTrue(pendingReceipt.parentDirectorySynced)
        XCTAssertEqual(try Data(contentsOf: pending), pendingBytes)

        let record = ledger.appendingPathComponent("records/record-w53.json")
        let recordBytes = Data("{\"record\":true}".utf8)
        let recordReceipt = try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.createExclusive(
            recordBytes,
            at: record,
            within: ledger,
            maximumBytes: 4096,
            target: .immutableRecord
        )
        XCTAssertEqual(recordReceipt.target, .immutableRecord)
        XCTAssertTrue(recordReceipt.atomicPublish)
        XCTAssertTrue(recordReceipt.parentDirectorySynced)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.createExclusive(
            recordBytes,
            at: record,
            within: ledger,
            maximumBytes: 4096,
            target: .immutableRecord
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError, .targetCollision)
        }

        try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(pending, within: ledger)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.path))
    }

    func testAllTwelvePublicationFaultBoundariesRecoverOnlyToContractedState() throws {
        let targets: [AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget] = [
            .pendingMarker, .immutableRecord, .ledgerHead
        ]
        let points: [AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint] = [
            .beforeDataSync,
            .afterDataSyncBeforePublish,
            .afterPublishBeforeDirectorySync,
            .afterDirectorySync
        ]
        let expectedCertificateRoot = try certificate().declaredCertificateRootSHA256

        for target in targets {
            for point in points {
                let root = try root()
                defer { try? FileManager.default.removeItem(at: root) }
                let injection = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationInjectedFault(
                    target: target,
                    point: point
                )
                XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.appendDurabilityForTesting(
                    ledgerID: "ledger",
                    certificate: certificate(),
                    custody: custody(),
                    rootURL: root,
                    durablePublicationFault: injection
                )) { error in
                    XCTAssertEqual(
                        error as? AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError,
                        .injectedFault(injection),
                        "target=\(target) point=\(point)"
                    )
                }

                _ = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.recoverIfNeeded(
                    ledgerID: "ledger", rootURL: root
                )
                let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.loadValidatedHead(
                    ledgerID: "ledger", rootURL: root
                )
                let expectedCommitted: Bool
                switch target {
                case .pendingMarker:
                    expectedCommitted = false
                case .immutableRecord:
                    expectedCommitted = point == .afterPublishBeforeDirectorySync || point == .afterDirectorySync
                case .ledgerHead:
                    expectedCommitted = true
                }
                XCTAssertEqual(head != nil, expectedCommitted, "target=\(target) point=\(point)")
                if expectedCommitted {
                    XCTAssertEqual(head?.latestSequence, 1)
                    XCTAssertEqual(head?.records.last?.bridgeCertificateRootSHA256, expectedCertificateRoot)
                }
            }
        }
    }

    func testInterruptedTemporaryFilesAreBoundedIgnoredMetadataNotLedgerRecords() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: root, fileManager: .default
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        let records = ledger.appendingPathComponent("records", isDirectory: true)
        let name = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporaryPrefix
            + "interrupted" + AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporarySuffix
        try Data("partial".utf8).write(to: records.appendingPathComponent(name))
        XCTAssertEqual(
            try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.recordDirectoryNames(
                recordsURL: records, ledgerURL: ledger, fileManager: .default
            ),
            []
        )
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateLedgerTopology(
            ledgerURL: ledger, rootURL: root, fileManager: .default
        )
    }

    func testTooManyInterruptedTempsAndSymlinkTempFailClosed() throws {
        let rootA = try root()
        defer { try? FileManager.default.removeItem(at: rootA) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: rootA, fileManager: .default
        )
        let ledgerA = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: rootA
        )
        for index in 0...AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.maximumInterruptedTemporaryFilesPerDirectory {
            let name = AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporaryPrefix
                + "\(index)" + AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporarySuffix
            try Data("x".utf8).write(to: ledgerA.appendingPathComponent(name))
        }
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateLedgerTopology(
            ledgerURL: ledgerA, rootURL: rootA, fileManager: .default
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .unsafeFilesystemTopology)
        }

        let rootB = try root()
        defer { try? FileManager.default.removeItem(at: rootB) }
        try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ensureDirectories(
            ledgerID: "ledger", rootURL: rootB, fileManager: .default
        )
        let ledgerB = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: rootB
        )
        let outside = rootB.appendingPathComponent("outside-temp")
        try Data("x".utf8).write(to: outside)
        let temp = ledgerB.appendingPathComponent(
            AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporaryPrefix
                + "symlink" + AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.temporarySuffix
        )
        try FileManager.default.createSymbolicLink(at: temp, withDestinationURL: outside)
        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.validateLedgerTopology(
            ledgerURL: ledgerB, rootURL: rootB, fileManager: .default
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError, .symbolicLinkRejected)
        }
    }

    func testNormalW53AppendRemainsLegacyW49HeadCompatibleAndLeavesNoPendingMarker() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let head = try AnalysisPhysicalRealAudioBridgeConsumptionSecureStore.append(
            ledgerID: "ledger",
            certificate: certificate(),
            custody: custody(),
            rootURL: root
        )
        XCTAssertEqual(
            try AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.loadValidatedHead(
                ledgerID: "ledger", rootURL: root
            ),
            head
        )
        let ledger = AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.ledgerURL(
            ledgerID: "ledger", rootURL: root
        )
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: ledger.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionLedgerStore.pendingFileName).path
        ))
    }

    func testPhysicalProbeRecoveredStateContractCoversEveryBoundary() {
        let targets: [AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationTarget] = [
            .pendingMarker, .immutableRecord, .ledgerHead
        ]
        let points: [AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationFaultPoint] = [
            .beforeDataSync,
            .afterDataSyncBeforePublish,
            .afterPublishBeforeDirectorySync,
            .afterDirectorySync
        ]
        var observed: [AnalysisPhysicalRealAudioBridgeDurabilityRecoveredState] = []
        for target in targets {
            for point in points {
                observed.append(AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.expectedRecoveredState(
                    target: target,
                    faultPoint: point
                ))
            }
        }
        XCTAssertEqual(observed.count, 12)
        XCTAssertEqual(observed.filter { $0 == .exactPreOrPost }.count, 1)
        XCTAssertEqual(
            AnalysisPhysicalRealAudioBridgeDurabilityProbeContract.expectedRecoveredState(
                target: .immutableRecord,
                faultPoint: .afterPublishBeforeDirectorySync
            ),
            .exactPreOrPost
        )
    }
}
