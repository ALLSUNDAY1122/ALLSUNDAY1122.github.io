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

// PROCESSING without an output: relaunch returns to captured when raw is intact.
let interrupted = try relaunched.createProject(title: "interrupted")
try rawFiles(in: interrupted.0)
_ = try relaunched.updateManifest(projectURL: interrupted.0) { $0.stage = .processing }
let recoveredProcessing = try ScanProjectStore(rootURL: root).loadProject(id: interrupted.1.id)
expect(recoveredProcessing.manifest.stage == .captured, "processing interruption did not recover to captured")
expect(recoveredProcessing.manifest.recoveredAfterInterruption, "processing recovery flag missing")

// S8 #4151 acceptance: an aligned partial/direct output is never completion evidence.
let alignedPartial = try relaunched.createProject(title: "aligned-partial")
try rawFiles(in: alignedPartial.0)
_ = try relaunched.updateManifest(projectURL: alignedPartial.0) { $0.stage = .processing }
try Data(repeating: 0xAA, count: 64).write(
    to: alignedPartial.0.appendingPathComponent(ScanProjectStore.splatResultFileName)
)
let recoveredAligned = try ScanProjectStore(rootURL: root).loadProject(id: alignedPartial.1.id)
expect(recoveredAligned.manifest.stage == .captured, "aligned partial output was promoted to finished")
expect(recoveredAligned.manifest.splatFileName == nil, "aligned partial output remained published")
expect(!FileManager.default.fileExists(atPath: alignedPartial.0.appendingPathComponent(ScanProjectStore.splatResultFileName).path), "aligned partial output was not discarded")

// S8 #4151 acceptance: an unaligned partial output is also discarded and raw remains retryable.
let unalignedPartial = try relaunched.createProject(title: "unaligned-partial")
try rawFiles(in: unalignedPartial.0)
_ = try relaunched.updateManifest(projectURL: unalignedPartial.0) { $0.stage = .processing }
try Data(repeating: 0xBB, count: 47).write(
    to: unalignedPartial.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
)
let recoveredUnaligned = try ScanProjectStore(rootURL: root).loadProject(id: unalignedPartial.1.id)
expect(recoveredUnaligned.manifest.stage == .captured, "unaligned partial output was promoted to finished")
expect(!FileManager.default.fileExists(atPath: unalignedPartial.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName).path), "unaligned partial pending output was not discarded")

// S8 #4151 acceptance: a fully exported pending file gets durable evidence before manifest completion.
// Simulate termination after commitPendingSplat returned but before ScanModel writes `.finished`.
let committedBeforeManifest = try relaunched.createProject(title: "committed-before-manifest")
try rawFiles(in: committedBeforeManifest.0)
_ = try relaunched.updateManifest(projectURL: committedBeforeManifest.0) { $0.stage = .processing }
try splatData(0xCC).write(
    to: committedBeforeManifest.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName)
)
let committedURL = try relaunched.commitPendingSplat(projectURL: committedBeforeManifest.0)
expect(FileManager.default.fileExists(atPath: committedURL.path), "committed output missing before simulated termination")
expect(FileManager.default.fileExists(atPath: committedBeforeManifest.0.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path), "durable completion evidence missing")
let recoveredCommitted = try ScanProjectStore(rootURL: root).loadProject(id: committedBeforeManifest.1.id)
expect(recoveredCommitted.manifest.stage == .finished, "durably committed output was not recovered after manifest interruption")
expect(recoveredCommitted.manifest.splatFileName == ScanProjectStore.splatResultFileName, "committed output was not published during recovery")
let recoveredCommittedData = try Data(contentsOf: recoveredCommitted.resultURL!)
expect(recoveredCommittedData == splatData(0xCC), "committed output changed during recovery")

// REPROCESS interruption: a prior finished result is preserved before `.processing` is made durable.
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
try Data(repeating: 0xEE, count: 64).write(to: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
let recoveredOld = try ScanProjectStore(rootURL: root).loadProject(id: reprocessCrash.1.id)
expect(recoveredOld.manifest.stage == .finished, "reprocess crash did not recover previous finished state")
let recoveredOldData = try Data(contentsOf: reprocessCrash.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
expect(recoveredOldData == splatData(0x2A), "reprocess crash damaged the previous completed splat")

// REPROCESS success: the new result is exported to pending and committed before the finished manifest.
let reprocessSuccess = try relaunched.createProject(title: "reprocess-success")
try rawFiles(in: reprocessSuccess.0)
try splatData(0x10).write(to: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = ScanProjectStore.splatResultFileName
}
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { $0.stage = .processing }
try splatData(0x20).write(to: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName))
let newResult = try relaunched.commitPendingSplat(projectURL: reprocessSuccess.0)
_ = try relaunched.updateManifest(projectURL: reprocessSuccess.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = newResult.lastPathComponent
}
let successfulData = try Data(contentsOf: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.splatResultFileName))
expect(successfulData == splatData(0x20), "successful reprocess did not retain the new result")
expect(!FileManager.default.fileExists(atPath: reprocessSuccess.0.appendingPathComponent(ScanProjectStore.previousSplatFileName).path), "previous result was not cleaned after successful finish")
expect(relaunched.trustedSplatURL(projectURL: reprocessSuccess.0) != nil, "finished result was not exposed through trusted completion contract")

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

