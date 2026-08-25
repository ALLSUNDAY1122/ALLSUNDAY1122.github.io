import Foundation
import Testing

@Test func segmentedBridgePersistsTraversalOnlyAfterExplicitCommit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root.appendingPathComponent("Imports", isDirectory: true), withIntermediateDirectories: true)
    let file = root.appendingPathComponent("Imports/a.wav")
    try Data([1,2,3]).write(to: file)

    let bridge = Lane2ManagedArtifactInventorySegmentedBridge(rootURL: root)
    try bridge.registerManaged(relativePaths: ["Imports/a.wav"])
    let first = try bridge.prepareOrphanCandidateSlice(gracePeriod: 0, candidateLimit: 1, shardVisitLimit: 256)
    let beforeCommit = try bridge.prepareOrphanCandidateSlice(gracePeriod: 0, candidateLimit: 1, shardVisitLimit: 256)
    #expect(first.priorTraversal == beforeCommit.priorTraversal)
    try bridge.persistTraversal(after: first)
    let afterCommit = try bridge.prepareOrphanCandidateSlice(gracePeriod: 0, candidateLimit: 1, shardVisitLimit: 256)
    #expect(afterCommit.priorTraversal == first.nextTraversal)
}

@Test func segmentedBridgeRejectsStaleSliceCommit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let bridge = Lane2ManagedArtifactInventorySegmentedBridge(rootURL: root)
    let first = try bridge.prepareOrphanCandidateSlice(candidateLimit: 1, shardVisitLimit: 1)
    try bridge.persistTraversal(after: first)
    #expect(throws: Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor) {
        try bridge.persistTraversal(after: first)
    }
}

@Test func segmentedBridgeResetRecoversCorruptCursor() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let cursor = root.appendingPathComponent(".LibraryRecovery/ArtifactInventory/v1/cursor.json")
    try FileManager.default.createDirectory(at: cursor.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("bad".utf8).write(to: cursor)
    let bridge = Lane2ManagedArtifactInventorySegmentedBridge(rootURL: root)
    #expect(throws: Lane2ManagedArtifactInventoryFailure.corruptTraversalCursor) {
        _ = try bridge.prepareOrphanCandidateSlice()
    }
    try bridge.resetTraversalForRecovery()
    let recovered = try bridge.prepareOrphanCandidateSlice()
    #expect(recovered.priorTraversal == Lane2ManagedArtifactInventoryTraversal(shardIndex: 0))
}
