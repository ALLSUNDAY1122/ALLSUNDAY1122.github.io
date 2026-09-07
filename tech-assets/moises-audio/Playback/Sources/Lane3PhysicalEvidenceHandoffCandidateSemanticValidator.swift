import Foundation

public enum Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError: Error, Equatable, Sendable {
    case artifactByteBindingRejected
    case candidateTraceCardinality
    case candidateArtifactCardinality
    case unsupportedArtifactFormat
    case artifactTooLarge
    case malformedArtifact
    case sessionIdentifierMismatch
    case invalidSampleSemantics
    case semanticMismatch
    case receiptIntegrityFailure
}

/// Deterministically re-derived semantics from the candidate AW52 canonical resource-trace bytes.
///
/// This summary says nothing about whether the bytes came from a physical iPhone. It only proves that
/// the already byte-bound artifact encodes the same resource statistics carried by the AW51 receipt.
struct Lane3CandidateResourceArtifactSemanticSummary: Equatable, Sendable {
    let sessionIdentifier: String
    let observedDurationSeconds: Double
    let sampleCount: Int
    let maximumSampleIntervalSeconds: Double
    let peakRSSBytes: UInt64
    let thermalNominalSamples: Int
    let thermalFairSamples: Int
    let thermalSeriousSamples: Int
    let thermalCriticalSamples: Int
    let batteryStartLevel: Double
    let batteryEndLevel: Double
    let externalPowerConnectedDuringBatteryWindow: Bool
    let artifactByteCount: Int
    let traceArtifactSHA256: String

    var semanticBindingSHA256: String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_CANDIDATE_RESOURCE_ARTIFACT_SEMANTIC_BINDING_V1",
            sessionIdentifier,
            String(observedDurationSeconds.bitPattern),
            String(sampleCount),
            String(maximumSampleIntervalSeconds.bitPattern),
            String(peakRSSBytes),
            String(thermalNominalSamples),
            String(thermalFairSamples),
            String(thermalSeriousSamples),
            String(thermalCriticalSamples),
            String(batteryStartLevel.bitPattern),
            String(batteryEndLevel.bitPattern),
            externalPowerConnectedDuringBatteryWindow ? "1" : "0",
            String(artifactByteCount),
            traceArtifactSHA256
        ])
    }
}

/// Streaming-size-bounded decoder for the exact binary format emitted by
/// `Lane3CandidatePhysicalResourceTraceAccumulator.canonicalArtifactData`.
///
/// Callers must first establish byte/digest binding. The public HQ validator below enforces that
/// ordering by invoking `Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator` before this decoder.
enum Lane3CandidateResourceArtifactSemanticDecoder {
    static let maximumArtifactBytes = 8 * 1_024 * 1_024
    private static let recordSize = 26
    private static let magic = Array("LANE3_AW52_CANDIDATE_RESOURCE_TRACE_V1\0".utf8)
    private static let traceScope = "LANE3_AW51_RESOURCE_TRACE_NON_PARITY"

