import Foundation

private enum ProbeFailure: Error { case wrongRequest, activeStageWasSwept }

private actor RecoveryProbeBaseImporter: AudioImporting {
    let rootURL: URL
    let failAfterProbe: Bool
    init(rootURL: URL, failAfterProbe: Bool) { self.rootURL = rootURL; self.failAfterProbe = failAfterProbe }

    func importAudio(from request: ImportRequest) async throws -> LocalAudioAsset {
        guard case .appOwnedFile(let relativePath) = request else { throw ProbeFailure.wrongRequest }
        try await Task.sleep(for: .milliseconds(350))
        let store = IOFileStore(rootURL: rootURL)
        let staged = rootURL.appendingPathComponent(relativePath)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-7200)], ofItemAtPath: staged.path)
        let removed = try IOStagingRecovery(fileStore: store).sweep(olderThan: 60)
        guard removed.isEmpty, FileManager.default.fileExists(atPath: staged.path) else {
            throw ProbeFailure.activeStageWasSwept
        }
        if failAfterProbe { throw DomainFailure.corruptMedia }
        return LocalAudioAsset()
    }
}

@main
struct L2AW16WrapperSelfCheck {
    static func main() async throws {
        let fm = FileManager.default
        var scenarios = 0
        for fail in [false, true] {
            let root = fm.temporaryDirectory.appendingPathComponent("aw16-wrap-" + UUID().uuidString, isDirectory: true)
            let source = fm.temporaryDirectory.appendingPathComponent("aw16-src-" + UUID().uuidString).appendingPathExtension("wma")
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try Data(repeating: 0x55, count: 128 * 1024).write(to: source)
            defer { try? fm.removeItem(at: root); try? fm.removeItem(at: source) }
            let importer = IOProviderSnapshotAudioImporter(
                baseImporter: RecoveryProbeBaseImporter(rootURL: root, failAfterProbe: fail),
                rootURL: root,
                maximumFileBytes: 1024 * 1024,
                storageReserveBytes: 0,
                chunkBytes: 4096,
                ownershipHeartbeatBytes: 8192,
                ownershipLeaseDuration: 0.2,
                ownershipKeepAliveInterval: 0.1
            )
            do {
                _ = try await importer.importExternalFile(at: source, accessMode: .direct)
                guard !fail else { fatalError("unexpected success") }
            } catch DomainFailure.corruptMedia {
                guard fail else { fatalError("unexpected failure") }
            }
            let staging = root.appendingPathComponent("Staging", isDirectory: true)
            guard (try fm.contentsOfDirectory(atPath: staging.path)).isEmpty else { fatalError("staging/lease handoff leaked") }
            scenarios += 1
        }
        print("L2_AW16_WRAPPER_SELF_TEST_PASS scenarios=\(scenarios)")
    }
}
