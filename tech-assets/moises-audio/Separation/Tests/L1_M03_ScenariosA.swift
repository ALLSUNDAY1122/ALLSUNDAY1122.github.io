import Foundation

func testPrepareCommitDeleteHappyPath() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let prepared = try await f.assurance.prepare(f.manifest())
    require(prepared.state == .prepared, "prepared state")
    require(prepared.verifiedOutputs.count == 2, "verified count")
    require(Set(prepared.verifiedOutputs.map(\.role)) == Set([.vocals, .drums]), "roles")
    let committed = try await f.assurance.commit(projectID: f.projectID, jobID: f.jobID)
    require(committed.state == .committed, "committed")
    require(committed.finalArtifacts.count == 2, "artifacts")
    for artifact in committed.finalArtifacts {
        require(FileManager.default.fileExists(atPath: f.root.appendingPathComponent(artifact.relativePath).path), "final file")
    }
    let deleted = try await f.assurance.deleteLocalRun(projectID: f.projectID, jobID: f.jobID)
    require(deleted.state == .deleted, "deleted")
}

func testExpiringURLRejectedBeforeFetch() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    do { _ = try await f.assurance.prepare(f.manifest(expiresIn: 10)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_URL_EXPIRING", "expiry code") }
    let count = await f.fetcher.count(); require(count == 0, "no download")
}

func testDuplicateRoleRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let base = f.manifest().outputs
    let dup = VendorStemOutputDescriptor(stemID: StemID(), role: .vocals, downloadURL: URL(string: "https://vendor.example/drums.wav")!, expiresAt: f.now.addingTimeInterval(3600), container: "wav", sampleRate: 44_100, channels: 2, frameCount: 44_100, durationSeconds: 1)
    do { _ = try await f.assurance.prepare(f.manifest(outputs: [base[0], dup])); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_DUPLICATE_ROLE", "duplicate role") }
}

func testDuplicateStemIDRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let shared = StemID()
    let a = VendorStemOutputDescriptor(stemID: shared, role: .vocals, downloadURL: URL(string:"https://vendor.example/vocals.wav")!, expiresAt:f.now.addingTimeInterval(3600), container:"wav", sampleRate:44_100, channels:2, frameCount:44_100, durationSeconds:1)
    let b = VendorStemOutputDescriptor(stemID: shared, role: .drums, downloadURL: URL(string:"https://vendor.example/drums.wav")!, expiresAt:f.now.addingTimeInterval(3600), container:"wav", sampleRate:44_100, channels:2, frameCount:44_100, durationSeconds:1)
    do { _ = try await f.assurance.prepare(f.manifest(outputs:[a,b])); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_DUPLICATE_STEM_ID", "duplicate id") }
}

func testCorruptWAVLeavesExistingFinalUntouched() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let final = f.root.appendingPathComponent("separation-stems/\(f.projectID.rawValue.uuidString)", isDirectory:true)
    try FileManager.default.createDirectory(at: final, withIntermediateDirectories:true)
    let old = final.appendingPathComponent("vocals.wav"); try Data("OLD-STEM".utf8).write(to: old)
    try Data("not-a-wav".utf8).write(to: f.drumsURL)
    do { _ = try await f.assurance.prepare(f.manifest()); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_WAV_INVALID", "corrupt wav") }
    let oldData = try Data(contentsOf: old)
    require(String(data: oldData, encoding:.utf8) == "OLD-STEM", "old final preserved")
    let staging = f.root.appendingPathComponent("separation-output-staging/\(f.projectID.rawValue.uuidString)/\(f.jobID.rawValue.uuidString)")
    require(!FileManager.default.fileExists(atPath: staging.path), "partial staging cleaned")
}

func testSampleRateMismatchRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    var outputs = f.manifest().outputs
    let v = outputs[0]
    outputs[0] = VendorStemOutputDescriptor(stemID:v.stemID, role:v.role, downloadURL:v.downloadURL, expiresAt:v.expiresAt, container:"wav", sampleRate:48_000, channels:2, frameCount:48_000, durationSeconds:1)
    do { _ = try await f.assurance.prepare(f.manifest(outputs:outputs)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_SAMPLE_RATE_MISMATCH", "sample rate") }
}

func testFrameCountMismatchRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    var outputs = f.manifest().outputs
    let v = outputs[0]
    outputs[0] = VendorStemOutputDescriptor(stemID:v.stemID, role:v.role, downloadURL:v.downloadURL, expiresAt:v.expiresAt, container:"wav", sampleRate:44_100, channels:2, frameCount:43_000, durationSeconds:Double(43_000)/44_100)
    do { _ = try await f.assurance.prepare(f.manifest(outputs:outputs)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_FRAME_COUNT_MISMATCH", "frame mismatch") }
}

func testExpectedHashMismatchRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    var outputs = f.manifest().outputs
    let v = outputs[0]
    outputs[0] = VendorStemOutputDescriptor(stemID:v.stemID, role:v.role, downloadURL:v.downloadURL, expiresAt:v.expiresAt, container:"wav", sampleRate:v.sampleRate, channels:v.channels, frameCount:v.frameCount, durationSeconds:v.durationSeconds, expectedSHA256:String(repeating:"0",count:64))
    do { _ = try await f.assurance.prepare(f.manifest(outputs:outputs)); fatalError("must reject") }
    catch { require(failureCode(error) == "SEP_OUTPUT_HASH_MISMATCH", "hash mismatch") }
}

func testInvalidCostAndRetentionRejected() async throws {
    let f = try Fixture(); defer { f.cleanup() }
    let badCost = SeparationCostAccounting(currency:"US", total:-1, units:nil, unitName:nil, basis:"", isActual:true)
    do { _ = try await f.assurance.prepare(f.manifest(cost:badCost)); fatalError("bad cost") }
    catch { require(failureCode(error) == "SEP_COST_CURRENCY_INVALID", "currency") }
    let badRetention = SeparationRetentionRecord(vendorAssetExpiresAt:nil, vendorOutputExpiresAt:nil, vendorDeleteRequestedAt:nil, vendorDeleteConfirmedAt:nil, localPolicy:.explicitExpiry, localExpiresAt:f.now.addingTimeInterval(-1))
    do { _ = try await f.assurance.prepare(f.manifest(retention:badRetention)); fatalError("bad retention") }
    catch { require(failureCode(error) == "SEP_RETENTION_LOCAL_EXPIRY_INVALID", "retention") }
}
