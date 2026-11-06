import Foundation

func testDeleteProtectsNewerRun() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    _ = try await f.assurance.prepare(f.manifest())
    _ = try await f.assurance.commit(projectID:f.projectID, jobID:f.jobID)
    let finalV = f.root.appendingPathComponent("separation-stems/\(f.projectID.rawValue.uuidString)/vocals.wav")
    try Data("NEWER-RUN".utf8).write(to:finalV)
    do { _ = try await f.assurance.deleteLocalRun(projectID:f.projectID, jobID:f.jobID); fatalError("must protect") }
    catch { require(failureCode(error) == "SEP_DELETE_NEWER_RUN_PROTECTED", "protect newer") }
    require(FileManager.default.fileExists(atPath:finalV.path), "newer preserved")
}

func testCrashRecoveryRestoresBackup() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    _ = try await f.assurance.prepare(f.manifest())
    let backup = f.root.appendingPathComponent("separation-commit-backup/\(f.projectID.rawValue.uuidString)-\(f.jobID.rawValue.uuidString)", isDirectory:true)
    try FileManager.default.createDirectory(at:backup,withIntermediateDirectories:true)
    try Data("BACKUP".utf8).write(to:backup.appendingPathComponent("vocals.wav"))
    try await f.assurance.recoverInterruptedCommit(projectID:f.projectID,jobID:f.jobID)
    let final = f.root.appendingPathComponent("separation-stems/\(f.projectID.rawValue.uuidString)/vocals.wav")
    let finalData = try Data(contentsOf: final)
    require(String(data:finalData,encoding:.utf8)=="BACKUP","backup restored")
}

func testFileLedgerRoundTrip() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let store = try FileSeparationRunLedgerStore(appDataRoot:f.root)
    let assurance = SeparationOutputAssurance(appDataRoot:f.root,fetcher:f.fetcher,ledgerStore:store,minimumExpiryLeadSeconds:30,now:{ [now=f.now] in now })
    let prepared = try await assurance.prepare(f.manifest())
    let loaded = try await store.load(projectID:f.projectID,jobID:f.jobID)
    require(loaded?.state == .prepared,"ledger state")
    require(loaded?.verifiedOutputs.map(\.sha256) == prepared.verifiedOutputs.map(\.sha256),"hashes roundtrip")
    require(loaded?.manifest.cost.total == 0.08,"cost roundtrip")
    require(loaded?.manifest.retention.localPolicy == .untilProjectDelete,"retention roundtrip")
}

func testMissingOutputRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let onlyVocals = [f.manifest().outputs[0]]
    do { _ = try await f.assurance.prepare(f.manifest(outputs: onlyVocals)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_COUNT_MISMATCH", "missing output") }
}

func testUnsupportedContainerRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    var outputs = f.manifest().outputs
    let v = outputs[0]
    outputs[0] = VendorStemOutputDescriptor(stemID:v.stemID, role:v.role, downloadURL:v.downloadURL, expiresAt:v.expiresAt, container:"mp3", sampleRate:v.sampleRate, channels:v.channels, frameCount:v.frameCount, durationSeconds:v.durationSeconds)
    do { _ = try await f.assurance.prepare(f.manifest(outputs:outputs)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_CONTAINER_UNSUPPORTED", "container") }
}

func testExpectedByteCountMismatchRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    var outputs = f.manifest().outputs
    let v = outputs[0]
    outputs[0] = VendorStemOutputDescriptor(stemID:v.stemID, role:v.role, downloadURL:v.downloadURL, expiresAt:v.expiresAt, container:v.container, sampleRate:v.sampleRate, channels:v.channels, frameCount:v.frameCount, durationSeconds:v.durationSeconds, expectedByteCount:123, expectedSHA256:nil)
    do { _ = try await f.assurance.prepare(f.manifest(outputs:outputs)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_BYTE_COUNT_MISMATCH", "byte count") }
}

func testDeleteProtectsAdditionalNewerStem() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    _ = try await f.assurance.prepare(f.manifest())
    _ = try await f.assurance.commit(projectID:f.projectID, jobID:f.jobID)
    let final = f.root.appendingPathComponent("separation-stems/\(f.projectID.rawValue.uuidString)", isDirectory:true)
    try Data("NEW-BASS".utf8).write(to:final.appendingPathComponent("bass.wav"))
    do { _ = try await f.assurance.deleteLocalRun(projectID:f.projectID, jobID:f.jobID); fatalError("must protect extra") }
    catch { require(failureCode(error) == "SEP_DELETE_NEWER_RUN_PROTECTED", "extra file protection") }
    require(FileManager.default.fileExists(atPath:final.appendingPathComponent("bass.wav").path), "extra preserved")
}

func testAssuredProviderUsesManifestSeamAndCachesCommittedResult() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let manifest = f.manifest()
    let controller = ControllerStub(jobID:f.jobID)
    let manifestProvider = ManifestProviderStub(manifest)
    let provider = AssuredSeparationProvider(controller:controller,manifestProvider:manifestProvider,assurance:f.assurance,ledgerStore:f.store)
    let first = try await provider.result(jobID:f.jobID)
    let downloadsAfterFirst = await f.fetcher.count()
    let second = try await provider.result(jobID:f.jobID)
    let downloadsAfterSecond = await f.fetcher.count()
    let controllerResults = await controller.resultCount()
    require(first.count == 2 && second.count == 2, "assured artifacts")
    require(downloadsAfterFirst == 2 && downloadsAfterSecond == 2, "committed result cache")
    require(controllerResults == 0, "raw controller result bypass forbidden")
}

func testFlatLiveManifestCodecFeedsAssurance() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let iso = ISO8601DateFormatter()
    let expires = iso.string(from: f.now.addingTimeInterval(3600))
    let generated = iso.string(from: f.now)
    let object: [String: Any] = [
        "schema_version": 1,
        "evidence_state": "NON_PARITY_EVIDENCE_ONLY",
        "project_id": f.projectID.rawValue.uuidString,
        "job_id": f.jobID.rawValue.uuidString,
        "provider": ["id": "live-provider", "kind": "SERVER_API", "model_name": "4stem", "model_version": "v1"],
        "quality_profile": "standard",
        "requested_roles": ["vocals", "drums"],
        "timing_ms": ["upload": 100, "queue": 20, "inference": 500, "download": 90],
        "cost": ["currency": "USD", "total": 0.08, "units": 2.0, "unit_name": "credits", "basis": "actual provider telemetry", "is_actual": true],
        "retention": ["vendor_asset_expires_at": expires, "vendor_output_expires_at": expires, "local_policy": "untilProjectDelete"],
        "outputs": [
            ["stem_id": UUID().uuidString, "role": "vocals", "download_url": "https://vendor.example/vocals.wav", "expires_at": expires, "container": "wav", "sample_rate_hz": 44100.0, "channels": 2, "frame_count": 44100, "duration_seconds": 1.0, "expected_byte_count": 176444, "expected_sha256": "f33a18bc9af300b294ab7aba995735bc14cdda00fb1df0d73b0001161a491dea"],
            ["stem_id": UUID().uuidString, "role": "drums", "download_url": "https://vendor.example/drums.wav", "expires_at": expires, "container": "wav", "sample_rate_hz": 44100.0, "channels": 2, "frame_count": 44100, "duration_seconds": 1.0, "expected_byte_count": 176444, "expected_sha256": "7eb1cff0f0ff0e2f7e41607375ce897542bae8595ca0ba91860ba871c40563aa"]
        ],
        "generated_at": generated
    ]
    let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    let decoded = try SeparationRunManifestCodec.decode(data)
    require(decoded.projectID == f.projectID, "codec project")
    require(decoded.jobID == f.jobID, "codec job")
    require(decoded.cost.isActual, "codec cost")
    let prepared = try await f.assurance.prepare(decoded)
    require(prepared.verifiedOutputs.count == 2, "codec feeds assurance")
}
