#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

public struct AnalysisIOSPhysicalRealAudioCorpusRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let authority: String
    public let approvalReference: String
    public let sourceRevision: String
    public let buildIdentity: String
    public let physicalSessionID: String
    public let analyzerID: String
    public let analyzerVersion: String
    public let analysisConfigurationID: String
    public let engine: String
    public let engineVersion: String

    public init(
        schemaVersion: Int = 1,
        authority: String,
        approvalReference: String,
        sourceRevision: String,
        buildIdentity: String,
        physicalSessionID: String,
        analyzerID: String,
        analyzerVersion: String,
        analysisConfigurationID: String,
        engine: String,
        engineVersion: String
    ) {
        self.schemaVersion = schemaVersion
        self.authority = authority
        self.approvalReference = approvalReference
        self.sourceRevision = sourceRevision
        self.buildIdentity = buildIdentity
        self.physicalSessionID = physicalSessionID
        self.analyzerID = analyzerID
        self.analyzerVersion = analyzerVersion
        self.analysisConfigurationID = analysisConfigurationID
        self.engine = engine
        self.engineVersion = engineVersion
    }
}

public enum AnalysisIOSPhysicalRealAudioCorpusStatus: String, Codable, Sendable {
    case invalidRequest = "W47_INVALID_REQUEST"
    case invalidManifest = "W47_INVALID_CANONICAL_MANIFEST"
    case nonPhysicalRuntime = "W47_NON_PHYSICAL_RUNTIME_NON_PARITY"
    case invalidDecoder = "W47_INVALID_GENUINE_LANE2_DECODER_BINDING"
    case fixtureExecutionFailed = "W47_FIXTURE_EXECUTION_FAILED"
    case readyPendingHQ = "W47_PROJECT_CORPUS_READY_PENDING_HQ_NON_PARITY"
}

public struct AnalysisIOSPhysicalRealAudioCorpusResult: Sendable {
    public let status: AnalysisIOSPhysicalRealAudioCorpusStatus
    public let package: AnalysisPhysicalRealAudioCorpusExecutionPackage?
    public let issues: [String]

    public init(
        status: AnalysisIOSPhysicalRealAudioCorpusStatus,
        package: AnalysisPhysicalRealAudioCorpusExecutionPackage?,
        issues: [String]
    ) {
        self.status = status
        self.package = package
        self.issues = issues.sorted()
    }
}

@MainActor
public enum AnalysisIOSPhysicalRealAudioCorpusCoordinator {
    public static func capture(
        canonicalManifestData: Data,
        decoder: any AnalysisPhysicalRealAudioChunkedDecoding,
        request: AnalysisIOSPhysicalRealAudioCorpusRequest,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) async -> AnalysisIOSPhysicalRealAudioCorpusResult {
        guard requestIsValid(request) else {
            return .init(status: .invalidRequest, package: nil, issues: ["W47_REQUEST_FIELDS_OR_HQ_AUTHORITY_INVALID"])
        }
        guard isSelectedPhysicalIOSRuntime else {
            return .init(status: .nonPhysicalRuntime, package: nil, issues: ["W47_REQUIRES_PHYSICAL_IPHONEOS_ARM64_RUNTIME"])
        }
        guard decoder.decoderBinding.schemaVersion == 1,
              decoder.decoderBinding.kind == .genuineLane2BoundedDecoder,
              !decoder.decoderBinding.decoderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !decoder.decoderBinding.decoderVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !decoder.decoderBinding.decoderSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .init(status: .invalidDecoder, package: nil, issues: ["W47_GENUINE_LANE2_BOUNDED_DECODER_REQUIRED"])
        }

        let manifest: AnalysisRealAudioBenchmarkManifest
        let manifestSHA256: String
        do {
            manifest = try AnalysisRealAudioBenchmarkCodec.decodeManifest(canonicalManifestData)
            let canonical = try AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
            guard canonical == canonicalManifestData else {
                return .init(status: .invalidManifest, package: nil, issues: ["W47_MANIFEST_BYTES_NOT_CANONICAL"])
            }
            manifestSHA256 = AnalysisDeviceWorkloadSHA256.hexDigest(canonicalManifestData)
        } catch {
            return .init(status: .invalidManifest, package: nil, issues: ["W47_MANIFEST_DECODE_OR_CANONICALIZATION_FAILED"])
        }
        let manifestIssues = AnalysisRealAudioManifestValidator.validate(manifest)
        guard manifestIssues.isEmpty,
              !manifest.cases.isEmpty,
              manifest.cases.allSatisfy({ $0.sourceKind == .realAudio }) else {
            return .init(status: .invalidManifest, package: nil, issues: ["W47_MANIFEST_REQUIRES_VALID_REAL_AUDIO_FIXTURES_ONLY"])
        }

