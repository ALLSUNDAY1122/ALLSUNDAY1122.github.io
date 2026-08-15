import Foundation
import XCTest

final class ScanPersistenceIntegrationTests: XCTestCase {
    func testPendingSplatCommitBecomesTrustedFinishedResult() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = ScanProjectStore(rootURL: root)
        let (projectURL, _) = try store.createProject(title: "Integration", targetFrames: 24)

        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .processing
        }

        let pendingURL = projectURL.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
        try Data(repeating: 0x2A, count: 64).write(to: pendingURL, options: .atomic)

        let committedURL = try store.commitPendingSplat(projectURL: projectURL)
        _ = try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.stage = .finished
            manifest.outputs[ScanRepresentationKind.splat.rawValue] = committedURL.lastPathComponent
        }

        XCTAssertEqual(committedURL.lastPathComponent, ScanProjectStore.splatResultFileName)
        XCTAssertEqual(store.trustedSplatURL(projectURL: projectURL), committedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pendingURL.path))
    }
}