    static func validatePreviouslyByteBoundArtifact(
        trace: Lane3PhysicalEvidenceResourceTraceReceipt,
        artifact: Lane3PhysicalEvidenceHandoffResourceArtifact
    ) throws -> Lane3CandidateResourceArtifactSemanticSummary {
        guard trace.schemaVersion == 1,
              trace.evidenceScope == traceScope,
              trace.subject == .candidate,
              trace.scenario == .longTrackStability,
              !trace.parityPromotionAllowed,
              artifact.subject == .candidate,
              artifact.scenario == .longTrackStability else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.semanticMismatch
        }
        guard trace.sessionIdentifier == artifact.sessionIdentifier else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.sessionIdentifierMismatch
        }
        guard !artifact.data.isEmpty else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        guard artifact.data.count <= maximumArtifactBytes else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.artifactTooLarge
        }

        let bytes = Array(artifact.data)
        guard bytes.count >= magic.count,
              Array(bytes.prefix(magic.count)) == magic else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.unsupportedArtifactFormat
        }
        var offset = magic.count

        let sessionLength64 = try readUInt64LE(bytes, offset: &offset)
        guard sessionLength64 <= 128 else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        let sessionLength = Int(sessionLength64)
        let sessionBytes = try readBytes(bytes, count: sessionLength, offset: &offset)
        guard let embeddedSession = String(bytes: sessionBytes, encoding: .utf8),
              let validatedSession = try? Lane3CandidatePhysicalResourceTraceAccumulator
                .validatedSessionIdentifier(embeddedSession),
              validatedSession == embeddedSession else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        guard embeddedSession == trace.sessionIdentifier,
              embeddedSession == artifact.sessionIdentifier else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.sessionIdentifierMismatch
        }

        let sampleCount64 = try readUInt64LE(bytes, offset: &offset)
        let remaining = bytes.count - offset
        guard remaining >= 0,
              remaining % recordSize == 0,
              sampleCount64 == UInt64(remaining / recordSize) else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        let sampleCount = Int(sampleCount64)
        guard sampleCount >= Lane3CandidatePhysicalResourceTraceAccumulator.minimumSamples else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.invalidSampleSemantics
        }

        var firstUptime: Double?
        var previousUptime: Double?
        var lastUptime: Double?
        var maximumGap = 0.0
        var peakRSS: UInt64 = 0
        var nominal = 0
        var fair = 0
        var serious = 0
        var critical = 0
        var firstBattery: Double?
        var lastBattery: Double?
        var externalPowerObserved = false

        for _ in 0..<sampleCount {
            let uptime = Double(bitPattern: try readUInt64LE(bytes, offset: &offset))
            let residentSetBytes = try readUInt64LE(bytes, offset: &offset)
            let thermalRaw = try readByte(bytes, offset: &offset)
            let battery = Double(bitPattern: try readUInt64LE(bytes, offset: &offset))
            let externalPowerRaw = try readByte(bytes, offset: &offset)

            guard uptime.isFinite, uptime >= 0,
                  residentSetBytes > 0,
                  battery.isFinite, (0...1).contains(battery),
                  let thermal = Lane3CandidatePhysicalThermalState(rawValue: thermalRaw),
                  externalPowerRaw == 0 || externalPowerRaw == 1 else {
                throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.invalidSampleSemantics
            }
            if let previousUptime {
                guard uptime > previousUptime else {
                    throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.invalidSampleSemantics
                }
                maximumGap = max(maximumGap, uptime - previousUptime)
            } else {
                firstUptime = uptime
                firstBattery = battery
            }
            previousUptime = uptime
            lastUptime = uptime
            lastBattery = battery
            peakRSS = max(peakRSS, residentSetBytes)
            externalPowerObserved = externalPowerObserved || externalPowerRaw == 1

            switch thermal {
            case .nominal: nominal += 1
            case .fair: fair += 1
            case .serious: serious += 1
            case .critical: critical += 1
            }
        }
        guard offset == bytes.count,
              let firstUptime,
              let lastUptime,
              let firstBattery,
              let lastBattery else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }

        let duration = lastUptime - firstUptime
        guard duration >= Lane3CandidatePhysicalResourceTraceAccumulator.minimumDurationSeconds,
              maximumGap > 0,
              maximumGap <= Lane3CandidatePhysicalResourceTraceAccumulator.maximumSamplingIntervalSeconds,
              !externalPowerObserved else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.invalidSampleSemantics
        }

        let summary = Lane3CandidateResourceArtifactSemanticSummary(
            sessionIdentifier: embeddedSession,
            observedDurationSeconds: duration,
            sampleCount: sampleCount,
            maximumSampleIntervalSeconds: maximumGap,
            peakRSSBytes: peakRSS,
            thermalNominalSamples: nominal,
            thermalFairSamples: fair,
            thermalSeriousSamples: serious,
            thermalCriticalSamples: critical,
            batteryStartLevel: firstBattery,
            batteryEndLevel: lastBattery,
            externalPowerConnectedDuringBatteryWindow: externalPowerObserved,
            artifactByteCount: bytes.count,
            traceArtifactSHA256: trace.traceArtifactSHA256
        )

        guard trace.observedDurationSeconds == summary.observedDurationSeconds,
              trace.sampleCount == summary.sampleCount,
              trace.maximumSampleIntervalSeconds == summary.maximumSampleIntervalSeconds,
              trace.peakRSSBytes == summary.peakRSSBytes,
              trace.thermalNominalSamples == summary.thermalNominalSamples,
              trace.thermalFairSamples == summary.thermalFairSamples,
              trace.thermalSeriousSamples == summary.thermalSeriousSamples,
              trace.thermalCriticalSamples == summary.thermalCriticalSamples,
              trace.batteryStartLevel == summary.batteryStartLevel,
              trace.batteryEndLevel == summary.batteryEndLevel,
              trace.externalPowerConnectedDuringBatteryWindow
                == summary.externalPowerConnectedDuringBatteryWindow else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.semanticMismatch
        }
        return summary
    }

    private static func readUInt64LE(_ bytes: [UInt8], offset: inout Int) throws -> UInt64 {
        guard offset >= 0, offset <= bytes.count, bytes.count - offset >= 8 else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        var value: UInt64 = 0
        for index in 0..<8 {
            value |= UInt64(bytes[offset + index]) << UInt64(index * 8)
        }
        offset += 8
        return value
    }

    private static func readByte(_ bytes: [UInt8], offset: inout Int) throws -> UInt8 {
        guard offset >= 0, offset < bytes.count else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        let value = bytes[offset]
        offset += 1
        return value
    }

    private static func readBytes(_ bytes: [UInt8], count: Int, offset: inout Int) throws -> [UInt8] {
        guard count >= 0,
              offset >= 0,
              offset <= bytes.count,
              count <= bytes.count - offset else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.malformedArtifact
        }
        let result = Array(bytes[offset..<(offset + count)])
        offset += count
        return result
    }
}

