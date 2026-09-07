import Foundation

public enum AnalysisPhysicalRealAudioDecoderKind: String, Codable, Sendable {
    case genuineLane2BoundedDecoder = "GENUINE_LANE2_BOUNDED_DECODER"
    case compatibilityWholeSignal = "COMPATIBILITY_WHOLE_SIGNAL"
    case unknown = "UNKNOWN"
}

public struct AnalysisPhysicalRealAudioDecoderBinding: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let kind: AnalysisPhysicalRealAudioDecoderKind
    public let decoderID: String
    public let decoderVersion: String
    public let decoderSessionID: String

    public init(
        schemaVersion: Int = 1,
        kind: AnalysisPhysicalRealAudioDecoderKind,
        decoderID: String,
        decoderVersion: String,
        decoderSessionID: String
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.decoderID = decoderID
        self.decoderVersion = decoderVersion
        self.decoderSessionID = decoderSessionID
    }
}

public struct AnalysisPhysicalRealAudioRuntimeBinding: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let platform: String
    public let architecture: String
    public let sourceRevision: String
    public let buildIdentity: String
    public let deviceModel: String
    public let osVersion: String
    public let physicalSessionID: String
    public let analyzerID: String
    public let analyzerVersion: String
    public let analysisConfigurationID: String
    public let engine: String
    public let engineVersion: String
    public let decoder: AnalysisPhysicalRealAudioDecoderBinding

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        platform: String,
        architecture: String,
        sourceRevision: String,
        buildIdentity: String,
        deviceModel: String,
        osVersion: String,
        physicalSessionID: String,
        analyzerID: String,
        analyzerVersion: String,
        analysisConfigurationID: String,
        engine: String,
        engineVersion: String,
        decoder: AnalysisPhysicalRealAudioDecoderBinding
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.platform = platform
        self.architecture = architecture
        self.sourceRevision = sourceRevision
        self.buildIdentity = buildIdentity
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.physicalSessionID = physicalSessionID
        self.analyzerID = analyzerID
        self.analyzerVersion = analyzerVersion
        self.analysisConfigurationID = analysisConfigurationID
        self.engine = engine
        self.engineVersion = engineVersion
        self.decoder = decoder
    }
}

public struct AnalysisPhysicalRealAudioDecodedSource: Sendable {
    public let signal: AnalysisChunkedSignal
    public let sourceSHA256: String
    public let sourceChannelCount: Int
    public let decoderExecutionID: String

    public init(
        signal: AnalysisChunkedSignal,
        sourceSHA256: String,
        sourceChannelCount: Int,
        decoderExecutionID: String
    ) {
        self.signal = signal
        self.sourceSHA256 = sourceSHA256.lowercased()
        self.sourceChannelCount = sourceChannelCount
        self.decoderExecutionID = decoderExecutionID
    }
}

/// Lane-4-owned integration seam. Worker 4 does not provide a compatibility implementation.
/// HQ/Lane 2 must supply the genuine bounded decoder adapter in the integrated iOS target.
public protocol AnalysisPhysicalRealAudioChunkedDecoding: Sendable {
    var decoderBinding: AnalysisPhysicalRealAudioDecoderBinding { get }

    func openPhysicalRealAudioFixture(
        projectID: ProjectID,
        asset: LocalAudioAsset
    ) async throws -> AnalysisPhysicalRealAudioDecodedSource
}

public struct AnalysisPhysicalRealAudioFixtureExecutionReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let fixtureID: String
    public let runtimeBindingSHA256: String
    public let decoderExecutionID: String
    public let sourceSHA256: String
    public let sourceSampleRate: Double
    public let sourceSampleCount: Int64
    public let sourceChannelCount: Int
    public let observedSourceChunkCount: Int
    public let observedSourceSampleCount: Int64
    public let workloadReceipt: AnalysisDeviceWorkloadReceipt

    public init(
        schemaVersion: Int = 1,
        fixtureID: String,
        runtimeBindingSHA256: String,
        decoderExecutionID: String,
        sourceSHA256: String,
        sourceSampleRate: Double,
        sourceSampleCount: Int64,
        sourceChannelCount: Int,
        observedSourceChunkCount: Int,
        observedSourceSampleCount: Int64,
        workloadReceipt: AnalysisDeviceWorkloadReceipt
    ) {
        self.schemaVersion = schemaVersion
        self.fixtureID = fixtureID
        self.runtimeBindingSHA256 = runtimeBindingSHA256.lowercased()
        self.decoderExecutionID = decoderExecutionID
        self.sourceSHA256 = sourceSHA256.lowercased()
        self.sourceSampleRate = sourceSampleRate
        self.sourceSampleCount = sourceSampleCount
        self.sourceChannelCount = sourceChannelCount
        self.observedSourceChunkCount = observedSourceChunkCount
        self.observedSourceSampleCount = observedSourceSampleCount
        self.workloadReceipt = workloadReceipt
    }
}

public enum AnalysisPhysicalRealAudioCorpusPackageStatus: String, Codable, Sendable {
    case readyForW46ProjectInputPendingHQ = "READY_FOR_W46_PROJECT_INPUT_PENDING_HQ_NON_PARITY"
}

