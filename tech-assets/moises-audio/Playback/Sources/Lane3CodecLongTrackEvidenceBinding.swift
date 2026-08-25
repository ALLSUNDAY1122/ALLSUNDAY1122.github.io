import Foundation

public enum Lane3CodecLongTrackSourceRole: String, Codable, Sendable {
    case reference
    case observed
}

public enum Lane3CodecLongTrackEvidenceBindingError: Error, Equatable, Sendable {
    case invalidCleanReport
    case invalidTruncatedReport
    case invalidCorruptedReport
    case codecFamilyMismatch
    case baselineMetadataMismatch
    case duplicateFixtureID
    case cleanReportReexecutionMismatch
    case invalidLongTrackResult
    case invalidLongTrackCompletion
    case completionRunBindingMismatch
    case targetPCMIdentityMismatch
    case invalidBindingReceipt
}

public struct Lane3CodecLongTrackEvidenceBindingReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sourceRole: Lane3CodecLongTrackSourceRole
    public let declaredCodecLabel: String
    public let cleanFixtureID: String
    public let truncatedFixtureID: String
    public let corruptedFixtureID: String
    public let cleanReportBindingSHA256: String
    public let truncatedReportBindingSHA256: String
    public let corruptedReportBindingSHA256: String
    public let codecFamilyBindingSHA256: String
    public let cleanReportReexecutionMatched: Bool
    public let cleanPCMIdentityAlgorithm: String
    public let cleanPCMIdentitySHA256: String
    public let longTrackTargetPCMIdentitySHA256: String
    public let targetPCMIdentityMatched: Bool
    public let aw30RunBindingSHA256: String
    public let aw30CompletionBindingSHA256: String
    public let completionRunBindingMatched: Bool
    public let combinedBindingSHA256: String
    public let codecFamilyContractComplete: Bool
    public let codecFamilyPhysicalIPhoneComplete: Bool
    public let derivativeLineageCryptographicallyProven: Bool
    public let rawPCMIncluded: Bool
    public let rawCompressedBytesIncluded: Bool
    public let sourcePathIncluded: Bool
    public let authenticitySignatureIncluded: Bool
    public let authoritativePhysicalEvidenceAllowed: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3CodecLongTrackEvidenceBinder {
    public static func makeReceipt(
        cleanSource: any Lane3PCMChunkReadable,
        sourceRole: Lane3CodecLongTrackSourceRole,
        cleanReport: Lane3RepresentativeCodecExecutionReport,
        truncatedReport: Lane3RepresentativeCodecExecutionReport,
        corruptedReport: Lane3RepresentativeCodecExecutionReport,
        longTrackResult: Lane3LongTrackUnifiedEvidenceResult,
        completion: Lane3LongTrackEvidenceCompletionReceipt,
        identityChunkFrames: Int = 16_384
    ) throws -> Lane3CodecLongTrackEvidenceBindingReceipt {
        try validateCodecFamily(
            clean: cleanReport,
            truncated: truncatedReport,
            corrupted: corruptedReport
        )

        guard !longTrackResult.parityPromotionAllowed,
              !longTrackResult.reportV2.parityPromotionAllowed,
              longTrackResult.reportV2.schemaVersion == 2,
              longTrackResult.reportV2.evidenceScope == "LANE3_UNIFIED_PLAYBACK_DSP_EVIDENCE_V2_NON_PARITY" else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidLongTrackResult
        }

        do {
            _ = try Lane3LongTrackEvidenceCompletionValidator.validate(completion)
        } catch {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidLongTrackCompletion
        }
        let expectedLongTrackRunBinding = longTrackRunBindingSHA256(longTrackResult.reportV2)
        guard expectedLongTrackRunBinding == longTrackResult.reportV2.runBindingSHA256 else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidLongTrackResult
        }
        guard completion.runBindingSHA256 == longTrackResult.reportV2.runBindingSHA256 else {
            throw Lane3CodecLongTrackEvidenceBindingError.completionRunBindingMismatch
        }

        let cleanReexecution = try Lane3RepresentativeCodecExecutionProbe.sweep(
            source: cleanSource,
            descriptor: cleanReport.fixture,
            environment: cleanReport.environment,
            chunkFrames: cleanReport.maximumChunkFrames
        )
        guard cleanReexecution == cleanReport else {
            throw Lane3CodecLongTrackEvidenceBindingError.cleanReportReexecutionMismatch
        }

        let selfIdentity = try Lane3LongTrackPCMIdentityHasher.makeReceipt(
            reference: cleanSource,
            observed: cleanSource,
            chunkFrames: identityChunkFrames
        )
        guard selfIdentity.algorithm == "SHA256_FLOAT32_LE_V1",
              selfIdentity.referenceDigestSHA256 == selfIdentity.observedDigestSHA256,
              selfIdentity.referenceFrameCount == selfIdentity.observedFrameCount,
              selfIdentity.channels == cleanReport.fixture.expectedChannels,
              selfIdentity.sampleRate.bitPattern == cleanReport.fixture.expectedSampleRate.bitPattern,
              selfIdentity.referenceFrameCount == cleanReport.fixture.baselineFrameCount else {
            throw Lane3CodecLongTrackEvidenceBindingError.targetPCMIdentityMismatch
        }

        let targetDigest: String
        let targetFrameCount: Int64
        switch sourceRole {
        case .reference:
            targetDigest = longTrackResult.reportV2.pcmIdentity.referenceDigestSHA256
            targetFrameCount = longTrackResult.reportV2.pcmIdentity.referenceFrameCount
        case .observed:
            targetDigest = longTrackResult.reportV2.pcmIdentity.observedDigestSHA256
            targetFrameCount = longTrackResult.reportV2.pcmIdentity.observedFrameCount
        }
        let targetMetadataMatches: Bool
        switch sourceRole {
        case .reference:
            targetMetadataMatches = longTrackResult.reportV2.pcmIdentity.channels == selfIdentity.channels
                && longTrackResult.reportV2.pcmIdentity.sampleRate.bitPattern == selfIdentity.sampleRate.bitPattern
        case .observed:
            // Lane3PCMIdentityReceipt.sampleRate is the reference-side rate; the observed digest itself
            // includes the observed source sample-rate bit pattern, so digest equality is authoritative here.
            targetMetadataMatches = longTrackResult.reportV2.pcmIdentity.channels == selfIdentity.channels
        }
        guard longTrackResult.reportV2.pcmIdentity.algorithm == selfIdentity.algorithm,
              targetMetadataMatches,
              targetFrameCount == selfIdentity.referenceFrameCount,
              targetDigest == selfIdentity.referenceDigestSHA256 else {
            throw Lane3CodecLongTrackEvidenceBindingError.targetPCMIdentityMismatch
        }

        let cleanDigest = reportBindingSHA256(cleanReport)
        let truncatedDigest = reportBindingSHA256(truncatedReport)
        let corruptedDigest = reportBindingSHA256(corruptedReport)
        let familyDigest = Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_AW44_CODEC_FAMILY_BINDING_V1",
            cleanReport.fixture.declaredCodecLabel,
            cleanDigest,
            truncatedDigest,
            corruptedDigest
        ])
        let completionDigest = completionBindingSHA256(completion)
        let combined = Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_AW44_CODEC_LONG_TRACK_BINDING_V1",
            sourceRole.rawValue,
            familyDigest,
            selfIdentity.referenceDigestSHA256,
            targetDigest,
            longTrackResult.reportV2.runBindingSHA256,
            completionDigest
        ])

        let physicalFamily = [cleanReport, truncatedReport, corruptedReport].allSatisfy {
            $0.environment == .physicalIPhoneAVFAudio && $0.authoritativePhysicalEvidenceAllowed
        }

        return Lane3CodecLongTrackEvidenceBindingReceipt(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW44_CODEC_LONG_TRACK_CONTENT_BINDING_NON_PARITY",
            sourceRole: sourceRole,
            declaredCodecLabel: cleanReport.fixture.declaredCodecLabel,
            cleanFixtureID: cleanReport.fixture.fixtureID,
            truncatedFixtureID: truncatedReport.fixture.fixtureID,
            corruptedFixtureID: corruptedReport.fixture.fixtureID,
            cleanReportBindingSHA256: cleanDigest,
            truncatedReportBindingSHA256: truncatedDigest,
            corruptedReportBindingSHA256: corruptedDigest,
            codecFamilyBindingSHA256: familyDigest,
            cleanReportReexecutionMatched: true,
            cleanPCMIdentityAlgorithm: selfIdentity.algorithm,
            cleanPCMIdentitySHA256: selfIdentity.referenceDigestSHA256,
            longTrackTargetPCMIdentitySHA256: targetDigest,
            targetPCMIdentityMatched: true,
            aw30RunBindingSHA256: longTrackResult.reportV2.runBindingSHA256,
            aw30CompletionBindingSHA256: completionDigest,
            completionRunBindingMatched: true,
            combinedBindingSHA256: combined,
            codecFamilyContractComplete: true,
            codecFamilyPhysicalIPhoneComplete: physicalFamily,
            derivativeLineageCryptographicallyProven: false,
            rawPCMIncluded: false,
            rawCompressedBytesIncluded: false,
            sourcePathIncluded: false,
            authenticitySignatureIncluded: false,
            authoritativePhysicalEvidenceAllowed: false,
            parityPromotionAllowed: false
        )
    }

    @discardableResult
    public static func validate(
        _ receipt: Lane3CodecLongTrackEvidenceBindingReceipt,
        cleanSource: any Lane3PCMChunkReadable,
        cleanReport: Lane3RepresentativeCodecExecutionReport,
        truncatedReport: Lane3RepresentativeCodecExecutionReport,
        corruptedReport: Lane3RepresentativeCodecExecutionReport,
        longTrackResult: Lane3LongTrackUnifiedEvidenceResult,
        completion: Lane3LongTrackEvidenceCompletionReceipt,
        identityChunkFrames: Int = 16_384
    ) throws -> Lane3CodecLongTrackEvidenceBindingReceipt {
        let rebuilt = try makeReceipt(
            cleanSource: cleanSource,
            sourceRole: receipt.sourceRole,
            cleanReport: cleanReport,
            truncatedReport: truncatedReport,
            corruptedReport: corruptedReport,
            longTrackResult: longTrackResult,
            completion: completion,
            identityChunkFrames: identityChunkFrames
        )
        guard rebuilt == receipt,
              receipt.schemaVersion == 1,
              receipt.evidenceScope == "LANE3_AW44_CODEC_LONG_TRACK_CONTENT_BINDING_NON_PARITY",
              receipt.cleanReportReexecutionMatched,
              receipt.targetPCMIdentityMatched,
              receipt.completionRunBindingMatched,
              receipt.codecFamilyContractComplete,
              !receipt.derivativeLineageCryptographicallyProven,
              !receipt.rawPCMIncluded,
              !receipt.rawCompressedBytesIncluded,
              !receipt.sourcePathIncluded,
              !receipt.authenticitySignatureIncluded,
              !receipt.authoritativePhysicalEvidenceAllowed,
              !receipt.parityPromotionAllowed,
              isLowercaseSHA256(receipt.cleanReportBindingSHA256),
              isLowercaseSHA256(receipt.truncatedReportBindingSHA256),
              isLowercaseSHA256(receipt.corruptedReportBindingSHA256),
              isLowercaseSHA256(receipt.codecFamilyBindingSHA256),
              isLowercaseSHA256(receipt.cleanPCMIdentitySHA256),
              isLowercaseSHA256(receipt.longTrackTargetPCMIdentitySHA256),
              isLowercaseSHA256(receipt.aw30RunBindingSHA256),
              isLowercaseSHA256(receipt.aw30CompletionBindingSHA256),
              isLowercaseSHA256(receipt.combinedBindingSHA256) else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidBindingReceipt
        }
        return receipt
    }

    static func reportBindingSHA256(_ report: Lane3RepresentativeCodecExecutionReport) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_AW44_CODEC_REPORT_BINDING_V1",
            String(report.schemaVersion),
            report.evidenceScope,
            String(report.fixture.schemaVersion),
            report.fixture.fixtureID,
            report.fixture.declaredCodecLabel,
            report.fixture.faultExpectation.rawValue,
            String(report.fixture.expectedChannels),
            String(report.fixture.expectedSampleRate.bitPattern),
            String(report.fixture.baselineFrameCount),
            bool(report.fixture.rightsCleared),
            bool(report.fixture.sourcePathIncluded),
            bool(report.fixture.rawCompressedBytesIncluded),
            bool(report.fixture.parityPromotionAllowed),
            report.environment.rawValue,
            bool(report.decoderOpened),
            optionalInt(report.actualChannels),
            optionalDouble(report.actualSampleRate),
            optionalInt64(report.actualFrameCount),
            String(report.readCalls),
            String(report.framesRead),
            String(report.maximumChunkFrames),
            bool(report.completeSequentialSweep),
            String(report.nonFiniteSampleCount),
            optionalUInt64(report.rollingPCMChecksumFNV1A64),
            report.failureCode.map { "some:\($0.rawValue)" } ?? "nil",
            bool(report.metadataTruncationObserved),
            bool(report.expectedFaultObserved),
            bool(report.cleanDecodeContractSatisfied),
            bool(report.rightsCleared),
            bool(report.representativeLongTrack),
            bool(report.boundedChunkedRead),
            bool(report.rawPCMRetained),
            bool(report.sourcePathIncluded),
            bool(report.authoritativePhysicalEvidenceAllowed),
            bool(report.parityPromotionAllowed)
        ])
    }

    static func completionBindingSHA256(_ receipt: Lane3LongTrackEvidenceCompletionReceipt) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_AW44_AW30_COMPLETION_BINDING_V1",
            String(receipt.schemaVersion),
            receipt.evidenceScope,
            receipt.runBindingSHA256,
            String(receipt.finalCheckpointSerial),
            String(receipt.referenceReadCalls),
            String(receipt.observedReadCalls),
            String(receipt.referenceFramesRequested),
            String(receipt.observedFramesRequested),
            bool(receipt.counterOverflowed),
            String(receipt.progressPermille),
            bool(receipt.finalReportConstructedBeforeCompletion),
            bool(receipt.rawPCMIncluded),
            bool(receipt.sourcePathIncluded),
            bool(receipt.parityPromotionAllowed)
        ])
    }

    private static func longTrackRunBindingSHA256(_ report: Lane3UnifiedEvidenceReportV2) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            report.fixtureID,
            report.controlSignatureFNV1A64,
            String(report.productionGeneration.activePlaybackGeneration),
            String(report.productionGeneration.activeClickGeneration),
            report.productionGeneration.activeReason,
            String(report.productionGeneration.coordinatorReceipt.operationSerial),
            report.pcmIdentity.algorithm,
            report.pcmIdentity.referenceDigestSHA256,
            report.pcmIdentity.observedDigestSHA256,
            String(report.coreEvidence.timeDomain.globalLagFrames),
            String(report.envelope.windowsAnalyzed),
            String(report.coreEvidence.expectedEventCount)
        ])
    }

    private static func validateCodecFamily(
        clean: Lane3RepresentativeCodecExecutionReport,
        truncated: Lane3RepresentativeCodecExecutionReport,
        corrupted: Lane3RepresentativeCodecExecutionReport
    ) throws {
        guard clean.schemaVersion == 1,
              clean.evidenceScope == "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
              clean.fixture.faultExpectation == .clean,
              clean.cleanDecodeContractSatisfied,
              clean.completeSequentialSweep,
              clean.failureCode == nil,
              clean.nonFiniteSampleCount == 0,
              clean.rollingPCMChecksumFNV1A64 != nil,
              clean.rightsCleared,
              clean.representativeLongTrack,
              clean.boundedChunkedRead,
              !clean.rawPCMRetained,
              !clean.sourcePathIncluded,
              !clean.parityPromotionAllowed,
              clean.maximumChunkFrames > 0 else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidCleanReport
        }
        guard truncated.schemaVersion == 1,
              truncated.evidenceScope == "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
              truncated.fixture.faultExpectation == .truncated,
              truncated.expectedFaultObserved,
              truncated.rightsCleared,
              truncated.representativeLongTrack,
              truncated.boundedChunkedRead,
              !truncated.rawPCMRetained,
              !truncated.sourcePathIncluded,
              !truncated.parityPromotionAllowed else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidTruncatedReport
        }
        guard corrupted.schemaVersion == 1,
              corrupted.evidenceScope == "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
              corrupted.fixture.faultExpectation == .corrupted,
              corrupted.expectedFaultObserved,
              corrupted.rightsCleared,
              corrupted.representativeLongTrack,
              corrupted.boundedChunkedRead,
              !corrupted.rawPCMRetained,
              !corrupted.sourcePathIncluded,
              !corrupted.parityPromotionAllowed else {
            throw Lane3CodecLongTrackEvidenceBindingError.invalidCorruptedReport
        }

        let reports = [clean, truncated, corrupted]
        guard reports.allSatisfy({
            $0.fixture.declaredCodecLabel == clean.fixture.declaredCodecLabel
                && $0.fixture.rightsCleared
                && !$0.fixture.sourcePathIncluded
                && !$0.fixture.rawCompressedBytesIncluded
                && !$0.fixture.parityPromotionAllowed
        }) else {
            throw Lane3CodecLongTrackEvidenceBindingError.codecFamilyMismatch
        }
        guard reports.allSatisfy({
            $0.fixture.expectedChannels == clean.fixture.expectedChannels
                && $0.fixture.expectedSampleRate.bitPattern == clean.fixture.expectedSampleRate.bitPattern
                && $0.fixture.baselineFrameCount == clean.fixture.baselineFrameCount
        }) else {
            throw Lane3CodecLongTrackEvidenceBindingError.baselineMetadataMismatch
        }
        let fixtureIDs = Set(reports.map { $0.fixture.fixtureID })
        guard fixtureIDs.count == 3 else {
            throw Lane3CodecLongTrackEvidenceBindingError.duplicateFixtureID
        }
    }

    private static func bool(_ value: Bool) -> String { value ? "1" : "0" }
    private static func optionalInt(_ value: Int?) -> String { value.map { "some:\($0)" } ?? "nil" }
    private static func optionalInt64(_ value: Int64?) -> String { value.map { "some:\($0)" } ?? "nil" }
    private static func optionalUInt64(_ value: UInt64?) -> String { value.map { "some:\($0)" } ?? "nil" }
    private static func optionalDouble(_ value: Double?) -> String {
        value.map { "someBits:\($0.bitPattern)" } ?? "nil"
    }
    private static func isLowercaseSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }
}