// Clearing raw must never remove the completed result, thumbnail, or durable completion evidence.
let clearable = try relaunched.createProject(title: "clearable")
try rawFiles(in: clearable.0)
_ = try relaunched.updateManifest(projectURL: clearable.0) { $0.stage = .processing }
try splatData(0x05).write(to: clearable.0.appendingPathComponent(ScanProjectStore.pendingSplatFileName))
let clearableOutput = try relaunched.commitPendingSplat(projectURL: clearable.0)
try relaunched.setThumbnail(data: Data(repeating: 6, count: 12), projectURL: clearable.0)
_ = try relaunched.updateManifest(projectURL: clearable.0) { manifest in
    manifest.stage = .finished
    manifest.outputs[ScanRepresentationKind.splat.rawValue] = clearableOutput.lastPathComponent
}
try relaunched.clearRawData(projectURL: clearable.0)
let cleared = try relaunched.loadProject(id: clearable.1.id)
expect(!cleared.manifest.rawDataRetained, "raw flag remained true after clear")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.splatResultFileName).path), "clear raw deleted result")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.thumbnailFileName).path), "clear raw deleted thumbnail")
expect(FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName).path), "clear raw deleted completion evidence")
expect(!FileManager.default.fileExists(atPath: clearable.0.appendingPathComponent("images").path), "clear raw retained images")

// TRASH: delete is reversible until explicitly purged.
let recoverableDelete = try relaunched.createProject(title: "trash")
try relaunched.moveToTrash(projectURL: recoverableDelete.0)
let afterDelete = ScanProjectStore(rootURL: root)
expect(afterDelete.listTrash().contains(where: { $0.id == recoverableDelete.1.id }), "project did not enter trash across relaunch")
try afterDelete.restoreFromTrash(id: recoverableDelete.1.id)
expect(ScanProjectStore(rootURL: root).listProjects().contains(where: { $0.id == recoverableDelete.1.id }), "project did not restore across relaunch")

// MIGRATION: pre-S5 PoC raw folders migrate in place without requiring a central index.
let legacyID = "legacy-gate"
let legacy = root.appendingPathComponent(legacyID).appendingPathExtension(ScanProjectStore.projectExtension)
try rawFiles(in: legacy)
let migrated = ScanProjectStore(rootURL: root).listProjects().first(where: { $0.id == legacyID })
expect(migrated?.manifest.stage == .captured, "legacy project was not migrated")
expect(FileManager.default.fileExists(atPath: legacy.appendingPathComponent(ScanProjectStore.manifestFileName).path), "legacy manifest not written")

// MIGRATION + S8 #4151: a legacy folder without a manifest must not trust an aligned `.splat`
// merely because its byte count looks structurally valid. Keep the file, but publish only raw retry.
let legacyPartialID = "legacy-aligned-partial"
let legacyPartial = root.appendingPathComponent(legacyPartialID).appendingPathExtension(ScanProjectStore.projectExtension)
try rawFiles(in: legacyPartial)
let legacyPartialResult = legacyPartial.appendingPathComponent(ScanProjectStore.splatResultFileName)
try splatData(0x77).write(to: legacyPartialResult)
let migratedPartial = ScanProjectStore(rootURL: root).listProjects().first(where: { $0.id == legacyPartialID })
expect(migratedPartial?.manifest.stage == .captured, "legacy aligned partial was trusted as finished without completion evidence")
expect(migratedPartial?.manifest.splatFileName == nil, "legacy aligned partial was published without completion evidence")
expect(FileManager.default.fileExists(atPath: legacyPartialResult.path), "legacy migration destroyed the unverified result file")
expect(migratedPartial?.manifest.lastError?.contains("完了確認情報がない") == true, "legacy migration did not explain why the old result is untrusted")

print("PASS: ScanProjectStore lifecycle regression gate — partial outputs and legacy aligned results require durable completion evidence")
