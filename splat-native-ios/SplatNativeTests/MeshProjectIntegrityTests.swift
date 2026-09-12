import XCTest

final class MeshProjectIntegrityTests: XCTestCase {
    func testSealedArchiveSurvivesWorkingProjectDeletion() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x31)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))

        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName).path
        ))

        try FileManager.default.removeItem(at: live)
        let relaunched = try XCTUnwrap(MeshProjectStore(appRootURL: root).listProjects().first)
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: relaunched), relaunched.resultURL)
    }

    func testFirstSealPublishesVerifiedEvidenceWithoutCandidateResidue() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x32)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))

        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let evidenceURL = archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName)
        let data = try Data(contentsOf: evidenceURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let evidence = try decoder.decode(MeshProjectIntegrity.Evidence.self, from: data)
        XCTAssertEqual(evidence.schemaVersion, MeshProjectIntegrity.Evidence.currentSchemaVersion)
        XCTAssertEqual(evidence.resultFileName, archived.resultURL.lastPathComponent)
        XCTAssertFalse(evidence.sha256.isEmpty)

        let entries = try FileManager.default.contentsOfDirectory(
            at: archived.projectURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        XCTAssertFalse(entries.contains { $0.lastPathComponent.contains(".mesh-result.sha256.json.candidate-") })
    }

    func testRejectsSameSizeReplacementAfterSealEvenWhenMtimeRestored() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x41)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let attributes = try FileManager.default.attributesOfItem(atPath: archived.resultURL.path)
        let modificationDate = try XCTUnwrap(attributes[.modificationDate] as? Date)
        try Data(repeating: 0x42, count: 256).write(to: archived.resultURL, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: archived.resultURL.path)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.hashMismatch = error else {
                return XCTFail("Expected hashMismatch, got \(error)")
            }
        }
    }

    func testRejectsSameSizeReplacementBeforeFirstSealWhenMtimeChanges() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x51)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))

        try Data(repeating: 0x52, count: 256).write(to: archived.resultURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(30)],
            ofItemAtPath: archived.resultURL.path
        )

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.resultChangedAfterArchive = error else {
                return XCTFail("Expected resultChangedAfterArchive, got \(error)")
            }
        }
    }

    func testRejectsManifestRetargetBetweenListingAndFirstSeal() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x5A)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))

        let alternate = archived.projectURL.appendingPathComponent("alternate.obj")
        try Data(contentsOf: archived.resultURL).write(to: alternate, options: .atomic)
        let attrs = try FileManager.default.attributesOfItem(atPath: archived.resultURL.path)
        let originalDate = try XCTUnwrap(attrs[.modificationDate] as? Date)
        try FileManager.default.setAttributes([.modificationDate: originalDate], ofItemAtPath: alternate.path)

        let manifestURL = archived.projectURL.appendingPathComponent(MeshProjectStore.libraryManifestFileName)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = try decoder.decode(MeshProjectStore.LibraryManifest.self, from: Data(contentsOf: manifestURL))
        manifest.resultFileName = alternate.lastPathComponent
        manifest.resultByteCount = Int64(try Data(contentsOf: alternate).count)
        manifest.sourceResultModificationDate = originalDate
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.manifestChangedSinceListing = error else {
                return XCTFail("Expected manifestChangedSinceListing, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName).path
        ))
    }

    func testRejectsCorruptExistingEvidenceInsteadOfResealing() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x61)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let evidenceURL = archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName)
        try Data("not-valid-integrity-evidence".utf8).write(to: evidenceURL, options: .atomic)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.evidenceInvalid = error else {
                return XCTFail("Expected evidenceInvalid, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: evidenceURL), Data("not-valid-integrity-evidence".utf8))
    }

    func testRejectsEvidenceFromUnsupportedFutureSchemaWithoutOverwritingIt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x71)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let evidenceURL = archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName)
        let original = try Data(contentsOf: evidenceURL)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        object["schemaVersion"] = 999
        object["futureField"] = "must-survive"
        let futureEvidence = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try futureEvidence.write(to: evidenceURL, options: .atomic)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.evidenceInvalid = error else {
                return XCTFail("Expected evidenceInvalid, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: evidenceURL), futureEvidence)
    }

    func testRejectsOversizedExistingEvidenceWithoutReadingOrReplacingIt() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x72)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let evidenceURL = archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName)
        let oversized = Data(repeating: 0x41, count: 64 * 1024 + 1)
        try oversized.write(to: evidenceURL, options: .atomic)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.evidenceInvalid = error else {
                return XCTFail("Expected evidenceInvalid, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: evidenceURL), oversized)
    }

    func testRejectsSymlinkedEvidenceWithoutFollowingExternalBytes() throws {
        let fileManager = FileManager.default
        let root = try makeRoot()
        let externalRoot = fileManager.temporaryDirectory
            .appendingPathComponent("MeshProjectIntegrityExternal-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: externalRoot, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: externalRoot)
        }
        let store = MeshProjectStore(appRootURL: root)
        let live = try makeLiveProject(in: root, marker: 0x73)
        let archived = try store.archiveFinishedProject(resultURL: live.appendingPathComponent("mesh.obj"))
        XCTAssertEqual(try MeshProjectIntegrity.verifyOrSeal(summary: archived), archived.resultURL)

        let evidenceURL = archived.projectURL.appendingPathComponent(MeshProjectIntegrity.evidenceFileName)
        let validEvidence = try Data(contentsOf: evidenceURL)
        try fileManager.removeItem(at: evidenceURL)
        let external = externalRoot.appendingPathComponent("outside-evidence.json")
        try validEvidence.write(to: external, options: .atomic)
        try fileManager.createSymbolicLink(at: evidenceURL, withDestinationURL: external)

        XCTAssertThrowsError(try MeshProjectIntegrity.verifyOrSeal(summary: archived)) { error in
            guard case MeshProjectIntegrity.IntegrityError.evidenceInvalid = error else {
                return XCTFail("Expected evidenceInvalid, got \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: external), validEvidence)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeshProjectIntegrityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makeLiveProject(in root: URL, marker: UInt8) throws -> URL {
        let project = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("meshproject")
        let images = project.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 64).write(to: images.appendingPathComponent("mesh_00000.jpg"))

        let manifest: [String: Any] = [
            "schemaVersion": 1,
            "captureMode": "lidar",
            "scanSize": "medium",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "frames": [],
            "lidarMeshAvailable": true,
            "texturedModelAvailable": false,
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try manifestData.write(to: project.appendingPathComponent("mesh-project.json"), options: .atomic)

        // Integrity sealing now requires semantically usable geometry, not merely a non-empty file.
        // Keep the fixture exactly 256 bytes so the same-size tamper regressions continue exercising
        // hash/mtime behavior while the baseline itself is a real triangle SceneKit can load.
        var obj = Data("o Mesh\nv 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n#".utf8)
        XCTAssertLessThan(obj.count, 256)
        while obj.count < 255 { obj.append(marker) }
        obj.append(0x0A)
        XCTAssertEqual(obj.count, 256)
        try obj.write(to: project.appendingPathComponent("mesh.obj"), options: .atomic)
        return project
    }
}
