import Foundation
import XCTest

final class Lane2ManagedArtifactCompatibilityCensusPathAuthorityTests: XCTestCase {
    func testSymlinkedCensusDirectoryCannotWriteExternalState() throws {
        let root = try makeRoot(prefix: "census-root")
        let external = try makeRoot(prefix: "census-external")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: external)
        }

        let v1 = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: v1, withIntermediateDirectories: true)
        let censusDirectory = v1.appendingPathComponent("Census", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: censusDirectory,
            withDestinationURL: external
        )
        let externalState = external.appendingPathComponent("state.json", isDirectory: false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: externalState.path))

        let census = Lane2ManagedArtifactCompatibilityCensus(rootURL: root)
        XCTAssertThrowsError(try census.advance(registrationLimit: 1)) { error in
            XCTAssertEqual(error as? Lane2ManagedArtifactCensusFailure, .corruptState)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: externalState.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: censusDirectory.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    func testDanglingStateSymlinkCannotBeReplacedByCensusCheckpoint() throws {
        let root = try makeRoot(prefix: "state-root")
        defer { try? FileManager.default.removeItem(at: root) }

        let censusDirectory = root.appendingPathComponent(
            ".LibraryRecovery/ArtifactInventory/v1/Census",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: censusDirectory,
            withIntermediateDirectories: true
        )
        let state = censusDirectory.appendingPathComponent("state.json", isDirectory: false)
        let missing = root.appendingPathComponent("outside-missing-state.json", isDirectory: false)
        try FileManager.default.createSymbolicLink(at: state, withDestinationURL: missing)

        let census = Lane2ManagedArtifactCompatibilityCensus(rootURL: root)
        XCTAssertThrowsError(try census.advance(registrationLimit: 1)) { error in
            XCTAssertEqual(error as? Lane2ManagedArtifactCensusFailure, .corruptState)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: state.path)
        XCTAssertEqual(attributes[.type] as? FileAttributeType, .typeSymbolicLink)
    }

    private func makeRoot(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2CensusAuthority-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
