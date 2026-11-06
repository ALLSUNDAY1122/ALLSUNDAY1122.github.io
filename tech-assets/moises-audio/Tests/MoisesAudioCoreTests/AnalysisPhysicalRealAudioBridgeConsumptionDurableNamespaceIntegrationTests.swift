import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionDurableNamespaceIntegrationTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w54-durable-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRemoveDurablyRejectsDanglingSymlinkInsteadOfTreatingItAsMissing() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("pending.json")
        try FileManager.default.createSymbolicLink(
            at: link,
            withDestinationURL: root.appendingPathComponent("missing-target")
        )

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(
            link,
            within: root
        )) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError,
                .symbolicLinkRejected
            )
        }
        XCTAssertEqual(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink, true)
    }

    func testRemoveDurablyDeletesRegularFileAndSynchronizesParent() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("pending.json")
        try Data("pending".utf8).write(to: file)
        try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.removeDurably(file, within: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testAtomicReplaceRejectsSymlinkDestinationNoFollow() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside")
        let destination = root.appendingPathComponent("head.json")
        try Data("outside".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: outside)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.replaceAtomically(
            Data("new-head".utf8),
            to: destination,
            within: root,
            maximumBytes: 4096,
            target: .ledgerHead
        )) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError,
                .symbolicLinkRejected
            )
        }
        XCTAssertEqual(try Data(contentsOf: outside), Data("outside".utf8))
    }

    func testExclusiveCreateRejectsDanglingSymlinkCollision() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("record.json")
        try FileManager.default.createSymbolicLink(
            at: destination,
            withDestinationURL: root.appendingPathComponent("missing-record")
        )

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.createExclusive(
            Data("record".utf8),
            at: destination,
            within: root,
            maximumBytes: 4096,
            target: .immutableRecord
        )) { error in
            XCTAssertEqual(
                error as? AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError,
                .symbolicLinkRejected
            )
        }
    }
}