public struct AnalysisPhysicalRealAudioCorpusExecutionPackage: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let status: AnalysisPhysicalRealAudioCorpusPackageStatus
    public let manifestID: String
    public let manifestSHA256: String
    public let runtime: AnalysisPhysicalRealAudioRuntimeBinding
    public let runtimeBindingSHA256: String
    public let expectedFixtureIDs: [String]
    public let receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt]
    public let auditedProjectReport: AnalysisAuditedRealAudioBenchmarkReport
    public let auditedProjectReportSHA256: String
    public let limitations: [String]
    public let declaredPackageRootSHA256: String

    public init(
        schemaVersion: Int = 1,
        status: AnalysisPhysicalRealAudioCorpusPackageStatus = .readyForW46ProjectInputPendingHQ,
        manifestID: String,
        manifestSHA256: String,
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        runtimeBindingSHA256: String,
        expectedFixtureIDs: [String],
        receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt],
        auditedProjectReport: AnalysisAuditedRealAudioBenchmarkReport,
        auditedProjectReportSHA256: String,
        limitations: [String],
        declaredPackageRootSHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.status = status
        self.manifestID = manifestID
        self.manifestSHA256 = manifestSHA256.lowercased()
        self.runtime = runtime
        self.runtimeBindingSHA256 = runtimeBindingSHA256.lowercased()
        self.expectedFixtureIDs = expectedFixtureIDs.sorted()
        self.receipts = receipts.sorted { $0.fixtureID < $1.fixtureID }
        self.auditedProjectReport = auditedProjectReport
        self.auditedProjectReportSHA256 = auditedProjectReportSHA256.lowercased()
        self.limitations = limitations
        self.declaredPackageRootSHA256 = declaredPackageRootSHA256.lowercased()
    }
}

public enum AnalysisPhysicalRealAudioCorpusIssueCode: String, Codable, Hashable, Sendable {
    case invalidManifest = "W47_INVALID_MANIFEST"
    case nonRealFixture = "W47_NON_REAL_FIXTURE"
    case invalidRuntimeBinding = "W47_INVALID_RUNTIME_BINDING"
    case nonGenuineDecoder = "W47_NON_GENUINE_DECODER"
    case fixtureInventoryMismatch = "W47_FIXTURE_INVENTORY_MISMATCH"
    case duplicateRunID = "W47_DUPLICATE_RUN_ID"
    case duplicateExecutionID = "W47_DUPLICATE_EXECUTION_ID"
    case duplicateDecoderExecutionID = "W47_DUPLICATE_DECODER_EXECUTION_ID"
    case sourceBindingMismatch = "W47_SOURCE_BINDING_MISMATCH"
    case sourceObservationMismatch = "W47_SOURCE_OBSERVATION_MISMATCH"
    case workloadBindingMismatch = "W47_WORKLOAD_BINDING_MISMATCH"
    case invalidWorkloadStages = "W47_INVALID_WORKLOAD_STAGES"
    case invalidSnapshot = "W47_INVALID_SNAPSHOT"
    case reportRebuildMismatch = "W47_REPORT_REBUILD_MISMATCH"
    case reportRootMismatch = "W47_REPORT_ROOT_MISMATCH"
    case packageRootMismatch = "W47_PACKAGE_ROOT_MISMATCH"
}

public struct AnalysisPhysicalRealAudioCorpusIssue: Codable, Equatable, Sendable {
    public let code: AnalysisPhysicalRealAudioCorpusIssueCode
    public let fixtureID: String?
    public let detail: String

    public init(code: AnalysisPhysicalRealAudioCorpusIssueCode, fixtureID: String? = nil, detail: String) {
        self.code = code
        self.fixtureID = fixtureID
        self.detail = detail
    }
}

public enum AnalysisPhysicalRealAudioCorpusExecutionError: Error, Equatable, Sendable {
    case invalid([AnalysisPhysicalRealAudioCorpusIssue])
    case canonicalEncodingFailed
}

public enum AnalysisPhysicalRealAudioCorpusCanonical {
    public static func stableSHA256<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return AnalysisDeviceWorkloadSHA256.hexDigest(try encoder.encode(value))
    }

    public static func runtimeSHA256(_ runtime: AnalysisPhysicalRealAudioRuntimeBinding) throws -> String {
        try stableSHA256(runtime)
    }

    private struct PackageRootPayload: Codable {
        let schemaVersion: Int
        let status: AnalysisPhysicalRealAudioCorpusPackageStatus
        let manifestID: String
        let manifestSHA256: String
        let runtime: AnalysisPhysicalRealAudioRuntimeBinding
        let runtimeBindingSHA256: String
        let expectedFixtureIDs: [String]
        let receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt]
        let auditedProjectReport: AnalysisAuditedRealAudioBenchmarkReport
        let auditedProjectReportSHA256: String
        let limitations: [String]
    }

    public static func packageSHA256(_ package: AnalysisPhysicalRealAudioCorpusExecutionPackage) throws -> String {
        try stableSHA256(PackageRootPayload(
            schemaVersion: package.schemaVersion,
            status: package.status,
            manifestID: package.manifestID,
            manifestSHA256: package.manifestSHA256,
            runtime: package.runtime,
            runtimeBindingSHA256: package.runtimeBindingSHA256,
            expectedFixtureIDs: package.expectedFixtureIDs.sorted(),
            receipts: package.receipts.sorted { $0.fixtureID < $1.fixtureID },
            auditedProjectReport: package.auditedProjectReport,
            auditedProjectReportSHA256: package.auditedProjectReportSHA256,
            limitations: package.limitations
        ))
    }
}

public enum AnalysisPhysicalRealAudioCorpusCodec {
    public static func encode(_ package: AnalysisPhysicalRealAudioCorpusExecutionPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }

    public static func decode(_ data: Data) throws -> AnalysisPhysicalRealAudioCorpusExecutionPackage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AnalysisPhysicalRealAudioCorpusExecutionPackage.self, from: data)
    }
}
