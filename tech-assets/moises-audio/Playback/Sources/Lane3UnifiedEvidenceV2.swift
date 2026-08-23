import Foundation

public enum Lane3UnifiedEvidenceV2Error: Error, Equatable, Sendable {
    case invalidProductionGenerationReceipt
    case staleProductionGenerationReceipt
    case invalidRecoveryLineageReceipt
    case generationLineageMismatch(
        productionPlayback: UInt64,
        productionClick: UInt64,
        recoveryPlayback: UInt64,
        recoveryClick: UInt64
    )
    case reasonLineageMismatch(production: String, recovery: String)
    case invalidPCMIdentity
    case envelopeAlignmentMismatch(coreLag: Int, envelopeLag: Int)
    case sourceEvidenceScopeRejected(String)
    case componentClaimRejected
    case noEnvelopeWindows
    case nonFiniteEvidence(reference: Int64, observed: Int64)
    case invalidMetric
}

public struct Lane3ProductionGenerationEvidenceReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt
    public let snapshotOperationSerial: UInt64
    public let activePlaybackGeneration: UInt64
    public let activeClickGeneration: UInt64
    public let activeReason: String
    public let currentBindingValidated: Bool
    public let parityPromotionAllowed: Bool

    public init(
        coordinatorReceipt: PracticeDSPGenerationCoordinatorReceipt,
        snapshotOperationSerial: UInt64,
        activePlaybackGeneration: UInt64,
        activeClickGeneration: UInt64,
        activeReason: String,
        currentBindingValidated: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW12_CURRENT_PRODUCTION_GENERATION_RECEIPT_NON_PARITY"
        self.coordinatorReceipt = coordinatorReceipt
        self.snapshotOperationSerial = snapshotOperationSerial
        self.activePlaybackGeneration = activePlaybackGeneration
        self.activeClickGeneration = activeClickGeneration
        self.activeReason = activeReason
        self.currentBindingValidated = currentBindingValidated
        self.parityPromotionAllowed = false
    }
}

public enum Lane3ProductionGenerationEvidenceCapture {
    public static func capture(
        coordinator: PracticeDSPGenerationCoordinator,
        receipt: PracticeDSPGenerationCoordinatorReceipt
    ) async throws -> Lane3ProductionGenerationEvidenceReceipt {
        try validateAuthorizingReceipt(receipt)
        let snapshot = try await coordinator.snapshot()
        guard !snapshot.isPoisoned,
              snapshot.operationSerial == receipt.operationSerial,
              let binding = snapshot.activeBinding,
              binding.playbackGeneration == receipt.playbackGeneration,
              binding.clickGeneration == receipt.clickGeneration,
              binding.reason.rawValue == receipt.reason else {
            throw Lane3UnifiedEvidenceV2Error.staleProductionGenerationReceipt
        }
        return Lane3ProductionGenerationEvidenceReceipt(
            coordinatorReceipt: receipt,
            snapshotOperationSerial: snapshot.operationSerial,
            activePlaybackGeneration: binding.playbackGeneration,
            activeClickGeneration: binding.clickGeneration,
            activeReason: binding.reason.rawValue,
            currentBindingValidated: true
        )
    }

    static func validateAuthorizingReceipt(
        _ receipt: PracticeDSPGenerationCoordinatorReceipt
    ) throws {
        guard receipt.schemaVersion == 1,
              receipt.evidenceScope == "LANE3_PRODUCTION_COMBINED_GENERATION_NON_PARITY",
              receipt.operationSerial > 0,
              let playbackGeneration = receipt.playbackGeneration,
              playbackGeneration > 0,
              receipt.clickGeneration > 0,
              let reason = receipt.reason,
              !reason.isEmpty,
              receipt.replacementBindingActive,
              !receipt.parityPromotionAllowed else {
            throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
        }

        switch receipt.mutationKind {
        case .transportDiscontinuity:
            guard reason != "tempoChange", reason != "recovery" else {
                throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
            }
        case .tempoChange:
            guard reason == "tempoChange" else {
                throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
            }
        case .recovery:
            guard reason == "recovery" else {
                throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
            }
        case .metronomeChange, .countInSchedule:
            throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
        }
    }
}

public struct Lane3PCMIdentityReceipt: Equatable, Codable, Sendable {
    public let algorithm: String
    public let referenceDigestFNV1A64: String
    public let observedDigestFNV1A64: String
    public let channels: Int
    public let sampleRate: Double
    public let referenceFrameCount: Int64
    public let observedFrameCount: Int64
}

