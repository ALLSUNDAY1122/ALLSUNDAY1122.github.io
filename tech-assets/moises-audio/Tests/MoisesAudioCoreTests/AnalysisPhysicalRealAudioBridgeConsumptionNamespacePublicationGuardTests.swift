import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisPhysicalRealAudioBridgeConsumptionNamespacePublicationGuardTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("w54-publish-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testRenameGuardRejectsDestinationSubstitutionWithoutOverwritingReplacement() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.tmp")
        let destination = root.appendingPathComponent("head.json")
        try Data("new-head".utf8).write(to: source)
        try Data("old-head".utf8).write(to: destination)

        try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.withPinnedDirectory(
            root,
            within: root
        ) { directory in
            let expectedDestination = try XCTUnwrap(
                AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.entryIdentity(
                    name: destination.lastPathComponent,
                    in: directory
                )
            )
            let retained = root.appendingPathComponent("old-head-retained")
            try FileManager.default.moveItem(at: destination, to: retained)
            try Data("attacker-replacement".utf8).write(to: destination)

            XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.renameEntry(
                sourceName: source.lastPathComponent,
                destinationName: destination.lastPathComponent,
                expectedDestinationIdentity: expectedDestination,
                in: directory
            )) { error in
                XCTAssertEqual(
                    error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                    .entryIdentityChanged
                )
            }
            XCTAssertEqual(try Data(contentsOf: source), Data("new-head".utf8))
            XCTAssertEqual(try Data(contentsOf: destination), Data("attacker-replacement".utf8))
        }
    }

    func testExclusiveLinkGuardRefusesPreexistingDestination() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("record-temp")
        let destination = root.appendingPathComponent("record.json")
        try Data("record".utf8).write(to: source)
        try Data("occupied".utf8).write(to: destination)

        try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.withPinnedDirectory(
            root,
            within: root
        ) { directory in
            XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.linkEntryExclusive(
                sourceName: source.lastPathComponent,
                destinationName: destination.lastPathComponent,
                in: directory
            )) { error in
                XCTAssertEqual(
                    error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError,
                    .entryIdentityChanged
                )
            }
            XCTAssertEqual(try Data(contentsOf: destination), Data("occupied".utf8))
        }
    }

    func testPinnedTraversalRejectsIntermediateSymlinkDirectory() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let actual = root.appendingPathComponent("actual", isDirectory: true)
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: actual)
        let nested = link.appendingPathComponent("child", isDirectory: true)

        XCTAssertThrowsError(try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.openPinnedDirectory(
            nested,
            within: root
        )) { error in
            guard let namespaceError = error as? AnalysisPhysicalRealAudioBridgeConsumptionNamespaceError else {
                return XCTFail("unexpected error: \(error)")
            }
            switch namespaceError {
            case .directoryOpenFailed, .unsafeDirectory:
                break
            default:
                XCTFail("unexpected namespace error: \(namespaceError)")
            }
        }
    }
}
