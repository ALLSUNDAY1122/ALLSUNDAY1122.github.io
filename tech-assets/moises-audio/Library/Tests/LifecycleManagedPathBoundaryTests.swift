import Foundation
import XCTest
#if canImport(MoisesAudioLibrary)
@testable import MoisesAudioLibrary
#endif

final class LifecycleManagedPathBoundaryTests: XCTestCase {
    func testLifecycleDirectorySymlinkFailsClosedWithoutExternalMutation() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-root-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        let lifecycle = root.appendingPathComponent(".LibraryLifecycle", isDirectory: true)
        try fm.createSymbolicLink(at: lifecycle, withDestinationURL: external)
        defer { try? fm.removeItem(at: base) }

        let store = Lane2LifecycleMetadataStore(rootURL: root, fileManager: fm)
        do {
            _ = try await store.snapshot()
            XCTFail("symlink lifecycle authority must fail closed")
        } catch { }
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testUnmarkedV2SymlinkIsNotDiscarded() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-v2-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let lifecycle = root.appendingPathComponent(".LibraryLifecycle", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: lifecycle, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        let sentinel = external.appendingPathComponent("sentinel")
        try Data([1]).write(to: sentinel)
        try fm.createSymbolicLink(
            at: lifecycle.appendingPathComponent("v2", isDirectory: true),
            withDestinationURL: external
        )
        defer { try? fm.removeItem(at: base) }

        let store = Lane2LifecycleMetadataStore(rootURL: root, fileManager: fm)
        do {
            _ = try await store.snapshot()
            XCTFail("unmarked v2 symlink must not be recursively discarded")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([1]))
    }

    func testDanglingSchemaMarkerFailsClosed() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-marker-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let v2 = root.appendingPathComponent(".LibraryLifecycle/v2", isDirectory: true)
        try fm.createDirectory(at: v2, withIntermediateDirectories: true)
        try fm.createSymbolicLink(
            at: v2.appendingPathComponent("schema.json"),
            withDestinationURL: base.appendingPathComponent("missing.json")
        )
        defer { try? fm.removeItem(at: base) }

        let store = Lane2LifecycleMetadataStore(rootURL: root, fileManager: fm)
        do {
            _ = try await store.snapshot()
            XCTFail("dangling schema marker must not be treated as absent")
        } catch { }
    }

    func testProjectShardSymlinkCannotBecomeMetadataAuthority() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-project-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("outside.json")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let store = Lane2LifecycleMetadataStore(rootURL: root, fileManager: fm)
        _ = try await store.snapshot()
        let project = UUID()
        let shard = root.appendingPathComponent(".LibraryLifecycle/v2/projects/\(project.uuidString).json")
        try Data("{}".utf8).write(to: external)
        try fm.createSymbolicLink(at: shard, withDestinationURL: external)

        do {
            _ = try await store.snapshot()
            XCTFail("project shard symlink must fail closed")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: external), Data("{}".utf8))
    }

    func testQuarantineDirectorySymlinkCannotRedirectCorruptBytes() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-quarantine-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        let store = Lane2LifecycleMetadataStore(rootURL: root, fileManager: fm)
        _ = try await store.snapshot()
        let corrupt = root.appendingPathComponent(".LibraryLifecycle/v2/projects/\(UUID().uuidString).json")
        try Data("broken".utf8).write(to: corrupt)
        let quarantine = root.appendingPathComponent(".LibraryLifecycle/Quarantine", isDirectory: true)
        try fm.createSymbolicLink(at: quarantine, withDestinationURL: external)

        do {
            _ = try await store.quarantineCorruptShards()
            XCTFail("quarantine symlink must not redirect preserved metadata")
        } catch { }
        XCTAssertTrue(fm.fileExists(atPath: corrupt.path))
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testRecoveryDirectorySymlinkCannotRedirectBarrierWrite() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-barrier-write-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let lifecycle = root.appendingPathComponent(".LibraryLifecycle", isDirectory: true)
        let external = base.appendingPathComponent("external", isDirectory: true)
        try fm.createDirectory(at: lifecycle, withIntermediateDirectories: true)
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try fm.createSymbolicLink(
            at: lifecycle.appendingPathComponent("Recovery", isDirectory: true),
            withDestinationURL: external
        )
        defer { try? fm.removeItem(at: base) }

        let recovery = Lane2LifecycleQuarantineRecovery(rootURL: root, fileManager: fm)
        do {
            _ = try await recovery.prepareBarrierForLegacyCorruption()
            XCTFail("recovery-directory symlink must fail closed")
        } catch { }
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: external.path).isEmpty)
    }

    func testDanglingBarrierIsCorruptAuthorityNotMissing() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-barrier-read-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let recoveryDirectory = root.appendingPathComponent(".LibraryLifecycle/Recovery", isDirectory: true)
        try fm.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        let barrier = recoveryDirectory.appendingPathComponent("export-metadata-quarantine-barrier.json")
        try fm.createSymbolicLink(at: barrier, withDestinationURL: base.appendingPathComponent("missing.json"))
        defer { try? fm.removeItem(at: base) }

        let recovery = Lane2LifecycleQuarantineRecovery(rootURL: root, fileManager: fm)
        do {
            _ = try await recovery.barrier()
            XCTFail("dangling barrier must fail as corrupt authority")
        } catch { }
    }

    func testRecoveredExportSymlinkIsRejected() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2-AW49-recovered-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root", isDirectory: true)
        let exports = root.appendingPathComponent("Exports", isDirectory: true)
        let external = base.appendingPathComponent("outside.m4a")
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: external)
        let managed = exports.appendingPathComponent("mix.m4a")
        try fm.createSymbolicLink(at: managed, withDestinationURL: external)
        defer { try? fm.removeItem(at: base) }

        let recovery = Lane2LifecycleQuarantineRecovery(rootURL: root, fileManager: fm)
        let artifact = Lane2RecoveredExportArtifact(
            projectUUID: UUID(),
            relativePath: "Exports/mix.m4a",
            mediaType: "audio/mp4"
        )
        do {
            try await recovery.requireRecoveredArtifactsReady([artifact])
            XCTFail("recovered artifact symlink must not satisfy readiness")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: external), Data([1, 2, 3]))
    }
}