public enum Lane3PCMIdentityHasher {
    public static func makeReceipt(
        reference: Lane3PCMBufferDescriptor,
        observed: Lane3PCMBufferDescriptor
    ) throws -> Lane3PCMIdentityReceipt {
        guard reference.channels > 0,
              observed.channels == reference.channels,
              reference.sampleRate.isFinite,
              observed.sampleRate.isFinite,
              reference.sampleRate > 0,
              abs(reference.sampleRate - observed.sampleRate) <= 0.5,
              reference.frameCount > 0,
              observed.frameCount > 0,
              reference.interleavedSamples.count % reference.channels == 0,
              observed.interleavedSamples.count % observed.channels == 0 else {
            throw Lane3UnifiedEvidenceV2Error.invalidPCMIdentity
        }
        return Lane3PCMIdentityReceipt(
            algorithm: "FNV1A64_FLOAT32_LE_V1",
            referenceDigestFNV1A64: digest(reference),
            observedDigestFNV1A64: digest(observed),
            channels: reference.channels,
            sampleRate: reference.sampleRate,
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount
        )
    }

    private static func digest(_ pcm: Lane3PCMBufferDescriptor) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        feed("LANE3_PCM_IDENTITY_V1", into: &hash)
        feed(UInt64(pcm.channels), into: &hash)
        feed(pcm.sampleRate.bitPattern, into: &hash)
        feed(UInt64(pcm.frameCount), into: &hash)
        feed(UInt64(pcm.interleavedSamples.count), into: &hash)
        for sample in pcm.interleavedSamples {
            feed(UInt64(sample.bitPattern), byteCount: 4, into: &hash)
        }
        return String(format: "%016llx", hash)
    }

    fileprivate static func digestFields(_ fields: [String]) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        feed("LANE3_UNIFIED_RUN_BINDING_V2", into: &hash)
        for field in fields { feed(field, into: &hash) }
        return String(format: "%016llx", hash)
    }

    private static func feed(_ string: String, into hash: inout UInt64) {
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        hash ^= 0xff
        hash &*= 0x100000001b3
    }

    private static func feed(_ value: UInt64, byteCount: Int = 8, into hash: inout UInt64) {
        for offset in 0..<byteCount {
            let byte = UInt8(truncatingIfNeeded: value >> UInt64(offset * 8))
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
    }
}

public struct Lane3EnvelopeEvidenceSnapshot: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let globalLagFramesApplied: Int
    public let windowsAnalyzed: Int
    public let cepstralCoefficientCount: Int
    public let meanEnvelopeRMSEDB: Double
    public let p95EnvelopeRMSEDB: Double
    public let meanEnvelopeCorrelation: Double
    public let meanAbsoluteSpectralTiltDeltaDBPerOctave: Double
    public let matchedFormantPeakCount: Int
    public let medianAbsoluteFormantPeakErrorCents: Double?
    public let p95AbsoluteFormantPeakErrorCents: Double?
    public let referenceNonFiniteSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let standardizedPerceptualClaimAllowed: Bool
    public let formantPreservationClaimAllowed: Bool
    public let componentParityPromotionAllowed: Bool

    public init(report: Lane3CepstralEnvelopeDifferentialReport) {
        self.evidenceScope = report.evidenceScope
        self.globalLagFramesApplied = report.globalLagFramesApplied
        self.windowsAnalyzed = report.windowsAnalyzed
        self.cepstralCoefficientCount = report.cepstralCoefficientCount
        self.meanEnvelopeRMSEDB = report.meanEnvelopeRMSEDB
        self.p95EnvelopeRMSEDB = report.p95EnvelopeRMSEDB
        self.meanEnvelopeCorrelation = report.meanEnvelopeCorrelation
        self.meanAbsoluteSpectralTiltDeltaDBPerOctave = report.meanAbsoluteSpectralTiltDeltaDBPerOctave
        self.matchedFormantPeakCount = report.formantPeakMatches.count
        self.medianAbsoluteFormantPeakErrorCents = report.medianAbsoluteFormantPeakErrorCents
        self.p95AbsoluteFormantPeakErrorCents = report.p95AbsoluteFormantPeakErrorCents
        self.referenceNonFiniteSampleCount = report.referenceNonFiniteSampleCount
        self.observedNonFiniteSampleCount = report.observedNonFiniteSampleCount
        self.standardizedPerceptualClaimAllowed = report.standardizedPerceptualClaimAllowed
        self.formantPreservationClaimAllowed = report.formantPreservationClaimAllowed
        self.componentParityPromotionAllowed = report.parityPromotionAllowed
    }
}

