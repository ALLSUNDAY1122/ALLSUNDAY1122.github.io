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

let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("ScanProjectStoreGate-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: root) }

let store = ScanProjectStore(rootURL: root)

// Relaunch persistence.
let persistent = try store.createProject(title: "persistent")
_ = try store.updateManifest(projectURL: persistent.0) { manifest in
    manifest.stage = .captured
    manifest.acceptedFrames = 30
}
let relaunched = ScanProjectStore(rootURL: root)
let loaded = try relaunched.loadProject(id: persistent.1.id)
expect(loaded.manifest.acceptedFrames == 30, "manifest did not survive store recreation")

// Primary-manifest corruption recovers from the one-generation backup.
_ = try relaunched.updateManifest(projectURL: persistent.0) { $0.title = "backup-ok" }
_ = try relaunched.updateManifest(projectURL: persistent.0) { $0.acceptedFrames = 31 }
try Data("broken".utf8).write(
    to: persistent.0.appendingPathComponent(ScanProjectStore.manifestFileName),
    options: .atomic
)
let recoveredBackup = try ScanProjectStore(rootURL: root).loadProject(id: persistent.1.id)
expect(recoveredBackup.manifest.title == "backup-ok", "backup manifest recovery failed")

// A killed processing job returns to captured when raw is intact.
let interrupted = try relaunched.createProject(title: "interrupted")
try rawFiles(in: interrupted.0)
_ = try relaunched.updateManifest(projectURL: interrupted.0) { $0.stage = .processing }
let recoveredProcessing = try ScanProjectStore(rootURL: root).loadProject(id: interrupted.1.id)
expect(recoveredProcessing.manifest.stage == .captured, "processing interruption did not recover to captured")
expect(recoveredProcessing.manifest.recoveredAfterInterruption, "processing recovery flag missing")

// If the splat file finished before termination, relaunch promotes it to finished.
let completedWrite = try relaunched.createProject(title: "completed-write")
try Data(repeating: 4, count: 64).write(to: completedWrite.0.appendingPathComponent("result.splat"))
_ = try relaunched.updateManifest(projectURL: completedWrite.0) { $0.stage = .processing }
let recoveredFinished = try ScanProjectStore(rootURL: root).loadProject(id: completedWrite.1.id)
expect(recoveredFinished.manifest.stage == .finished, "valid splat was not promoted to finished")
expect(recoveredFinished.manifest.splatFileName == "result.splat", "recovered splat output missing")

// Clearing raw must never remove the completed result or thumbnail.
let clearable = try relaunched.createProject(title: "clearable")
try rawFiles(in: clearable.0)
try Data(repeating: 5, count: 64).write(to: clearable.0.appendingPathComponent("result.splat"))
try relaunched.setThumbnail(data: Data(repeating: 6, count: 12), projectURL: clearable.0)
_ = try relaunched.updateManifest(projectURL: clearable.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = "result.splat"
}
try relaunched.clearRawData(projectURL: clearable.0)
let cleared = try relaunched.loadProject(id: clearable.1.id)
expect(!cleared.manifest.rawDataRetained, "raw flag remained true after clear")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent("result.splat").path), "clear raw deleted result")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.thumbnailFileName).path), "clear raw deleted thumbnail")

// Delete is reversible until explicitly purged.
let recoverableDelete = try relaunched.createProject(title: "trash")
try relaunched.moveToTrash(projectURL: recoverableDelete.0)
expect(relaunched.listTrash().contains(where: { $0.id == recoverableDelete.1.id }), "project did not enter trash")
try relaunched.restoreFromTrash(id: recoverableDelete.1.id)
expect(relaunched.listProjects().contains(where: { $0.id == recoverableDelete.1.id }), "project did not restore")

// Pre-S5 PoC folders migrate in place without requiring a central index.
let legacyID = "legacy-gate"
let legacy = root.appendingPathComponent(legacyID).appendingPathExtension(ScanProjectStore.projectExtension)
try rawFiles(in: legacy)
let migrated = ScanProjectStore(rootURL: root).listProjects().first(where: { $0.id == legacyID })
expect(migrated?.manifest.stage == .captured, "legacy project was not migrated")
expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent(ScanProjectStore.manifestFileName).path), "legacy manifest not written")

print("PASS: ScanProjectStore lifecycle regression gate")
