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
    public let referenceDigestSHA256: String
    public let observedDigestSHA256: String
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
            algorithm: "SHA256_FLOAT32_LE_V1",
            referenceDigestSHA256: digest(reference),
            observedDigestSHA256: digest(observed),
            channels: reference.channels,
            sampleRate: reference.sampleRate,
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount
        )
    }

    private static func digest(_ pcm: Lane3PCMBufferDescriptor) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(64 + pcm.interleavedSamples.count * 4)
        append("LANE3_PCM_IDENTITY_V1", to: &bytes)
        append(UInt64(pcm.channels), byteCount: 8, to: &bytes)
        append(pcm.sampleRate.bitPattern, byteCount: 8, to: &bytes)
        append(UInt64(pcm.frameCount), byteCount: 8, to: &bytes)
        append(UInt64(pcm.interleavedSamples.count), byteCount: 8, to: &bytes)
        for sample in pcm.interleavedSamples {
            append(UInt64(sample.bitPattern), byteCount: 4, to: &bytes)
        }
        return SHA256.hexDigest(bytes)
    }

    fileprivate static func digestFields(_ fields: [String]) -> String {
        var bytes: [UInt8] = []
        append("LANE3_UNIFIED_RUN_BINDING_V2", to: &bytes)
        for field in fields { append(field, to: &bytes) }
        return SHA256.hexDigest(bytes)
    }

    private static func append(_ string: String, to bytes: inout [UInt8]) {
        bytes.append(contentsOf: string.utf8)
        bytes.append(0xff)
    }

    private static func append(_ value: UInt64, byteCount: Int, to bytes: inout [UInt8]) {
        for offset in 0..<byteCount {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(offset * 8)))
        }
    }

    private enum SHA256 {
        private static let initial: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
        private static let constants: [UInt32] = [
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
            0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
            0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
            0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
            0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
            0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
        ]

        static func hexDigest(_ input: [UInt8]) -> String {
            let digest = hash(input)
            return digest.map { String(format: "%02x", $0) }.joined()
        }

        private static func hash(_ input: [UInt8]) -> [UInt8] {
            var message = input
            let bitLength = UInt64(message.count) * 8
            message.append(0x80)
            while message.count % 64 != 56 { message.append(0) }
            for shift in stride(from: 56, through: 0, by: -8) {
                message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
            }

            var h = initial
            var w = [UInt32](repeating: 0, count: 64)
            for chunkStart in stride(from: 0, to: message.count, by: 64) {
                for index in 0..<16 {
                    let offset = chunkStart + index * 4
                    w[index] = (UInt32(message[offset]) << 24)
                        | (UInt32(message[offset + 1]) << 16)
                        | (UInt32(message[offset + 2]) << 8)
                        | UInt32(message[offset + 3])
                }
                for index in 16..<64 {
                    let s0 = rotateRight(w[index - 15], by: 7)
                        ^ rotateRight(w[index - 15], by: 18)
                        ^ (w[index - 15] >> 3)
                    let s1 = rotateRight(w[index - 2], by: 17)
                        ^ rotateRight(w[index - 2], by: 19)
                        ^ (w[index - 2] >> 10)
                    w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
                }

                var a = h[0], b = h[1], c = h[2], d = h[3]
                var e = h[4], f = h[5], g = h[6], hh = h[7]
                for index in 0..<64 {
                    let s1 = rotateRight(e, by: 6) ^ rotateRight(e, by: 11) ^ rotateRight(e, by: 25)
                    let ch = (e & f) ^ ((~e) & g)
                    let temp1 = hh &+ s1 &+ ch &+ constants[index] &+ w[index]
                    let s0 = rotateRight(a, by: 2) ^ rotateRight(a, by: 13) ^ rotateRight(a, by: 22)
                    let maj = (a & b) ^ (a & c) ^ (b & c)
                    let temp2 = s0 &+ maj
                    hh = g
                    g = f
                    f = e
                    e = d &+ temp1
                    d = c
                    c = b
                    b = a
                    a = temp1 &+ temp2
                }
                h[0] &+= a
                h[1] &+= b
                h[2] &+= c
                h[3] &+= d
                h[4] &+= e
                h[5] &+= f
                h[6] &+= g
                h[7] &+= hh
            }

            var output: [UInt8] = []
            output.reserveCapacity(32)
            for word in h {
                output.append(UInt8(truncatingIfNeeded: word >> 24))
                output.append(UInt8(truncatingIfNeeded: word >> 16))
                output.append(UInt8(truncatingIfNeeded: word >> 8))
                output.append(UInt8(truncatingIfNeeded: word))
            }
            return output
        }

        private static func rotateRight(_ value: UInt32, by amount: UInt32) -> UInt32 {
            (value >> amount) | (value << (32 - amount))
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
    public let runBindingSHA256: String
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
            pcmIdentity.referenceDigestSHA256,
            pcmIdentity.observedDigestSHA256,
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
            runBindingSHA256: runBinding,
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