public struct Lane3UnifiedEvidenceReportV2: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let comparisonIntent: Lane3EvidenceComparisonIntent
    public let productionGeneration: Lane3ProductionGenerationEvidenceReceipt
    public let recoveryLineage: Lane3CombinedRecoveryAW05Receipt
    public let pcmIdentity: Lane3PCMIdentityReceipt
    public let coreEvidence: Lane3IntegratedEvidenceReport
    public let envelope: Lane3EnvelopeEvidenceSnapshot
    public let runBindingFNV1A64: String
    public let sourceEvidenceScopes: [String]
    public let readyForRealAudioReview: Bool
    public let humanAudibilityClaimed: Bool
    public let standardizedPerceptualMetricClaimed: Bool
    public let formantPreservationClaimed: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3UnifiedEvidencePipelineV2 {
    public static func analyze(
        productionGeneration: Lane3ProductionGenerationEvidenceReceipt,
        recoveryLineage: Lane3CombinedRecoveryAW05Receipt,
        offline: Lane3OfflineEvidenceReceipt,
        referencePCM: Lane3PCMBufferDescriptor,
        observedPCM: Lane3PCMBufferDescriptor,
        expectedEventFrames: [Int64],
        comparisonIntent: Lane3EvidenceComparisonIntent,
        timeConfiguration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        spectralConfiguration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration(),
        envelopeConfiguration: Lane3CepstralEnvelopeConfiguration = Lane3CepstralEnvelopeConfiguration()
    ) throws -> Lane3UnifiedEvidenceReportV2 {
        try validateProductionGeneration(productionGeneration)
        try validateRecoveryLineage(recoveryLineage, production: productionGeneration)

        let timeReport = try Lane3PCMDifferentialAnalyzer.analyze(
            reference: referencePCM,
            observed: observedPCM,
            expectedEventFrames: expectedEventFrames,
            configuration: timeConfiguration
        )
        let spectralReport = try Lane3SpectralPerceptualDifferentialAnalyzer.analyze(
            reference: referencePCM,
            observed: observedPCM,
            globalLagFrames: timeReport.globalLagFrames,
            configuration: spectralConfiguration
        )
        let envelopeReport = try Lane3CepstralEnvelopeDifferentialAnalyzer.analyze(
            reference: referencePCM,
            observed: observedPCM,
            globalLagFrames: timeReport.globalLagFrames,
            configuration: envelopeConfiguration
        )

        let receipt = productionGeneration.coordinatorReceipt
        let projectedTransport = Lane3TransportEvidenceReceipt(
            playbackGeneration: productionGeneration.activePlaybackGeneration,
            clickGeneration: productionGeneration.activeClickGeneration,
            transactionSerial: receipt.operationSerial,
            reason: productionGeneration.activeReason,
            gateValidatedCurrentBinding: productionGeneration.currentBindingValidated
        )
        let core = try Lane3IntegratedEvidenceAssembler.assemble(
            comparisonIntent: comparisonIntent,
            transport: projectedTransport,
            offline: offline,
            referencePCMFrameCount: referencePCM.frameCount,
            observedPCMFrameCount: observedPCM.frameCount,
            observedPCMSampleRate: observedPCM.sampleRate,
            expectedEventCount: expectedEventFrames.count,
            timeDomain: Lane3TimeDomainEvidenceSnapshot(report: timeReport),
            spectral: Lane3SpectralEvidenceSnapshot(report: spectralReport)
        )

        let envelope = Lane3EnvelopeEvidenceSnapshot(report: envelopeReport)
        try validateEnvelope(envelope, core: core)
        let pcmIdentity = try Lane3PCMIdentityHasher.makeReceipt(
            reference: referencePCM,
            observed: observedPCM
        )

        let runBinding = Lane3PCMIdentityHasher.digestFields([
            offline.fixtureID,
            offline.controlSignatureFNV1A64,
            String(productionGeneration.activePlaybackGeneration),
            String(productionGeneration.activeClickGeneration),
            productionGeneration.activeReason,
            String(receipt.operationSerial),
            pcmIdentity.algorithm,
            pcmIdentity.referenceDigestFNV1A64,
            pcmIdentity.observedDigestFNV1A64,
            String(timeReport.globalLagFrames),
            String(envelope.windowsAnalyzed),
            String(expectedEventFrames.count)
        ])

        return Lane3UnifiedEvidenceReportV2(
            schemaVersion: 2,
            evidenceScope: "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY",
            fixtureID: offline.fixtureID,
            controlSignatureFNV1A64: offline.controlSignatureFNV1A64,
            comparisonIntent: comparisonIntent,
            productionGeneration: productionGeneration,
            recoveryLineage: recoveryLineage,
            pcmIdentity: pcmIdentity,
            coreEvidence: core,
            envelope: envelope,
            runBindingFNV1A64: runBinding,
            sourceEvidenceScopes: core.sourceEvidenceScopes + [
                envelope.evidenceScope,
                recoveryLineage.evidenceScope,
                productionGeneration.evidenceScope,
                receipt.evidenceScope
            ],
            readyForRealAudioReview: true,
            humanAudibilityClaimed: false,
            standardizedPerceptualMetricClaimed: false,
            formantPreservationClaimed: false,
            parityPromotionAllowed: false
        )
    }

    private static func validateProductionGeneration(
        _ production: Lane3ProductionGenerationEvidenceReceipt
    ) throws {
        try Lane3ProductionGenerationEvidenceCapture.validateAuthorizingReceipt(
            production.coordinatorReceipt
        )
        let receipt = production.coordinatorReceipt
        guard production.schemaVersion == 1,
              production.evidenceScope == "LANE3_AW12_CURRENT_PRODUCTION_GENERATION_RECEIPT_NON_PARITY",
              production.snapshotOperationSerial == receipt.operationSerial,
              production.activePlaybackGeneration == receipt.playbackGeneration,
              production.activeClickGeneration == receipt.clickGeneration,
              production.activeReason == receipt.reason,
              production.currentBindingValidated,
              !production.parityPromotionAllowed else {
            throw Lane3UnifiedEvidenceV2Error.invalidProductionGenerationReceipt
        }
    }

    private static func validateRecoveryLineage(
        _ recovery: Lane3CombinedRecoveryAW05Receipt,
        production: Lane3ProductionGenerationEvidenceReceipt
    ) throws {
        guard recovery.evidenceScope == "LANE3_AW05_TO_AW11_GENERATION_RECEIPT_NON_PARITY",
              recovery.playbackGeneration > 0,
              recovery.clickGeneration > 0,
              !recovery.parityPromotionAllowed else {
            throw Lane3UnifiedEvidenceV2Error.invalidRecoveryLineageReceipt
        }
        guard recovery.playbackGeneration == production.activePlaybackGeneration,
              recovery.clickGeneration == production.activeClickGeneration else {
            throw Lane3UnifiedEvidenceV2Error.generationLineageMismatch(
                productionPlayback: production.activePlaybackGeneration,
                productionClick: production.activeClickGeneration,
                recoveryPlayback: recovery.playbackGeneration,
                recoveryClick: recovery.clickGeneration
            )
        }
        guard recovery.reason.rawValue == production.activeReason else {
            throw Lane3UnifiedEvidenceV2Error.reasonLineageMismatch(
                production: production.activeReason,
                recovery: recovery.reason.rawValue
            )
        }
    }

    private static func validateEnvelope(
        _ envelope: Lane3EnvelopeEvidenceSnapshot,
        core: Lane3IntegratedEvidenceReport
    ) throws {
        guard envelope.evidenceScope == "LANE3_CEPSTRAL_ENVELOPE_FORMANT_PROXY_NON_PARITY" else {
            throw Lane3UnifiedEvidenceV2Error.sourceEvidenceScopeRejected(envelope.evidenceScope)
        }
        guard !envelope.standardizedPerceptualClaimAllowed,
              !envelope.formantPreservationClaimAllowed,
              !envelope.componentParityPromotionAllowed else {
            throw Lane3UnifiedEvidenceV2Error.componentClaimRejected
        }
        guard envelope.globalLagFramesApplied == core.timeDomain.globalLagFrames else {
            throw Lane3UnifiedEvidenceV2Error.envelopeAlignmentMismatch(
                coreLag: core.timeDomain.globalLagFrames,
                envelopeLag: envelope.globalLagFramesApplied
            )
        }
        guard envelope.windowsAnalyzed > 0 else {
            throw Lane3UnifiedEvidenceV2Error.noEnvelopeWindows
        }
        guard envelope.referenceNonFiniteSampleCount == 0,
              envelope.observedNonFiniteSampleCount == 0 else {
            throw Lane3UnifiedEvidenceV2Error.nonFiniteEvidence(
                reference: envelope.referenceNonFiniteSampleCount,
                observed: envelope.observedNonFiniteSampleCount
            )
        }
        var metrics = [
            envelope.meanEnvelopeRMSEDB,
            envelope.p95EnvelopeRMSEDB,
            envelope.meanEnvelopeCorrelation,
            envelope.meanAbsoluteSpectralTiltDeltaDBPerOctave
        ]
        if let value = envelope.medianAbsoluteFormantPeakErrorCents { metrics.append(value) }
        if let value = envelope.p95AbsoluteFormantPeakErrorCents { metrics.append(value) }
        guard envelope.cepstralCoefficientCount > 0,
              metrics.allSatisfy(\.isFinite) else {
            throw Lane3UnifiedEvidenceV2Error.invalidMetric
        }
    }
}
