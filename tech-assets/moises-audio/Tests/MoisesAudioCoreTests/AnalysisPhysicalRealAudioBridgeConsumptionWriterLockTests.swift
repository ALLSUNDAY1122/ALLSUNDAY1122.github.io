import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionWriterLockTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w51-lock-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testSymlinkedWriterLockDirectoryIsRejected() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let bridge = root.appendingPathComponent("w49-bridge-consumption", isDirectory: true)
        let target = root.appendingPathComponent("lock-target", isDirectory: true)
        try FileManager.default.createDirectory(at: bridge, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: bridge.appendingPathComponent(AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.lockDirectoryName),
            withDestinationURL: target
        )

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )) { error in
            XCTAssertEqual(error as? AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError, .unsafeLockDirectory)
        }
    }

    func testPreexistingSymlinkLockFileCannotBeFollowed() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let lockURL = AnalysisPhysicalRealAudioBridgeConsumptionWriterLock.lockURL(
            ledgerID: "ledger", rootURL: root
        )
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let outside = root.appendingPathComponent("outside-lock.txt")
        try Data("outside\n".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: lockURL, withDestinationURL: outside)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionConcurrentStore.observeAppendCAS(
            ledgerID: "ledger", rootURL: root
        )) { error in
            guard let lockError = error as? AnalysisPhysicalRealAudioBridgeConsumptionWriterLockError,
                  case .lockOpenFailed = lockError else {
                return XCTFail("expected O_NOFOLLOW lockOpenFailed, got \(error)")
            }
        }
    }
}
