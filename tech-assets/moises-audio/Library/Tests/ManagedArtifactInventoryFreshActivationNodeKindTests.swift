import Foundation
import XCTest

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class Lane2ManagedArtifactInventoryFreshActivationNodeKindTests: XCTestCase {
    func testFreshActivationRejectsFIFOWithoutWritingAuthorityMarker() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "L2InventoryFreshActivationFIFO-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: imports, withIntermediateDirectories: true)
        try Data("managed".utf8).write(to: imports.appendingPathComponent("first.m4a"))

        let fifo = imports.appendingPathComponent("unexpected.pipe")
        XCTAssertEqual(lane2CreateFIFO(atPath: fifo.path), 0)

        let inventory = Lane2ManagedArtifactInventory(rootURL: root)
        XCTAssertFalse(
            try inventory.activateForFirstManagedArtifactIfSafe(
                relativePath: "Imports/first.m4a"
            )
        )
        XCTAssertFalse(inventory.isAuthoritative)
    }
}

private func lane2CreateFIFO(atPath path: String) -> Int32 {
    path.withCString { pointer in
#if canImport(Darwin)
        Darwin.mkfifo(pointer, mode_t(0o600))
#elseif canImport(Glibc)
        Glibc.mkfifo(pointer, mode_t(0o600))
#else
        -1
#endif
    }
}
