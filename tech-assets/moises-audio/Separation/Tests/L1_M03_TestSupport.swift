import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}

func failureCode(_ error: Error) -> String {
    guard let failure = error as? DomainFailure else { return "NON_DOMAIN" }
    switch failure {
    case .processingFailed(let code, _): return code
    case .networkTimeout: return "NETWORK_TIMEOUT"
    case .networkUnavailable: return "NETWORK_UNAVAILABLE"
    case .cancelled: return "CANCELLED"
    default: return String(describing: failure)
    }
}

actor MemoryLedgerStore: SeparationRunLedgerStoring {
    private var records: [String: SeparationRunLedger] = [:]
    func load(projectID: ProjectID, jobID: ProcessingJobID) async throws -> SeparationRunLedger? {
        records[projectID.rawValue.uuidString + ":" + jobID.rawValue.uuidString]
    }
    func save(_ ledger: SeparationRunLedger) async throws {
        records[ledger.manifest.projectID.rawValue.uuidString + ":" + ledger.manifest.jobID.rawValue.uuidString] = ledger
    }
}

actor FixtureFetcher: VendorOutputFetching {
    private let files: [String: URL]
    private var countValue = 0
    init(files: [String: URL]) { self.files = files }
    func download(_ url: URL) async throws -> URL {
        countValue += 1
        guard let file = files[url.absoluteString] else {
            throw DomainFailure.processingFailed(code: "TEST_REMOTE_MISSING", retryable: false)
        }
        return file
    }
    func count() -> Int { countValue }
}

actor ControllerStub: SourceSeparationProviding {
    private let jobID: ProcessingJobID
    private var resultCalls = 0
    init(jobID: ProcessingJobID) { self.jobID = jobID }
    func start(_ request: SeparationRequest) async throws -> ProcessingJobID { jobID }
    func snapshot(jobID: ProcessingJobID) async throws -> ProcessingSnapshot { ProcessingSnapshot(jobID:jobID,phase:.ready,fractionComplete:1,retryable:false) }
    func result(jobID: ProcessingJobID) async throws -> [StemArtifact] { resultCalls += 1; throw DomainFailure.processingFailed(code:"TEST_CONTROLLER_RESULT_MUST_NOT_RUN",retryable:false) }
    func cancel(jobID: ProcessingJobID) async {}
    func resultCount() -> Int { resultCalls }
}

actor ManifestProviderStub: SeparationRunManifestProviding {
    private let manifest: SeparationProviderRunManifest
    init(_ manifest: SeparationProviderRunManifest) { self.manifest = manifest }
    func outputManifest(jobID: ProcessingJobID) async throws -> SeparationProviderRunManifest { manifest }
}

struct Fixture {
    let root: URL
    let projectID: ProjectID
    let jobID: ProcessingJobID
    let vocalsURL: URL
    let drumsURL: URL
    let now: Date
    let fetcher: FixtureFetcher
    let store: MemoryLedgerStore
    let assurance: SeparationOutputAssurance

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("l1m03-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        projectID = ProjectID()
        jobID = ProcessingJobID()
        vocalsURL = root.appendingPathComponent("vendor-vocals.wav")
        drumsURL = root.appendingPathComponent("vendor-drums.wav")
        try writeWAV(vocalsURL, sampleRate: 44_100, channels: 2, frames: 44_100, value: 800)
        try writeWAV(drumsURL, sampleRate: 44_100, channels: 2, frames: 44_100, value: 1200)
        now = Date(timeIntervalSince1970: 1_800_000_000)
        let remoteV = "https://vendor.example/vocals.wav"
        let remoteD = "https://vendor.example/drums.wav"
        fetcher = FixtureFetcher(files: [remoteV: vocalsURL, remoteD: drumsURL])
        store = MemoryLedgerStore()
        assurance = SeparationOutputAssurance(appDataRoot: root, fetcher: fetcher, ledgerStore: store, minimumExpiryLeadSeconds: 30, now: { [now] in now })
    }

