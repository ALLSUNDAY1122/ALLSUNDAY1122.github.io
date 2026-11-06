import Foundation

@main
struct L3HQPhysicalEvidenceHandoffCandidateSemanticValidatorSelfTestMain {
    static func main() throws {
        let session = "hq-candidate-semantic-session"
        let fixture = try makeFixture(sessionIdentifier: session)
        let artifact = Lane3PhysicalEvidenceHandoffResourceArtifact(
            sessionIdentifier: session,
            subject: .candidate,
            scenario: .longTrackStability,
            data: fixture.artifact
        )

        let accepted = try Lane3CandidateResourceArtifactSemanticDecoder
            .validatePreviouslyByteBoundArtifact(trace: fixture.trace, artifact: artifact)
        precondition(accepted.sessionIdentifier == session)
        precondition(accepted.sampleCount == 121)
        precondition(accepted.observedDurationSeconds == 1_800)
        precondition(accepted.maximumSampleIntervalSeconds == 15)
        precondition(accepted.peakRSSBytes == 100_000_000 + UInt64(120) * 4_096)
        precondition(accepted.thermalNominalSamples == 31)
        precondition(accepted.thermalFairSamples == 30)
        precondition(accepted.thermalSeriousSamples == 30)
        precondition(accepted.thermalCriticalSamples == 30)
        precondition(accepted.batteryStartLevel == 0.9)
        precondition(accepted.batteryEndLevel == 0.9 - Double(120) * 0.001)
        precondition(!accepted.externalPowerConnectedDuringBatteryWindow)
        precondition(accepted.artifactByteCount == fixture.artifact.count)
        precondition(isLowercaseHex(accepted.semanticBindingSHA256))

        let wrongPeak = copyTrace(
            fixture.trace,
            peakRSSBytes: fixture.trace.peakRSSBytes + 1
        )
        try expectError(.semanticMismatch) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder
                .validatePreviouslyByteBoundArtifact(trace: wrongPeak, artifact: artifact)
        }

