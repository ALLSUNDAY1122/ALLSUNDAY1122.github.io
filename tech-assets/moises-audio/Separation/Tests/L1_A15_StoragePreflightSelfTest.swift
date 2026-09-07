import Foundation

func a15Require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError("A15 assertion failed: \(message)") }
}

func a15ExpectedFailure(_ code: String, retryable: Bool, _ operation: () throws -> Void) {
    do {
        try operation()
        fatalError("A15 expected failure \(code)")
    } catch DomainFailure.processingFailed(let actual, let actualRetryable) {
        a15Require(actual == code, "expected \(code), got \(actual)")
        a15Require(actualRetryable == retryable, "retryable mismatch")
    } catch {
        fatalError("A15 unexpected error: \(error)")
    }
}

func a15Manifest(outputs: [VendorStemOutputDescriptor]) -> SeparationProviderRunManifest {
    SeparationProviderRunManifest(
        projectID: ProjectID(),
        jobID: ProcessingJobID(),
        providerID: "provider",
        providerKind: "SERVER_API",
        modelName: "model",
        modelVersion: "v1",
        qualityProfile: "standard",
        requestedRoles: Set(outputs.map(\.role)),
        outputs: outputs,
        cost: SeparationCostAccounting(
            currency: "USD", total: 0, units: nil, unitName: nil, basis: "test", isActual: false
        ),
        retention: SeparationRetentionRecord(
            vendorAssetExpiresAt: nil,
            vendorOutputExpiresAt: nil,
            vendorDeleteRequestedAt: nil,
            vendorDeleteConfirmedAt: nil,
            localPolicy: .untilProjectDelete,
            localExpiresAt: nil
        )
    )
}

func a15Output(
    role: StemRole,
    frames: Int64 = 44_100,
    channels: Int = 2,
    expectedBytes: Int64? = nil
) -> VendorStemOutputDescriptor {
    VendorStemOutputDescriptor(
        stemID: StemID(),
        role: role,
        downloadURL: URL(string: "https://example.test/\(role.rawValue).wav")!,
        expiresAt: Date().addingTimeInterval(3600),
        container: "wav",
        sampleRate: 44_100,
        channels: channels,
        frameCount: frames,
        durationSeconds: Double(frames) / 44_100,
        expectedByteCount: expectedBytes
    )
}

@main private struct L1A15StoragePreflightSelfTest {
    static func main() throws {
        try exactByteEstimateIncludesTemporaryAndReserve()
        try fallbackEstimateIsConservativeAndBounded()
        try commitEstimateRequiresOneAdditionalFullSet()
        insufficientStorageIsRetryable()
        invalidAvailableBytesFailClosed()
        estimateOverflowFailsClosed()
        print("L1_A15_STORAGE_PREFLIGHT_SELF_TEST_PASS scenarios=6")
    }

    static func exactByteEstimateIncludesTemporaryAndReserve() throws {
        let manifest = a15Manifest(outputs: [
            a15Output(role: .vocals, expectedBytes: 100),
            a15Output(role: .drums, expectedBytes: 300),
        ])
        let required = try SeparationStoragePreflight.estimatedPrepareAdditionalBytes(manifest)
        a15Require(
            required == 100 + 300 + 300 + SeparationStoragePreflight.safetyReserveBytes,
            "prepare must account all staging plus largest simultaneous temp"
        )
    }

    static func fallbackEstimateIsConservativeAndBounded() throws {
        let frames: Int64 = 1_000
        let output = a15Output(role: .vocals, frames: frames, channels: 2, expectedBytes: nil)
        let manifest = a15Manifest(outputs: [output])
        let one = frames * 2 * SeparationStoragePreflight.conservativeBytesPerSample
            + SeparationStoragePreflight.unknownWAVHeaderAllowanceBytes
        let required = try SeparationStoragePreflight.estimatedPrepareAdditionalBytes(manifest)
        a15Require(
            required == one + one + SeparationStoragePreflight.safetyReserveBytes,
            "fallback uses conservative sample width and one temporary copy"
        )
    }

    static func commitEstimateRequiresOneAdditionalFullSet() throws {
        let manifest = a15Manifest(outputs: [
            a15Output(role: .vocals, expectedBytes: 100),
            a15Output(role: .drums, expectedBytes: 200),
        ])
        let verified = [
            VerifiedSeparationOutput(
                stemID: manifest.outputs[0].stemID,
                role: .vocals,
                stagedRelativePath: "staging/vocals.wav",
                sha256: String(repeating: "a", count: 64),
                byteCount: 100,
                sampleRate: 44_100,
                channels: 2,
                frameCount: 44_100,
                durationSeconds: 1
            ),
            VerifiedSeparationOutput(
                stemID: manifest.outputs[1].stemID,
                role: .drums,
                stagedRelativePath: "staging/drums.wav",
                sha256: String(repeating: "b", count: 64),
                byteCount: 200,
                sampleRate: 44_100,
                channels: 2,
                frameCount: 44_100,
                durationSeconds: 1
            ),
        ]
        let ledger = SeparationRunLedger(
            state: .prepared,
            manifest: manifest,
            verifiedOutputs: verified,
            preparedAt: Date()
        )
        let required = try SeparationStoragePreflight.estimatedCommitAdditionalBytes(ledger)
        a15Require(
            required == 300 + SeparationStoragePreflight.safetyReserveBytes,
            "A14 incoming duplicate must fit before final swap"
        )
    }

    static func insufficientStorageIsRetryable() {
        a15ExpectedFailure("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", retryable: true) {
            try SeparationStoragePreflight.require(availableBytes: 99, requiredAdditionalBytes: 100)
        }
    }

    static func invalidAvailableBytesFailClosed() {
        a15ExpectedFailure("SEP_STORAGE_PREFLIGHT_INPUT_INVALID", retryable: false) {
            try SeparationStoragePreflight.require(availableBytes: -1, requiredAdditionalBytes: 100)
        }
    }

    static func estimateOverflowFailsClosed() {
        let output = a15Output(role: .vocals, frames: Int64.max, channels: 64, expectedBytes: nil)
        let manifest = a15Manifest(outputs: [output])
        a15ExpectedFailure("SEP_STORAGE_ESTIMATE_OVERFLOW", retryable: false) {
            _ = try SeparationStoragePreflight.estimatedPrepareAdditionalBytes(manifest)
        }
    }
}
