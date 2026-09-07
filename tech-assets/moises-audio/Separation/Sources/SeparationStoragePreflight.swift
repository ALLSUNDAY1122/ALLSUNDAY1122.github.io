import Foundation

enum SeparationStoragePreflight {
    static let safetyReserveBytes: Int64 = 256 * 1024 * 1024
    static let unknownWAVHeaderAllowanceBytes: Int64 = 1024 * 1024
    static let conservativeBytesPerSample: Int64 = 8

    static func estimatedPrepareAdditionalBytes(_ manifest: SeparationProviderRunManifest) throws -> Int64 {
        guard !manifest.outputs.isEmpty else {
            throw failure("SEP_STORAGE_ESTIMATE_OUTPUTS_EMPTY", false)
        }
        var total: Int64 = 0
        var largest: Int64 = 0
        for output in manifest.outputs {
            let estimated = try estimatedOutputBytes(output)
            total = try adding(total, estimated)
            largest = max(largest, estimated)
        }
        // URLSession download creates a temporary file before it is copied into app-owned staging.
        // In the worst same-volume case, all previously staged stems plus one current temp stem coexist.
        return try adding(try adding(total, largest), safetyReserveBytes)
    }

    static func estimatedCommitAdditionalBytes(_ ledger: SeparationRunLedger) throws -> Int64 {
        guard ledger.state == .prepared, !ledger.verifiedOutputs.isEmpty else {
            throw failure("SEP_STORAGE_COMMIT_LEDGER_INVALID", false)
        }
        var total: Int64 = 0
        for output in ledger.verifiedOutputs {
            guard output.byteCount > 0 else {
                throw failure("SEP_STORAGE_COMMIT_BYTE_COUNT_INVALID", false)
            }
            total = try adding(total, output.byteCount)
        }
        // A14 copies the verified staging set into incoming before rename promotion. Backup/final
        // transitions are renames on the same app-owned volume, so the extra copy is one full set.
        return try adding(total, safetyReserveBytes)
    }

    static func availableBytes(at root: URL, fileManager: FileManager = .default) throws -> Int64 {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: root.path)
            guard let number = attributes[.systemFreeSize] as? NSNumber else {
                throw failure("SEP_STORAGE_FREE_BYTES_UNAVAILABLE", true)
            }
            let value = number.int64Value
            guard value >= 0 else {
                throw failure("SEP_STORAGE_FREE_BYTES_INVALID", true)
            }
            return value
        } catch let domain as DomainFailure {
            throw domain
        } catch {
            throw failure("SEP_STORAGE_FREE_BYTES_UNAVAILABLE", true)
        }
    }

    static func require(availableBytes: Int64, requiredAdditionalBytes: Int64) throws {
        guard availableBytes >= 0, requiredAdditionalBytes > 0 else {
            throw failure("SEP_STORAGE_PREFLIGHT_INPUT_INVALID", false)
        }
        guard availableBytes >= requiredAdditionalBytes else {
            throw failure("SEP_STORAGE_PREFLIGHT_INSUFFICIENT", true)
        }
    }

    private static func estimatedOutputBytes(_ output: VendorStemOutputDescriptor) throws -> Int64 {
        if let expected = output.expectedByteCount {
            guard expected > 0 else { throw failure("SEP_OUTPUT_BYTE_COUNT_INVALID", false) }
            return expected
        }
        guard output.frameCount > 0, output.channels > 0 else {
            throw failure("SEP_STORAGE_ESTIMATE_METADATA_INVALID", false)
        }
        let frameBytes = try multiplying(output.frameCount, Int64(output.channels))
        let payloadBytes = try multiplying(frameBytes, conservativeBytesPerSample)
        return try adding(payloadBytes, unknownWAVHeaderAllowanceBytes)
    }

    private static func adding(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow, value > 0 else {
            throw failure("SEP_STORAGE_ESTIMATE_OVERFLOW", false)
        }
        return value
    }

    private static func multiplying(_ lhs: Int64, _ rhs: Int64) throws -> Int64 {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow, value > 0 else {
            throw failure("SEP_STORAGE_ESTIMATE_OVERFLOW", false)
        }
        return value
    }

    private static func failure(_ code: String, _ retryable: Bool) -> DomainFailure {
        .processingFailed(code: code, retryable: retryable)
    }
}

extension SeparationOutputAssurance {
    func requirePrepareStorage(_ manifest: SeparationProviderRunManifest) throws {
        let required = try SeparationStoragePreflight.estimatedPrepareAdditionalBytes(manifest)
        let available = try SeparationStoragePreflight.availableBytes(at: appDataRoot, fileManager: fileManager)
        try SeparationStoragePreflight.require(availableBytes: available, requiredAdditionalBytes: required)
    }

    func requireCommitStorage(_ ledger: SeparationRunLedger) throws {
        let required = try SeparationStoragePreflight.estimatedCommitAdditionalBytes(ledger)
        let available = try SeparationStoragePreflight.availableBytes(at: appDataRoot, fileManager: fileManager)
        try SeparationStoragePreflight.require(availableBytes: available, requiredAdditionalBytes: required)
    }
}