/// Persistable NON_PARITY proof that the candidate resource artifact's canonical binary semantics were
/// re-derived after the full committed-plan + raw-byte binding gate passed.
///
/// Current-Moises resource artifacts remain opaque at this layer because no canonical semantic encoding
/// for stock-Moises resource evidence exists in the repository. That limitation is encoded explicitly.
public struct Lane3PhysicalEvidenceHandoffCandidateSemanticHostReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let artifactBoundReceiptBindingSHA256: String
    public let candidateSemanticBindingSHA256: String
    public let candidateResourceSemanticsReDerived: Bool
    public let currentMoisesResourceSemanticsReDerived: Bool
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    private static let scope = "LANE3_HQ_CANDIDATE_RESOURCE_SEMANTIC_HANDOFF_RECEIPT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.scope,
              candidateResourceSemanticsReDerived,
              !currentMoisesResourceSemanticsReDerived,
              acceptedForHQReview,
              !parityPromotionAllowed,
              isLowercaseHex(artifactBoundReceiptBindingSHA256),
              isLowercaseHex(candidateSemanticBindingSHA256),
              isLowercaseHex(receiptBindingSHA256) else {
            return false
        }
        return receiptBindingSHA256 == Self.computeBinding(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            artifactBoundReceiptBindingSHA256: artifactBoundReceiptBindingSHA256,
            candidateSemanticBindingSHA256: candidateSemanticBindingSHA256
        )
    }

    fileprivate static func make(
        artifactBoundReceipt: Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt,
        candidateSummary: Lane3CandidateResourceArtifactSemanticSummary
    ) -> Self {
        let binding = computeBinding(
            sessionIdentifier: artifactBoundReceipt.sessionIdentifier,
            appBuildCommitSHA: artifactBoundReceipt.appBuildCommitSHA,
            artifactBoundReceiptBindingSHA256: artifactBoundReceipt.receiptBindingSHA256,
            candidateSemanticBindingSHA256: candidateSummary.semanticBindingSHA256
        )
        return Self(
            schemaVersion: 1,
            evidenceScope: scope,
            sessionIdentifier: artifactBoundReceipt.sessionIdentifier,
            appBuildCommitSHA: artifactBoundReceipt.appBuildCommitSHA,
            artifactBoundReceiptBindingSHA256: artifactBoundReceipt.receiptBindingSHA256,
            candidateSemanticBindingSHA256: candidateSummary.semanticBindingSHA256,
            candidateResourceSemanticsReDerived: true,
            currentMoisesResourceSemanticsReDerived: false,
            acceptedForHQReview: true,
            parityPromotionAllowed: false,
            receiptBindingSHA256: binding
        )
    }

    private static func computeBinding(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        artifactBoundReceiptBindingSHA256: String,
        candidateSemanticBindingSHA256: String
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_CANDIDATE_RESOURCE_SEMANTIC_HANDOFF_RECEIPT_V1",
            "1",
            scope,
            sessionIdentifier,
            appBuildCommitSHA,
            artifactBoundReceiptBindingSHA256,
            candidateSemanticBindingSHA256,
            "candidateSemantics=1",
            "currentMoisesSemantics=0",
            "acceptedForHQReview=1",
            "parityPromotionAllowed=0"
        ])
    }

    private func isLowercaseHex(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

public enum Lane3PhysicalEvidenceHandoffCandidateSemanticHostValidator {
    public static func validate(
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        resourceArtifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) throws -> Lane3PhysicalEvidenceHandoffCandidateSemanticHostReceipt {
        let artifactBoundReceipt: Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt
        do {
            artifactBoundReceipt = try Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator.validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces,
                resourceArtifacts: resourceArtifacts
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.artifactByteBindingRejected
        }

        let candidateTraces = resourceTraces.filter {
            $0.sessionIdentifier == plan.sessionIdentifier
                && $0.subject == .candidate
                && $0.scenario == .longTrackStability
        }
        guard candidateTraces.count == 1, let candidateTrace = candidateTraces.first else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.candidateTraceCardinality
        }
        let candidateArtifacts = resourceArtifacts.filter {
            $0.sessionIdentifier == plan.sessionIdentifier
                && $0.subject == .candidate
                && $0.scenario == .longTrackStability
        }
        guard candidateArtifacts.count == 1, let candidateArtifact = candidateArtifacts.first else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.candidateArtifactCardinality
        }

        let summary: Lane3CandidateResourceArtifactSemanticSummary
        do {
            summary = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: candidateTrace,
                artifact: candidateArtifact
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.semanticMismatch
        }
        let result = Lane3PhysicalEvidenceHandoffCandidateSemanticHostReceipt.make(
            artifactBoundReceipt: artifactBoundReceipt,
            candidateSummary: summary
        )
        guard result.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError.receiptIntegrityFailure
        }
        return result
    }

    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffCandidateSemanticHostReceipt,
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        resourceArtifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) -> Bool {
        guard receipt.verifyIntegrity() else { return false }
        do {
            return try validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces,
                resourceArtifacts: resourceArtifacts
            ) == receipt
        } catch {
            return false
        }
    }
}