        var wrongMagicBytes = [UInt8](fixture.artifact)
        wrongMagicBytes[0] ^= 0xff
        try expectError(.unsupportedArtifactFormat) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: fixture.trace,
                artifact: artifactReplacingData(artifact, Data(wrongMagicBytes))
            )
        }

        var trailingBytes = [UInt8](fixture.artifact)
        trailingBytes.append(0)
        try expectError(.malformedArtifact) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: fixture.trace,
                artifact: artifactReplacingData(artifact, Data(trailingBytes))
            )
        }

        let otherFixture = try makeFixture(sessionIdentifier: "other-semantic-session")
        try expectError(.sessionIdentifierMismatch) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: fixture.trace,
                artifact: artifactReplacingData(artifact, otherFixture.artifact)
            )
        }

        let firstRecordOffset = Array("LANE3_AW52_CANDIDATE_RESOURCE_TRACE_V1\0".utf8).count
            + 8 + session.utf8.count + 8
        var invalidThermalBytes = [UInt8](fixture.artifact)
        invalidThermalBytes[firstRecordOffset + 16] = 0xff
        try expectError(.invalidSampleSemantics) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: fixture.trace,
                artifact: artifactReplacingData(artifact, Data(invalidThermalBytes))
            )
        }

        var externallyPoweredBytes = [UInt8](fixture.artifact)
        externallyPoweredBytes[firstRecordOffset + 25] = 1
        try expectError(.invalidSampleSemantics) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: fixture.trace,
                artifact: artifactReplacingData(artifact, Data(externallyPoweredBytes))
            )
        }

        let referenceTrace = copyTrace(fixture.trace, subject: .currentMoisesReference)
        let referenceArtifact = Lane3PhysicalEvidenceHandoffResourceArtifact(
            sessionIdentifier: session,
            subject: .currentMoisesReference,
            scenario: .longTrackStability,
            data: fixture.artifact
        )
        try expectError(.semanticMismatch) {
            _ = try Lane3CandidateResourceArtifactSemanticDecoder.validatePreviouslyByteBoundArtifact(
                trace: referenceTrace,
                artifact: referenceArtifact
            )
        }

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_CANDIDATE_SEMANTIC_VALIDATOR_SELF_TEST_PASS canonicalBinaryDecoded=true statsRederived=true malformedRejected=true sessionMismatchRejected=true invalidThermalRejected=true poweredWindowRejected=true currentMoisesSemanticsNotClaimed=true nonParity=true")
    }

    private struct Fixture {
        let artifact: Data
        let trace: Lane3PhysicalEvidenceResourceTraceReceipt
    }

    private static func makeFixture(sessionIdentifier: String) throws -> Fixture {
        var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
        for index in 0...120 {
            let thermal: Lane3CandidatePhysicalThermalState
            switch index % 4 {
            case 0: thermal = .nominal
            case 1: thermal = .fair
            case 2: thermal = .serious
            default: thermal = .critical
            }
            try accumulator.append(Lane3CandidatePhysicalResourceSample(
                uptimeSeconds: 1_000 + Double(index) * 15,
                residentSetBytes: 100_000_000 + UInt64(index) * 4_096,
                thermalState: thermal,
                batteryLevel: 0.9 - Double(index) * 0.001,
                externalPowerConnected: false
            ))
        }
        let artifact = try accumulator.canonicalArtifactData(sessionIdentifier: sessionIdentifier)
        let trace = try accumulator.makeAW51CandidateReceipt(
            sessionIdentifier: sessionIdentifier,
            traceArtifactSHA256: String(repeating: "a", count: 64)
        )
        return Fixture(artifact: artifact, trace: trace)
    }

    private static func copyTrace(
        _ trace: Lane3PhysicalEvidenceResourceTraceReceipt,
        subject: Lane3PhysicalEvidenceResourceSubject? = nil,
        peakRSSBytes: UInt64? = nil
    ) -> Lane3PhysicalEvidenceResourceTraceReceipt {
        Lane3PhysicalEvidenceResourceTraceReceipt(
            sessionIdentifier: trace.sessionIdentifier,
            subject: subject ?? trace.subject,
            scenario: trace.scenario,
            observedDurationSeconds: trace.observedDurationSeconds,
            sampleCount: trace.sampleCount,
            maximumSampleIntervalSeconds: trace.maximumSampleIntervalSeconds,
            peakRSSBytes: peakRSSBytes ?? trace.peakRSSBytes,
            thermalNominalSamples: trace.thermalNominalSamples,
            thermalFairSamples: trace.thermalFairSamples,
            thermalSeriousSamples: trace.thermalSeriousSamples,
            thermalCriticalSamples: trace.thermalCriticalSamples,
            batteryStartLevel: trace.batteryStartLevel,
            batteryEndLevel: trace.batteryEndLevel,
            externalPowerConnectedDuringBatteryWindow: trace.externalPowerConnectedDuringBatteryWindow,
            traceArtifactSHA256: trace.traceArtifactSHA256
        )
    }

    private static func artifactReplacingData(
        _ artifact: Lane3PhysicalEvidenceHandoffResourceArtifact,
        _ data: Data
    ) -> Lane3PhysicalEvidenceHandoffResourceArtifact {
        Lane3PhysicalEvidenceHandoffResourceArtifact(
            sessionIdentifier: artifact.sessionIdentifier,
            subject: artifact.subject,
            scenario: artifact.scenario,
            data: data
        )
    }

    private static func expectError(
        _ expected: Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            preconditionFailure("expected \(expected)")
        } catch let error as Lane3PhysicalEvidenceHandoffCandidateSemanticValidationError {
            precondition(error == expected, "expected \(expected), got \(error)")
        }
    }

    private static func isLowercaseHex(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}
