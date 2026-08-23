import Foundation

private actor AW15SelfCheckImporter: AudioImporting {
    let rootURL: URL
    var lastBytes = Data()
    init(rootURL: URL) { self.rootURL = rootURL }
    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        guard case .appOwnedFile(let relativePath) = request else {
            throw DomainFailure.processingFailed(code: "wrong", retryable: false)
        }
        lastBytes = try Data(contentsOf: rootURL.appendingPathComponent(relativePath))
        return LocalAudioAsset()
    }
}

@main
struct L2AW15ProviderSnapshotSelfCheck {
    static func main() async throws {
        var scenarios = 0
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("L2AW15-" + UUID().uuidString, isDirectory: true)
        let root = base.appendingPathComponent("app", isDirectory: true)
        let provider = base.appendingPathComponent("provider", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: provider, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let store = IOFileStore(rootURL: root)
        let acquirer = IOProviderSnapshotAcquirer(fileStore: store, maximumFileBytes: 2_000_000, storageReserveBytes: 0, chunkBytes: 4096)

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
            if !condition() { throw NSError(domain: "L2AW15", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        }

        let stable = provider.appendingPathComponent("stable.wma")
        let stableBytes = Data((0..<131072).map { UInt8($0 % 241) })
        try stableBytes.write(to: stable)
        let staged = try acquirer.stageProviderFile(at: stable, accessMode: .direct)
        let stagedData = try Data(contentsOf: staged.stagingURL)
        try expect(stagedData == stableBytes, "stable copy mismatch")
        try expect(staged.descriptor.pathExtension == "wma", "extension lost")
        store.removeIfExists(staged.stagingURL, fileManager: fm)
        scenarios += 1

        let copied = IOProviderContentFingerprint(byteCount: 10, hashA: 1, hashB: 2)
        let changed = IOProviderContentFingerprint(byteCount: 10, hashA: 9, hashB: 8)
        do {
            try IOProviderSnapshotAcquirer.requireCoherentSnapshot(initialBytes: 10, copied: copied, sourceAfter: changed)
            throw NSError(domain: "L2AW15", code: 2)
        } catch IOProviderSnapshotAcquisitionError.sourceChangedDuringAcquisition {}
        scenarios += 1

        do {
            try IOProviderSnapshotAcquirer.requireCoherentSnapshot(initialBytes: 11, copied: copied, sourceAfter: copied)
            throw NSError(domain: "L2AW15", code: 3)
        } catch IOProviderSnapshotAcquisitionError.sourceChangedDuringAcquisition {}
        scenarios += 1

        let tooLarge = provider.appendingPathComponent("large.mp3")
        try Data(repeating: 1, count: 2_000_001).write(to: tooLarge)
        do {
            _ = try acquirer.stageProviderFile(at: tooLarge, accessMode: .direct)
            throw NSError(domain: "L2AW15", code: 4)
        } catch IOProviderSnapshotAcquisitionError.sourceTooLarge {}
        scenarios += 1

        let empty = provider.appendingPathComponent("empty.wav")
        _ = fm.createFile(atPath: empty.path, contents: Data())
        do {
            _ = try acquirer.stageProviderFile(at: empty, accessMode: .direct)
            throw NSError(domain: "L2AW15", code: 5)
        } catch IOProviderSnapshotAcquisitionError.sourceEmpty {}
        scenarios += 1

        try store.prepareDirectories()
        let stalePartial = store.stagingURL.appendingPathComponent("interrupted.provider-partial")
        try Data([1,2,3]).write(to: stalePartial)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: stalePartial.path)
        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60, now: Date(timeIntervalSince1970: 1000), fileManager: fm)
        try expect(removed.contains(stalePartial.lastPathComponent), "stale partial not recovered")
        scenarios += 1

        let wrapperSource = provider.appendingPathComponent("wrapper.flac")
        let wrapperBytes = Data([5,4,3,2,1])
        try wrapperBytes.write(to: wrapperSource)
        let mock = AW15SelfCheckImporter(rootURL: root)
        let wrapper = IOProviderSnapshotAudioImporter(baseImporter: mock, rootURL: root, maximumFileBytes: 1024, storageReserveBytes: 0, chunkBytes: 2, fileManager: fm)
        _ = try await wrapper.importExternalFile(at: wrapperSource, accessMode: .direct)
        let observed = await mock.lastBytes
        try expect(observed == wrapperBytes, "wrapper handoff mismatch")
        let afterWrapper = try fm.contentsOfDirectory(atPath: store.stagingURL.path)
        try expect(afterWrapper.isEmpty, "wrapper leaked staging lease")
        scenarios += 1

        let benchmarkFiles = 200
        let payload = Data((0..<65536).map { UInt8(($0 * 13) % 251) })
        let start = Date()
        for index in 0..<benchmarkFiles {
            let url = provider.appendingPathComponent("bench-\(index).m4a")
            try payload.write(to: url)
            let item = try acquirer.stageProviderFile(at: url, accessMode: .direct)
            store.removeIfExists(item.stagingURL, fileManager: fm)
            try fm.removeItem(at: url)
        }
        let elapsed = Date().timeIntervalSince(start)
        scenarios += 1

        let elapsedText = String(format: "%.6f", elapsed)
        print("L2_AW15_SELF_TEST_PASS scenarios=\(scenarios) files=\(benchmarkFiles) bytes_per_file=\(payload.count) elapsed_seconds=\(elapsedText)")
    }
}
