import Foundation
import XCTest

final class MeshProjectArchiveIndependenceTests: XCTestCase {
    func testArchivedFilesRemainStableAfterWorkingFilesAreMutatedInPlace() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let workingProject = root
            .appendingPathComponent("mesh-archive-independence")
            .appendingPathExtension(MeshProjectStore.projectExtension)
        let textureDirectory = workingProject.appendingPathComponent("textures", isDirectory: true)
        try FileManager.default.createDirectory(at: textureDirectory, withIntermediateDirectories: true)

        let resultURL = workingProject.appendingPathComponent("mesh.obj")
        let textureURL = textureDirectory.appendingPathComponent("albedo.bin")
        let originalResult = Data(repeating: 0x11, count: 4096)
        let originalTexture = Data(repeating: 0x22, count: 2048)
        try originalResult.write(to: resultURL)
        try originalTexture.write(to: textureURL)

        let store = MeshProjectStore(appRootURL: root)
        let archived = try store.archiveFinishedProject(resultURL: resultURL)
        let archivedTexture = archived.projectURL
            .appendingPathComponent("textures", isDirectory: true)
            .appendingPathComponent("albedo.bin")

        XCTAssertEqual(try Data(contentsOf: archived.resultURL), originalResult)
        XCTAssertEqual(try Data(contentsOf: archivedTexture), originalTexture)

        let replacementResult = Data(repeating: 0xA1, count: originalResult.count)
        let replacementTexture = Data(repeating: 0xB2, count: originalTexture.count)
        try overwriteInPlace(replacementResult, at: resultURL)
        try overwriteInPlace(replacementTexture, at: textureURL)

        XCTAssertEqual(try Data(contentsOf: resultURL), replacementResult)
        XCTAssertEqual(try Data(contentsOf: textureURL), replacementTexture)
        XCTAssertEqual(
            try Data(contentsOf: archived.resultURL),
            originalResult,
            "Mutating the working result must not mutate the archived library copy."
        )
        XCTAssertEqual(
            try Data(contentsOf: archivedTexture),
            originalTexture,
            "Mutating a working sidecar must not mutate the archived library copy."
        )
    }

    private func overwriteInPlace(_ data: Data, at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: data)
        try handle.truncate(atOffset: UInt64(data.count))
        try handle.synchronize()
    }
}
