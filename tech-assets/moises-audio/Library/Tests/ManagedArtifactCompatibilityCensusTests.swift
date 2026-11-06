import Foundation
import XCTest

final class Lane2ManagedArtifactCompatibilityCensusTests: XCTestCase {
    func testStableUpgradeRequiresTwoCompleteGenerationsBeforeAuthority() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeSeries(count: 5, root: root)

        var reports: [Lane2ManagedArtifactCensusReport] = []
        while !Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker,
              reports.count < 10 {
            reports.append(
                try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
                    registrationLimit: 2
                )
            )
        }

        XCTAssertEqual(reports.count, 6)
        XCTAssertTrue(reports[2].generationCompleted)
        XCTAssertFalse(reports[2].authorityPromoted)
        XCTAssertEqual(reports[2].generation, 1)
        XCTAssertTrue(reports[5].generationCompleted)
        XCTAssertTrue(reports[5].verificationMatchedPrevious)
        XCTAssertTrue(reports[5].authorityPromoted)
        XCTAssertEqual(reports[5].generation, 2)
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    func testProcessRecreationResumesFromDurableCheckpoint() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeSeries(count: 7, root: root)

        let first = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 3
        )
        XCTAssertEqual(first.registeredThisPass, 3)
        XCTAssertFalse(first.generationCompleted)
        let firstCursor = try XCTUnwrap(first.nextRelativePath)

        // Recreate the census value to model a process relaunch. State lives on disk.
        let second = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 3
        )
        XCTAssertEqual(second.registeredThisPass, 3)
        XCTAssertFalse(second.generationCompleted)
        XCTAssertGreaterThan(try XCTUnwrap(second.nextRelativePath), firstCursor)

        var passes = 2
        while !Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker,
              passes < 10 {
            _ = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
                registrationLimit: 3
            )
            passes += 1
        }
        XCTAssertEqual(passes, 6)
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    func testMutationBetweenCompleteGenerationsPreventsPrematureAuthority() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Imports/100-a.m4a", root: root, bytes: "a")
        try write("Stems/100-b.m4a", root: root, bytes: "b")
        try write("Exports/100-c.m4a", root: root, bytes: "c")

        _ = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(registrationLimit: 2)
        let firstComplete = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 2
        )
        XCTAssertTrue(firstComplete.generationCompleted)
        XCTAssertFalse(firstComplete.authorityPromoted)

        // Insert a lexically earlier path after generation 1. Generation 2 must see a new digest.
        try write("Imports/000-new.m4a", root: root, bytes: "new")
        _ = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(registrationLimit: 2)
        let changedComplete = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 2
        )
        XCTAssertTrue(changedComplete.generationCompleted)
        XCTAssertFalse(changedComplete.verificationMatchedPrevious)
        XCTAssertFalse(changedComplete.authorityPromoted)
        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)

        _ = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(registrationLimit: 2)
        let stableComplete = try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(
            registrationLimit: 2
        )
        XCTAssertTrue(stableComplete.authorityPromoted)
        XCTAssertTrue(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    func testSymlinkFailsClosedWithoutAuthority() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside.m4a")
        try Data("outside".utf8).write(to: outside)
        let link = root.appendingPathComponent("Imports/link.m4a")
        try FileManager.default.createDirectory(
            at: link.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        XCTAssertThrowsError(
            try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance(registrationLimit: 8)
        ) { error in
            guard case Lane2ManagedArtifactCensusFailure.symlinkEncountered = error else {
                return XCTFail("unexpected error: \(error)")
            }
        }
        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    func testCorruptStateFailsClosedWithoutAuthority() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("Imports/a.m4a", root: root, bytes: "a")
        let state = root
            .appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/Census", isDirectory: true)
            .appendingPathComponent("state.json")
        try FileManager.default.createDirectory(
            at: state.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: state)

        XCTAssertThrowsError(try Lane2ManagedArtifactCompatibilityCensus(rootURL: root).advance()) { error in
            XCTAssertEqual(error as? Lane2ManagedArtifactCensusFailure, .corruptState)
        }
        XCTAssertFalse(Lane2ManagedArtifactInventory(rootURL: root).hasValidAuthoritativeMarker)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2AW30Tests-" + UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func writeSeries(count: Int, root: URL) throws {
        for index in 0..<count {
            let managedRoot = index.isMultiple(of: 3) ? "Stems" : "Imports"
            try write(
                "\(managedRoot)/artifact-\(String(format: "%03d", index)).m4a",
                root: root,
                bytes: "\(index)"
            )
        }
    }

    private func write(_ relativePath: String, root: URL, bytes: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(bytes.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1_000_000)],
            ofItemAtPath: url.path
        )
    }
}
