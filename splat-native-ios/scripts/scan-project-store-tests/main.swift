import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
}

func rawFiles(in project: URL) throws {
    let images = project.appendingPathComponent("images", isDirectory: true)
    try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
    try Data(repeating: 1, count: 8).write(to: images.appendingPathComponent("frame_00000.jpg"))
    try Data("{}".utf8).write(to: project.appendingPathComponent("transforms.json"))
    try Data("ply".utf8).write(to: project.appendingPathComponent("points3D.ply"))
}

func splatData(_ marker: UInt8) -> Data {
    Data(repeating: marker, count: 64)
}

let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("ScanProjectStoreGate-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: root) }

let store = ScanProjectStore(rootURL: root)

// CAPTURING: a persisted checkpoint survives relaunch and primary-checkpoint corruption.
let capturing = try store.createProject(title: "capturing")
let firstCheckpoint = ScanCaptureCheckpoint(
    frames: [],
    featurePoints: [StoredFeaturePoint(id: 1, x: 1, y: 2, z: 3)],
    coverageSectors: [0, 1],
    estimatedTargetCenter: StoredVector3(x: 0, y: 0, z: -1),
    lastAcceptedTransform: nil,
    lastAcceptedTimestamp: 10
)
let secondCheckpoint = ScanCaptureCheckpoint(
    frames: [],
    featurePoints: [StoredFeaturePoint(id: 2, x: 4, y: 5, z: 6)],
    coverageSectors: [0, 1, 2],
    estimatedTargetCenter: StoredVector3(x: 0, y: 0, z: -1),
    lastAcceptedTransform: nil,
    lastAcceptedTimestamp: 20
)
try store.saveCheckpoint(firstCheckpoint, projectURL: capturing.0)
try store.saveCheckpoint(secondCheckpoint, projectURL: capturing.0)
try Data("corrupt".utf8).write(
    to: capturing.0.appendingPathComponent(ScanProjectStore.checkpointFileName),
    options: .atomic
)
let recoveredCheckpoint = try ScanProjectStore(rootURL: root).loadCheckpoint(projectURL: capturing.0)
expect(recoveredCheckpoint.lastAcceptedTimestamp == 10, "checkpoint backup recovery failed")

// CAPTURED: manifest and metadata survive store recreation.
let persistent = try store.createProject(title: "persistent")
try rawFiles(in: persistent.0)
_ = try store.updateManifest(projectURL: persistent.0) { manifest in
    manifest.stage = .captured
    manifest.acceptedFrames = 30
    manifest.featurePointCount = 800
    manifest.coverageSectorCount = 8
}
let relaunched = ScanProjectStore(rootURL: root)
let loaded = try relaunched.loadProject(id: persistent.1.id)
expect(loaded.manifest.acceptedFrames == 30, "manifest did not survive store recreation")
expect(loaded.manifest.stage == .captured, "captured stage did not survive relaunch")

// Primary-manifest corruption recovers from the one-generation backup.
_ = try relaunched.updateManifest(projectURL: persistent.0) { $0.title = "backup-ok" }
_ = try relaunched.updateManifest(projectURL: persistent.0) { $0.acceptedFrames = 31 }
try Data("broken".utf8).write(
    to: persistent.0.appendingPathComponent(ScanProjectStore.manifestFileName),
    options: .atomic
)
let recoveredBackup = try ScanProjectStore(rootURL: root).loadProject(id: persistent.1.id)
expect(recoveredBackup.manifest.title == "backup-ok", "backup manifest recovery failed")

// PROCESSING without a previous result: relaunch returns to captured when raw is intact.
let interrupted = try relaunched.createProject(title: "interrupted")
try rawFiles(in: interrupted.0)
_ = try relaunched.updateManifest(projectURL: interrupted.0) { $0.stage = .processing }
let recoveredProcessing = try ScanProjectStore(rootURL: root).loadProject(id: interrupted.1.id)
expect(recoveredProcessing.manifest.stage == .captured, "processing interruption did not recover to captured")
expect(recoveredProcessing.manifest.recoveredAfterInterruption, "processing recovery flag missing")

// PROCESSING after a first result: direct reprocessing may overwrite result.splat, but the old completed
// result must remain recoverable even if termination happens during that write.
let reprocessCrash = try relaunched.createProject(title: "reprocess-crash")
try rawFiles(in: reprocessCrash.0)
try splatData(0x2A).write(to: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
_ = try relaunched.updateManifest(projectURL: reprocessCrash.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
}
_ = try relaunched.updateManifest(projectURL: reprocessCrash.0) { $0.stage = .processing }
expect(!FileManager.default.fileExists(atPath: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName).path), "old result was not isolated before reprocessing")
expect(FileManager.default.fileExists(atPath: reprocessCrash.0.appendingPathComponent(ScanProjectStore.previousSplatFileName).path), "previous completed result was not preserved")
try Data(repeating: 0xEE, count: 13).write(to: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
let recoveredOld = try ScanProjectStore(rootURL: root).loadProject(id: reprocessCrash.1.id)
expect(recoveredOld.manifest.stage == .finished, "reprocess crash did not recover previous finished state")
let recoveredOldData = try Data(contentsOf: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
expect(recoveredOldData == splatData(0x2A), "reprocess crash damaged the previous completed splat")

// PROCESSING success: a valid new result replaces the previous one and cleanup happens only after finish.
let reprocessSuccess = try relaunched.createProject(title: "reprocess-success")
try rawFiles(in: reprocessSuccess.0)
try splatData(0x10).write(to: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
}
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { $0.stage = .processing }
try splatData(0x20).write(to: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
}
let successfulData = try Data(contentsOf: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
expect(successfulData == splatData(0x20), "successful reprocess did not retain the new result")
expect(!FileManager.default.fileExists(atPath: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.previousSplatFileName).path), "previous result was not cleaned after successful finish")

// FINISHED written immediately before termination: relaunch promotes the valid file to finished.
let completedWrite = try relaunched.createProject(title: "completed-write")
try splatData(0x04).write(to: completedWrite.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
_ = try relaunched.updateManifest(projectURL: completedWrite.0) { $0.stage = .processing }
let recoveredFinished = try ScanProjectStore(rootURL: root).loadProject(id: completedWrite.1.id)
expect(recoveredFinished.manifest.stage == .finished, "valid splat was not promoted to finished")
expect(recoveredFinished.manifest.splatFileName == ScanProjectStore.splatResultFileName, "recovered splat output missing")

// FAILED: failure state survives relaunch rather than silently disappearing from the library.
let failed = try relaunched.createProject(title: "failed")
_ = try relaunched.updateManifest(projectURL: failed.0) { manifest in
    manifest.stage = .failed
    manifest.lastError = "synthetic failure"
}
let recoveredFailed = try ScanProjectStore(rootURL: root).loadProject(id: failed.1.id)
expect(recoveredFailed.manifest.stage == .failed, "failed stage did not survive relaunch")
expect(recoveredFailed.manifest.lastError == "synthetic failure", "failure reason did not survive relaunch")

// S4 handoff: retained raw can be requested for either Splat or Mesh without duplicating storage.
let meshRequest = try relaunched.reprocessRequest(projectURL: persistent.0, representation: .mesh)
expect(meshRequest.representation == .mesh, "mesh reprocess contract lost representation")
expect(meshRequest.imagesURL.lastPathComponent == "images", "mesh reprocess contract did not expose retained images")

// Clearing raw must never remove the completed result or thumbnail.
let clearable = try relaunched.createProject(title: "clearable")
try rawFiles(in: clearable.0)
try splatData(0x05).write(to: clearable.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
try relaunched.setThumbnail(data: Data(repeating: 6, count: 12), projectURL: clearable.0)
_ = try relaunched.updateManifest(projectURL: clearable.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
}
try relaunched.clearRawData(projectURL: clearable.0)
let cleared = try relaunched.loadProject(id: clearable.1.id)
expect(!cleared.manifest.rawDataRetained, "raw flag remained true after clear")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.splatResultFileName).path), "clear raw deleted result")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.thumbnailFileName).path), "clear raw deleted thumbnail")
expect(!FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent("images").path), "clear raw retained images")

// TRASH: delete is reversible until explicitly purged.
let recoverableDelete = try relaunched.createProject(title: "trash")
try relaunched.moveToTrash(projectURL: recoverableDelete.0)
let afterDelete = ScanProjectStore(rootURL: root)
expect(afterDelete.listTrash().contains(where: { $0.id == recoverableDelete.1.id }), "project did not enter trash across relaunch")
try afterDelete.restoreFromTrash(id: recoverableDelete.1.id)
expect(ScanProjectStore(rootURL: root).listProjects().contains(where: { $0.id == recoverableDelete.1.id }), "project did not restore across relaunch")

// MIGRATION: pre-S5 PoC folders migrate in place without requiring a central index.
let legacyID = "legacy-gate"
let legacy = root.appendingPathComponent(legacyID).appendingPathExtension(ScanProjectStore.projectExtension)
try rawFiles(in: legacy)
let migrated = ScanProjectStore(rootURL: root).listProjects().first(where: { $0.id == legacyID })
expect(migrated?.manifest.stage == .captured, "legacy project was not migrated")
expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent(ScanProjectStore.manifestFileName).path), "legacy manifest not written")

print("PASS: ScanProjectStore lifecycle regression gate — capturing/captured/processing/finished/failed/trash/migration")
