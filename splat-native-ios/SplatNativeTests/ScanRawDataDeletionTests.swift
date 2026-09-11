import Foundation
import XCTest

final class ScanRawDataDeletionTests: XCTestCase {
    func testClearRawDataFailureDoesNotClaimRawWasDeleted() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent("ScanRawDataDeletionTests-\(UUID().uuidString)", isDirectory: true)
        let store = ScanProjectStore(rootURL: rootURL)
        let created = try store.createProject(title: "raw deletion failure")
        let projectURL = created.0
        let rawURL = projectURL.appendingPathComponent("transforms.json")
        try Data("raw".utf8).write(to: rawURL, options: .atomic)

        defer {
            try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: projectURL.path)
            try? fileManager.removeItem(at: rootURL)
        }

        try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: projectURL.path)
        XCTAssertThrowsError(try store.clearRawData(projectURL: projectURL))
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: projectURL.path)

        let manifest = try store.loadManifest(projectURL: projectURL)
        XCTAssertTrue(manifest.rawDataRetained)
        XCTAssertTrue(fileManager.fileExists(atPath: rawURL.path))
    }
}
