import Foundation

extension SeparationOutputAssurance {
    func validateManifest(_ manifest: SeparationProviderRunManifest, requireFreshOutputURLs: Bool = true) throws {
        guard manifest.schemaVersion == 1 else { throw failure("SEP_RUN_SCHEMA_UNSUPPORTED", false) }
        for value in [manifest.providerID, manifest.providerKind, manifest.modelName, manifest.modelVersion, manifest.qualityProfile] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw failure("SEP_RUN_METADATA_MISSING", false) }
        }
        guard !manifest.requestedRoles.isEmpty else { throw failure("SEP_RUN_NO_ROLES", false) }
        guard manifest.outputs.count == manifest.requestedRoles.count else { throw failure("SEP_OUTPUT_COUNT_MISMATCH", false) }
        let roles = manifest.outputs.map(\.role)
        guard Set(roles).count == roles.count else { throw failure("SEP_OUTPUT_DUPLICATE_ROLE", false) }
        guard Set(roles) == manifest.requestedRoles else { throw failure("SEP_OUTPUT_ROLE_SET_MISMATCH", false) }
        let stemIDs = manifest.outputs.map(\.stemID)
        guard Set(stemIDs).count == stemIDs.count else { throw failure("SEP_OUTPUT_DUPLICATE_STEM_ID", false) }
        let urls = manifest.outputs.map { $0.downloadURL.absoluteString }
        guard Set(urls).count == urls.count else { throw failure("SEP_OUTPUT_DUPLICATE_URL", false) }
        try validateCost(manifest.cost)
        try validateRetention(manifest.retention)
        for output in manifest.outputs {
            guard output.downloadURL.scheme?.lowercased() == "https" else { throw failure("SEP_OUTPUT_INSECURE_URL", false) }
            guard output.container.lowercased() == "wav" else { throw failure("SEP_OUTPUT_CONTAINER_UNSUPPORTED", false) }
            guard output.sampleRate.isFinite, output.sampleRate >= 8_000, output.sampleRate <= 384_000 else { throw failure("SEP_OUTPUT_SAMPLE_RATE_INVALID", false) }
            guard output.channels > 0, output.channels <= 64 else { throw failure("SEP_OUTPUT_CHANNELS_INVALID", false) }
            guard output.frameCount > 0, output.durationSeconds.isFinite, output.durationSeconds > 0 else { throw failure("SEP_OUTPUT_DURATION_INVALID", false) }
            let declaredDuration = Double(output.frameCount) / output.sampleRate
            guard abs(declaredDuration - output.durationSeconds) <= durationToleranceSeconds else { throw failure("SEP_OUTPUT_DECLARED_DURATION_INCONSISTENT", false) }
            if let count = output.expectedByteCount { guard count > 0 else { throw failure("SEP_OUTPUT_BYTE_COUNT_INVALID", false) } }
            if let hash = output.expectedSHA256 { guard isSHA256(hash) else { throw failure("SEP_OUTPUT_HASH_INVALID", false) } }
            if requireFreshOutputURLs { try ensureNotExpired(output) }
        }
    }

    func validateCost(_ cost: SeparationCostAccounting) throws {
        let currency = cost.currency.uppercased()
        guard currency.count == 3, currency.allSatisfy({ $0.isASCII && $0.isLetter }) else { throw failure("SEP_COST_CURRENCY_INVALID", false) }
        guard cost.total.isFinite, cost.total >= 0 else { throw failure("SEP_COST_TOTAL_INVALID", false) }
        guard !cost.basis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw failure("SEP_COST_BASIS_MISSING", false) }
        if let units = cost.units {
            guard units.isFinite, units >= 0, cost.unitName?.isEmpty == false else { throw failure("SEP_COST_UNITS_INVALID", false) }
        } else if cost.unitName != nil {
            throw failure("SEP_COST_UNITS_INVALID", false)
        }
    }

    func validateRetention(_ retention: SeparationRetentionRecord) throws {
        if retention.localPolicy == .explicitExpiry {
            guard let expiry = retention.localExpiresAt, expiry > now() else { throw failure("SEP_RETENTION_LOCAL_EXPIRY_INVALID", false) }
        } else if retention.localExpiresAt != nil {
            throw failure("SEP_RETENTION_LOCAL_EXPIRY_UNEXPECTED", false)
        }
        if let confirmed = retention.vendorDeleteConfirmedAt {
            guard let requested = retention.vendorDeleteRequestedAt, confirmed >= requested else { throw failure("SEP_RETENTION_DELETE_ORDER_INVALID", false) }
        }
    }

    func ensureNotExpired(_ output: VendorStemOutputDescriptor) throws {
        guard output.expiresAt.timeIntervalSince(now()) > minimumExpiryLeadSeconds else {
            throw failure("SEP_OUTPUT_URL_EXPIRING", true)
        }
    }

    func validateDownloaded(output: VendorStemOutputDescriptor, inspected: WAVInspection, byteCount: Int64, sha256: String) throws {
        guard Double(inspected.sampleRate) == output.sampleRate else { throw failure("SEP_OUTPUT_SAMPLE_RATE_MISMATCH", false) }
        guard inspected.channels == output.channels else { throw failure("SEP_OUTPUT_CHANNEL_MISMATCH", false) }
        guard abs(inspected.frameCount - output.frameCount) <= 1 else { throw failure("SEP_OUTPUT_FRAME_COUNT_MISMATCH", false) }
        guard abs(inspected.durationSeconds - output.durationSeconds) <= durationToleranceSeconds else { throw failure("SEP_OUTPUT_DURATION_MISMATCH", false) }
        if let expected = output.expectedByteCount, expected != byteCount { throw failure("SEP_OUTPUT_BYTE_COUNT_MISMATCH", false) }
        if let expected = output.expectedSHA256, normalizeSHA256(expected) != sha256 { throw failure("SEP_OUTPUT_HASH_MISMATCH", false) }
    }

    func verifyPreparedFiles(_ ledger: SeparationRunLedger) throws {
        guard Set(ledger.verifiedOutputs.map(\.role)) == ledger.manifest.requestedRoles else { throw failure("SEP_PREPARED_ROLE_SET_MISMATCH", false) }
        for item in ledger.verifiedOutputs {
            let url = try resolveRelativePath(item.stagedRelativePath)
            guard fileManager.fileExists(atPath: url.path) else { throw failure("SEP_PREPARED_FILE_MISSING", true) }
            guard try fileSize(url) == item.byteCount else { throw failure("SEP_PREPARED_FILE_SIZE_CHANGED", false) }
            guard try SHA256FileHasher.hash(url: url) == item.sha256 else { throw failure("SEP_PREPARED_FILE_HASH_CHANGED", false) }
        }
    }

    func finalDirectoryMatches(_ ledger: SeparationRunLedger) throws -> Bool {
        let final = finalDirectory(projectID: ledger.manifest.projectID)
        guard fileManager.fileExists(atPath: final.path), !ledger.verifiedOutputs.isEmpty else { return false }
        let expectedNames = Set(ledger.verifiedOutputs.map { $0.role.rawValue + ".wav" })
        let actualNames: Set<String>
        do {
            actualNames = Set(try fileManager.contentsOfDirectory(atPath: final.path).filter { !$0.hasPrefix(".") })
        } catch {
            throw failure("SEP_FINAL_DIRECTORY_READ_FAILED", true)
        }
        guard actualNames == expectedNames else { return false }
        for item in ledger.verifiedOutputs {
            let url = final.appendingPathComponent(item.role.rawValue + ".wav")
            guard fileManager.fileExists(atPath: url.path), try SHA256FileHasher.hash(url: url) == item.sha256 else { return false }
        }
        return true
    }

    func copyReplacing(source: URL, destination: URL) throws {
        do {
            if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
            try fileManager.copyItem(at: source, to: destination)
        } catch {
            throw failure("SEP_OUTPUT_COPY_FAILED", true)
        }
    }

    func fileSize(_ url: URL) throws -> Int64 {
        do {
            let attrs = try fileManager.attributesOfItem(atPath: url.path)
            guard let number = attrs[.size] as? NSNumber, number.int64Value > 0 else { throw failure("SEP_OUTPUT_EMPTY", false) }
            return number.int64Value
        } catch let failure as DomainFailure { throw failure }
        catch { throw failure("SEP_OUTPUT_FILE_STAT_FAILED", true) }
    }

    func relativePath(_ url: URL) throws -> String {
        let root = appDataRoot.path
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard candidate.hasPrefix(root + "/") else { throw failure("SEP_OUTPUT_OUTSIDE_ROOT", false) }
        return String(candidate.dropFirst(root.count + 1))
    }

    func resolveRelativePath(_ value: String) throws -> URL {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.split(separator: "/").contains("..") else { throw failure("SEP_OUTPUT_PATH_UNSAFE", false) }
        let candidate = appDataRoot.appendingPathComponent(value).resolvingSymlinksInPath().standardizedFileURL
        guard candidate.path.hasPrefix(appDataRoot.path + "/") else { throw failure("SEP_OUTPUT_PATH_UNSAFE", false) }
        return candidate
    }

    func stagingDirectory(projectID: ProjectID, jobID: ProcessingJobID) -> URL {
        appDataRoot.appendingPathComponent("separation-output-staging", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
            .appendingPathComponent(jobID.rawValue.uuidString, isDirectory: true)
    }
    func finalDirectory(projectID: ProjectID) -> URL {
        appDataRoot.appendingPathComponent("separation-stems", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString, isDirectory: true)
    }
    func incomingDirectory(projectID: ProjectID, jobID: ProcessingJobID) -> URL {
        appDataRoot.appendingPathComponent("separation-commit", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString + "-" + jobID.rawValue.uuidString, isDirectory: true)
    }
    func backupDirectory(projectID: ProjectID, jobID: ProcessingJobID) -> URL {
        appDataRoot.appendingPathComponent("separation-commit-backup", isDirectory: true)
            .appendingPathComponent(projectID.rawValue.uuidString + "-" + jobID.rawValue.uuidString, isDirectory: true)
    }

    func inspectWAV(_ url: URL) throws -> WAVInspection {
        try WAVInspection.read(url: url)
    }
    func normalizeSHA256(_ value: String) -> String {
        let lower = value.lowercased()
        return lower.hasPrefix("sha256:") ? String(lower.dropFirst(7)) : lower
    }
    func isSHA256(_ value: String) -> Bool {
        let normalized = normalizeSHA256(value)
        return normalized.utf8.count == 64 && normalized.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
    func failure(_ code: String, _ retryable: Bool) -> DomainFailure { .processingFailed(code: code, retryable: retryable) }
}
