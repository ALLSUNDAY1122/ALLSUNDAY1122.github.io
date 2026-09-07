import Foundation

public struct SeparationRunManifestDocument: Codable, Sendable {
    public struct Provider: Codable, Sendable {
        public let id: String
        public let kind: String
        public let modelName: String
        public let modelVersion: String
        enum CodingKeys: String, CodingKey { case id, kind; case modelName = "model_name"; case modelVersion = "model_version" }
    }
    public struct TimingMilliseconds: Codable, Sendable {
        public let upload: Int64?
        public let queue: Int64?
        public let inference: Int64?
        public let download: Int64?
    }
    public struct Cost: Codable, Sendable {
        public let currency: String
        public let total: Double
        public let units: Double?
        public let unitName: String?
        public let basis: String
        public let isActual: Bool
        enum CodingKeys: String, CodingKey { case currency, total, units, basis; case unitName = "unit_name"; case isActual = "is_actual" }
    }
    public struct Retention: Codable, Sendable {
        public let vendorAssetExpiresAt: Date?
        public let vendorOutputExpiresAt: Date?
        public let vendorDeleteRequestedAt: Date?
        public let vendorDeleteConfirmedAt: Date?
        public let localPolicy: String
        public let localExpiresAt: Date?
        enum CodingKeys: String, CodingKey {
            case vendorAssetExpiresAt = "vendor_asset_expires_at"
            case vendorOutputExpiresAt = "vendor_output_expires_at"
            case vendorDeleteRequestedAt = "vendor_delete_requested_at"
            case vendorDeleteConfirmedAt = "vendor_delete_confirmed_at"
            case localPolicy = "local_policy"
            case localExpiresAt = "local_expires_at"
        }
    }
    public struct Output: Codable, Sendable {
        public let stemID: UUID
        public let role: String
        public let downloadURL: URL
        public let expiresAt: Date
        public let container: String
        public let sampleRateHz: Double
        public let channels: Int
        public let frameCount: Int64
        public let durationSeconds: Double
        public let expectedByteCount: Int64?
        public let expectedSHA256: String?
        enum CodingKeys: String, CodingKey {
            case stemID = "stem_id"
            case role
            case downloadURL = "download_url"
            case expiresAt = "expires_at"
            case container
            case sampleRateHz = "sample_rate_hz"
            case channels
            case frameCount = "frame_count"
            case durationSeconds = "duration_seconds"
            case expectedByteCount = "expected_byte_count"
            case expectedSHA256 = "expected_sha256"
        }
    }

    public let schemaVersion: Int
    public let evidenceState: String
    public let projectID: UUID
    public let jobID: UUID
    public let provider: Provider
    public let qualityProfile: String
    public let requestedRoles: [String]
    public let timingMs: TimingMilliseconds
    public let cost: Cost
    public let retention: Retention
    public let outputs: [Output]
    public let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case evidenceState = "evidence_state"
        case projectID = "project_id"
        case jobID = "job_id"
        case provider
        case qualityProfile = "quality_profile"
        case requestedRoles = "requested_roles"
        case timingMs = "timing_ms"
        case cost
        case retention
        case outputs
        case generatedAt = "generated_at"
    }

    public func domainManifest() throws -> SeparationProviderRunManifest {
        guard schemaVersion == 1 else { throw DomainFailure.processingFailed(code: "SEP_RUN_SCHEMA_UNSUPPORTED", retryable: false) }
        guard evidenceState == "NON_PARITY_EVIDENCE_ONLY" else { throw DomainFailure.processingFailed(code: "SEP_RUN_EVIDENCE_STATE_INVALID", retryable: false) }
        let roles = requestedRoles.map { StemRole(rawValue: $0.lowercased()) }
        guard roles.count == Set(roles).count, !roles.isEmpty else { throw DomainFailure.processingFailed(code: "SEP_RUN_ROLES_INVALID", retryable: false) }
        guard let localPolicy = SeparationRetentionPolicy(rawValue: retention.localPolicy) else { throw DomainFailure.processingFailed(code: "SEP_RETENTION_POLICY_INVALID", retryable: false) }
        let outputValues = outputs.map { value in
            VendorStemOutputDescriptor(
                stemID: StemID(rawValue: value.stemID),
                role: StemRole(rawValue: value.role.lowercased()),
                downloadURL: value.downloadURL,
                expiresAt: value.expiresAt,
                container: value.container,
                sampleRate: value.sampleRateHz,
                channels: value.channels,
                frameCount: value.frameCount,
                durationSeconds: value.durationSeconds,
                expectedByteCount: value.expectedByteCount,
                expectedSHA256: value.expectedSHA256
            )
        }
        return SeparationProviderRunManifest(
            projectID: ProjectID(rawValue: projectID),
            jobID: ProcessingJobID(rawValue: jobID),
            providerID: provider.id,
            providerKind: provider.kind,
            modelName: provider.modelName,
            modelVersion: provider.modelVersion,
            qualityProfile: qualityProfile,
            requestedRoles: Set(roles),
            outputs: outputValues,
            cost: SeparationCostAccounting(currency: cost.currency, total: cost.total, units: cost.units, unitName: cost.unitName, basis: cost.basis, isActual: cost.isActual),
            retention: SeparationRetentionRecord(
                vendorAssetExpiresAt: retention.vendorAssetExpiresAt,
                vendorOutputExpiresAt: retention.vendorOutputExpiresAt,
                vendorDeleteRequestedAt: retention.vendorDeleteRequestedAt,
                vendorDeleteConfirmedAt: retention.vendorDeleteConfirmedAt,
                localPolicy: localPolicy,
                localExpiresAt: retention.localExpiresAt
            ),
            uploadMilliseconds: timingMs.upload,
            queueMilliseconds: timingMs.queue,
            inferenceMilliseconds: timingMs.inference,
            downloadMilliseconds: timingMs.download,
            generatedAt: generatedAt
        )
    }
}

public enum SeparationRunManifestCodec {
    public static func decode(_ data: Data) throws -> SeparationProviderRunManifest {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(SeparationRunManifestDocument.self, from: data).domainManifest()
        } catch let failure as DomainFailure {
            throw failure
        } catch {
            throw DomainFailure.processingFailed(code: "SEP_RUN_MANIFEST_DECODE_FAILED", retryable: false)
        }
    }
}