        let runtime = AnalysisPhysicalRealAudioRuntimeBinding(
            authority: request.authority,
            approvalReference: request.approvalReference,
            platform: "iphoneos",
            architecture: "arm64",
            sourceRevision: request.sourceRevision,
            buildIdentity: request.buildIdentity,
            deviceModel: deviceModelIdentifier(),
            osVersion: UIDevice.current.systemVersion,
            physicalSessionID: request.physicalSessionID,
            analyzerID: request.analyzerID,
            analyzerVersion: request.analyzerVersion,
            analysisConfigurationID: request.analysisConfigurationID,
            engine: request.engine,
            engineVersion: request.engineVersion,
            decoder: decoder.decoderBinding
        )
        guard let runtimeRoot = try? AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(runtime) else {
            return .init(status: .invalidRequest, package: nil, issues: ["W47_RUNTIME_BINDING_ROOT_FAILED"])
        }

        let identity = AnalysisDeviceWorkloadIdentity(
            analyzerID: request.analyzerID,
            analyzerVersion: request.analyzerVersion,
            analysisConfigurationID: request.analysisConfigurationID,
            buildIdentity: request.buildIdentity
        )
        var receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt] = []
        var decoderExecutionIDs = Set<String>()
        var workloadExecutionIDs = Set<String>()
        var runIDs = Set<String>()

        for item in manifest.cases {
            do {
                try AnalysisCancellationPolicy.check()
                let asset = LocalAudioAsset(
                    id: AssetID(rawValue: item.assetID),
                    relativePath: item.relativePath,
                    mediaKind: .audio,
                    durationSeconds: item.expectedDurationSeconds
                )
                let decoded = try await decoder.openPhysicalRealAudioFixture(
                    projectID: ProjectID(rawValue: item.projectID),
                    asset: asset
                )
                guard decoded.signal.sourceMemoryContract == .boundedPull else {
                    return failed(item.fixtureID, "W47_DECODER_SOURCE_CONTRACT_NOT_BOUNDED_PULL")
                }
                guard decoded.sourceSHA256 == item.rights.sourceSHA256.lowercased(),
                      AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(decoded.sourceSHA256),
                      decoded.sourceChannelCount > 0,
                      !decoded.decoderExecutionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      decoderExecutionIDs.insert(decoded.decoderExecutionID).inserted else {
                    return failed(item.fixtureID, "W47_DECODER_SOURCE_SHA_CHANNEL_OR_EXECUTION_ID_INVALID")
                }
                let descriptor = decoded.signal.descriptor
                let tolerance = max(0.050, item.expectedDurationSeconds * 0.001)
                guard descriptor.sampleRate.isFinite,
                      descriptor.sampleRate > 0,
                      descriptor.sampleCount > 0,
                      abs(descriptor.durationSeconds - item.expectedDurationSeconds) <= tolerance else {
                    return failed(item.fixtureID, "W47_DECODED_SOURCE_DESCRIPTOR_MISMATCH")
                }

                let runID = "w47-" + UUID().uuidString.lowercased()
                guard runIDs.insert(runID).inserted else {
                    return failed(item.fixtureID, "W47_RUN_ID_COLLISION")
                }
                let source = AnalysisDeviceWorkloadSourceBinding(
                    fixtureID: item.fixtureID,
                    sourceSHA256: decoded.sourceSHA256,
                    sourceDurationSeconds: item.expectedDurationSeconds,
                    sourceSampleRate: descriptor.sampleRate,
                    sourceChannelCount: decoded.sourceChannelCount
                )
                let context = AnalysisDeviceWorkloadRunContext(
                    runID: runID,
                    runKind: .completeAnalysis,
                    manifestID: manifest.manifestID,
                    manifestSHA256: manifestSHA256,
                    source: source,
                    identity: identity
                )
                let execution = await Task.detached(priority: .userInitiated) {
                    await AnalysisCurrentDeviceWorkloadRunner.run(
                        signal: decoded.signal,
                        context: context,
                        configuration: configuration
                    )
                }.value

                guard execution.outcome == .completed,
                      execution.snapshot != nil,
                      execution.boundedSourceContractAccepted,
                      execution.observedSourceChunkCount > 0,
                      execution.observedSourceSampleCount == descriptor.sampleCount,
                      workloadExecutionIDs.insert(execution.receipt.executionID).inserted,
                      execution.receipt.snapshotCanonicalJSON != nil,
                      execution.receipt.snapshotSHA256 != nil,
                      execution.algorithmEvidence?.workloadExecutionID == execution.receipt.executionID,
                      execution.algorithmEvidence?.sourceInputContract == .boundedPull,
                      execution.algorithmEvidence?.captureState == .finalized else {
                    return failed(item.fixtureID, execution.failureDescription ?? "W47_CURRENT_CHUNKED_ANALYSIS_EXECUTION_NOT_COMPLETE")
                }

                receipts.append(AnalysisPhysicalRealAudioFixtureExecutionReceipt(
                    fixtureID: item.fixtureID,
                    runtimeBindingSHA256: runtimeRoot,
                    decoderExecutionID: decoded.decoderExecutionID,
                    sourceSHA256: decoded.sourceSHA256,
                    sourceSampleRate: descriptor.sampleRate,
                    sourceSampleCount: descriptor.sampleCount,
                    sourceChannelCount: decoded.sourceChannelCount,
                    observedSourceChunkCount: execution.observedSourceChunkCount,
                    observedSourceSampleCount: execution.observedSourceSampleCount,
                    workloadReceipt: execution.receipt
                ))
            } catch is CancellationError {
                return failed(item.fixtureID, "W47_CORPUS_EXECUTION_CANCELLED_NO_PARTIAL_EXPORT")
            } catch {
                return failed(item.fixtureID, "W47_DECODER_OR_ANALYSIS_ERROR:\(String(describing: error))")
            }
        }

        do {
            let generatedAt = Date()
            let package = try AnalysisPhysicalRealAudioCorpusAssembler.assemble(
                manifest: manifest,
                manifestSHA256: manifestSHA256,
                runtime: runtime,
                receipts: receipts,
                configuration: configuration,
                generatedAt: generatedAt
            )
            let reopenIssues = AnalysisPhysicalRealAudioCorpusAssembler.reopen(
                package,
                manifest: manifest,
                configuration: configuration,
                evaluatedAt: generatedAt
            )
            guard reopenIssues.isEmpty else {
                return .init(
                    status: .fixtureExecutionFailed,
                    package: nil,
                    issues: reopenIssues.map { $0.code.rawValue + ":" + ($0.fixtureID ?? "-") + ":" + $0.detail }
                )
            }
            return .init(status: .readyPendingHQ, package: package, issues: [])
        } catch let error as AnalysisPhysicalRealAudioCorpusExecutionError {
            return .init(status: .fixtureExecutionFailed, package: nil, issues: [String(describing: error)])
        } catch {
            return .init(status: .fixtureExecutionFailed, package: nil, issues: ["W47_PACKAGE_ASSEMBLY_FAILED:\(String(describing: error))"])
        }
    }

    private static func failed(_ fixtureID: String, _ detail: String) -> AnalysisIOSPhysicalRealAudioCorpusResult {
        .init(status: .fixtureExecutionFailed, package: nil, issues: ["\(fixtureID):\(detail)"])
    }

    private static func requestIsValid(_ request: AnalysisIOSPhysicalRealAudioCorpusRequest) -> Bool {
        let strings = [
            request.approvalReference, request.sourceRevision, request.buildIdentity, request.physicalSessionID,
            request.analyzerID, request.analyzerVersion, request.analysisConfigurationID, request.engine, request.engineVersion
        ]
        return request.schemaVersion == 1
            && request.authority == AnalysisPhysicalRealAudioCorpusAssembler.requiredAuthority
            && strings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(request.physicalSessionID)
    }

    private static var isSelectedPhysicalIOSRuntime: Bool {
        #if os(iOS) && arch(arm64) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, child in
            guard let value = child.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}
#endif