    func manifest(
        expiresIn: TimeInterval = 3600,
        outputs: [VendorStemOutputDescriptor]? = nil,
        cost: SeparationCostAccounting? = nil,
        retention: SeparationRetentionRecord? = nil
    ) -> SeparationProviderRunManifest {
        let defaultOutputs = [
            VendorStemOutputDescriptor(
                stemID: StemID(), role: .vocals, downloadURL: URL(string: "https://vendor.example/vocals.wav")!, expiresAt: now.addingTimeInterval(expiresIn), container: "wav", sampleRate: 44_100, channels: 2, frameCount: 44_100, durationSeconds: 1, expectedByteCount: 176_444, expectedSHA256: "f33a18bc9af300b294ab7aba995735bc14cdda00fb1df0d73b0001161a491dea"
            ),
            VendorStemOutputDescriptor(
                stemID: StemID(), role: .drums, downloadURL: URL(string: "https://vendor.example/drums.wav")!, expiresAt: now.addingTimeInterval(expiresIn), container: "wav", sampleRate: 44_100, channels: 2, frameCount: 44_100, durationSeconds: 1, expectedByteCount: 176_444, expectedSHA256: "7eb1cff0f0ff0e2f7e41607375ce897542bae8595ca0ba91860ba871c40563aa"
            )
        ]
        return SeparationProviderRunManifest(
            projectID: projectID,
            jobID: jobID,
            providerID: "provider-live-id",
            providerKind: "SERVER_API",
            modelName: "four-stem",
            modelVersion: "2026-08",
            qualityProfile: "standard",
            requestedRoles: [.vocals, .drums],
            outputs: outputs ?? defaultOutputs,
            cost: cost ?? SeparationCostAccounting(currency: "USD", total: 0.08, units: 2, unitName: "credits", basis: "provider invoice/telemetry", isActual: true),
            retention: retention ?? SeparationRetentionRecord(
                vendorAssetExpiresAt: now.addingTimeInterval(72 * 3600),
                vendorOutputExpiresAt: now.addingTimeInterval(expiresIn),
                vendorDeleteRequestedAt: nil,
                vendorDeleteConfirmedAt: nil,
                localPolicy: .untilProjectDelete,
                localExpiresAt: nil
            ),
            uploadMilliseconds: 1000,
            queueMilliseconds: 200,
            inferenceMilliseconds: 5000,
            downloadMilliseconds: 900,
            generatedAt: now
        )
    }

    func cleanup() { try? FileManager.default.removeItem(at: root) }
}

func writeWAV(_ url: URL, sampleRate: Int, channels: Int, frames: Int, value: Int16) throws {
    let bitsPerSample = 16
    let blockAlign = channels * bitsPerSample / 8
    let byteRate = sampleRate * blockAlign
    let dataSize = frames * blockAlign
    var data = Data()
    func ascii(_ string: String) { data.append(string.data(using: .ascii)!) }
    func u16(_ value: UInt16) { data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff)) }
    func u32(_ value: UInt32) {
        data.append(UInt8(value & 0xff)); data.append(UInt8((value >> 8) & 0xff)); data.append(UInt8((value >> 16) & 0xff)); data.append(UInt8((value >> 24) & 0xff))
    }
    ascii("RIFF"); u32(UInt32(36 + dataSize)); ascii("WAVE")
    ascii("fmt "); u32(16); u16(1); u16(UInt16(channels)); u32(UInt32(sampleRate)); u32(UInt32(byteRate)); u16(UInt16(blockAlign)); u16(UInt16(bitsPerSample))
    ascii("data"); u32(UInt32(dataSize))
    let lo = UInt8(UInt16(bitPattern: value) & 0xff)
    let hi = UInt8((UInt16(bitPattern: value) >> 8) & 0xff)
    for _ in 0..<(frames * channels) { data.append(lo); data.append(hi) }
    try data.write(to: url)
}
