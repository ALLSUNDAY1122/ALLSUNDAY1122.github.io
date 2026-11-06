import Foundation

// MARK: - Time-domain streaming analyzer (AW07-compatible report)

public enum Lane3LongTrackPCMDifferentialAnalyzer {
    struct LagResult { let lag: Int; let correlation: Double }
    struct AlignedRange { let referenceStart: Int64; let observedStart: Int64; let count: Int64 }

    public static func analyze(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        expectedEventFrames: [Int64] = [],
        configuration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration(),
        chunkFrames: Int = 16_384
    ) throws -> Lane3PCMDifferentialReport {
        _ = try Lane3LongTrackPCMAccess.validatePair(reference: reference, observed: observed, chunkFrames: chunkFrames)
        try validateEvents(expectedEventFrames, referenceFrames: reference.frameCount)
        try validateConfiguration(configuration)

        let global = try globalLag(reference: reference, observed: observed, configuration: configuration)
        let aligned = alignedRanges(referenceCount: reference.frameCount, observedCount: observed.frameCount, lag: global.lag)
        guard aligned.count >= Int64(configuration.minimumComparableFrames) else {
            throw Lane3LongTrackEvidenceError.insufficientComparableFrames
        }

        let residual = try residualAndDerivative(
            reference: reference,
            observed: observed,
            aligned: aligned,
            chunkFrames: chunkFrames,
            minimumComparableFrames: configuration.minimumComparableFrames
        )
        let drift = try driftObservations(reference: reference, observed: observed, globalLag: global.lag, configuration: configuration)
        let driftSpan = drift.isEmpty ? 0 : (drift.map(\.localLagFrames).max()! - drift.map(\.localLagFrames).min()!)
        let onset = try onsetObservations(reference: reference, observed: observed, expectedEventFrames: expectedEventFrames, globalLag: global.lag, configuration: configuration)
        let maxOnsetOffset = onset.compactMap { $0.rawDeltaFrames.map(abs) }.max()
        let maxResidualOnset = onset.compactMap { $0.residualDeltaFrames.map(abs) }.max()
        let discontinuities = try discontinuitySummary(observed: observed, expectedEventFrames: expectedEventFrames, globalLag: global.lag, configuration: configuration, chunkFrames: chunkFrames)
        let health = try Lane3LongTrackPCMAccess.scanSampleHealth(observed, chunkFrames: chunkFrames)

        return Lane3PCMDifferentialReport(
            evidenceScope: "LANE3_PCM_DIFFERENTIAL_NON_PARITY",
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount,
            globalLagFrames: global.lag,
            globalNormalizedCorrelation: global.correlation,
            comparableFrameCount: residual.comparable,
            residualRMS: residual.residualRMS,
            referenceRMS: residual.referenceRMS,
            residualToReferenceDB: amplitudeDB(residual.residualRMS / max(residual.referenceRMS, 1e-12)),
            derivativeRMSRatio: residual.derivativeRMSRatio,
            derivativeRMSDeltaDB: amplitudeDB(residual.derivativeRMSRatio),
            driftObservations: drift,
            driftSpanFrames: driftSpan,
            onsetObservations: onset,
            maximumAbsoluteOnsetOffsetFrames: maxOnsetOffset,
            maximumAbsoluteResidualOnsetErrorFrames: maxResidualOnset,
            unexpectedDiscontinuityCount: discontinuities.count,
            maximumUnexpectedDerivative: discontinuities.maximum,
            observedClippedSampleCount: health.clipped,
            observedNonFiniteSampleCount: health.nonFinite,
            parityPromotionAllowed: false
        )
    }

    static func validateEvents(_ events: [Int64], referenceFrames: Int64) throws {
        var prior: Int64?
        for frame in events {
            guard frame >= 0, frame < referenceFrames else { throw Lane3LongTrackEvidenceError.eventFrameOutOfBounds(frame) }
            if let prior, frame <= prior { throw Lane3LongTrackEvidenceError.invalidConfiguration }
            prior = frame
        }
    }

    static func validateConfiguration(_ c: Lane3PCMDifferentialConfiguration) throws {
        guard c.maximumAlignmentLagFrames >= 0, c.alignmentWindowFrames > 0,
              c.localDriftSearchFrames >= 0, c.localWindowFrames > 0, c.driftAnchorCount > 0,
              c.onsetSearchRadiusFrames >= 0, c.expectedEventMaskRadiusFrames >= 0,
              c.minimumComparableFrames > 0, c.silenceThreshold.isFinite, c.silenceThreshold >= 0,
              c.discontinuityRMSMultiplier.isFinite, c.discontinuityRMSMultiplier > 0,
              c.discontinuityAbsoluteFloor.isFinite, c.discontinuityAbsoluteFloor >= 0 else {
            throw Lane3LongTrackEvidenceError.invalidConfiguration
        }
    }

    static func globalLag(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        configuration: Lane3PCMDifferentialConfiguration
    ) throws -> LagResult {
        let refCount = reference.frameCount
        let obsCount = observed.frameCount
        let center = refCount / 2
        let half = Int64(max(1, min(configuration.alignmentWindowFrames, Int(min(refCount, obsCount))) / 2))
        let refStart = max(Int64(0), center - half)
        let refEnd = min(refCount, center + half)
        let count = Int(refEnd - refStart)
        guard count >= configuration.minimumComparableFrames else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }
        let refDiff = try differenceWindow(reference, start: refStart, count: count)
        return try bestLag(
            referenceDiff: refDiff,
            referenceStart: refStart,
            observed: observed,
            expectedLag: 0,
            searchRadius: configuration.maximumAlignmentLagFrames,
            minimumComparableFrames: configuration.minimumComparableFrames
        )
    }

    static func bestLag(
        referenceDiff: [Double],
        referenceStart: Int64,
        observed: any Lane3PCMChunkReadable,
        expectedLag: Int,
        searchRadius: Int,
        minimumComparableFrames: Int
    ) throws -> LagResult {
        let lowerLag = expectedLag - searchRadius
        let upperLag = expectedLag + searchRadius
        let minObservedStart = referenceStart + Int64(lowerLag)
        let maxObservedEnd = referenceStart + Int64(referenceDiff.count) + Int64(upperLag)
        let boundedStart = max(Int64(0), minObservedStart)
        let boundedEnd = min(observed.frameCount, maxObservedEnd)
        guard boundedEnd > boundedStart else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }
        let observedDiff = try differenceWindow(observed, start: boundedStart, count: Int(boundedEnd - boundedStart))

        let coarseStride = max(1, referenceDiff.count / 1_024)
        var bestLag = expectedLag
        var bestCorrelation = -Double.infinity
        for candidate in lowerLag...upperLag {
            let observedStart = referenceStart + Int64(candidate)
            guard observedStart >= boundedStart,
                  observedStart + Int64(referenceDiff.count) <= boundedEnd else { continue }
            let local = Int(observedStart - boundedStart)
            let correlation = normalizedCorrelation(referenceDiff, observedDiff, observedStart: local, count: referenceDiff.count, stride: coarseStride)
            if correlation > bestCorrelation || (correlation == bestCorrelation && abs(candidate - expectedLag) < abs(bestLag - expectedLag)) {
                bestCorrelation = correlation; bestLag = candidate
            }
        }
        let refineLower = max(lowerLag, bestLag - 2)
        let refineUpper = min(upperLag, bestLag + 2)
        let refineStride = max(1, referenceDiff.count / 16_384)
        for candidate in refineLower...refineUpper {
            let observedStart = referenceStart + Int64(candidate)
            guard observedStart >= boundedStart,
                  observedStart + Int64(referenceDiff.count) <= boundedEnd else { continue }
            let local = Int(observedStart - boundedStart)
            let correlation = normalizedCorrelation(referenceDiff, observedDiff, observedStart: local, count: referenceDiff.count, stride: refineStride)
            if correlation > bestCorrelation || (correlation == bestCorrelation && abs(candidate - expectedLag) < abs(bestLag - expectedLag)) {
                bestCorrelation = correlation; bestLag = candidate
            }
        }
        guard bestCorrelation.isFinite else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }
        return LagResult(lag: bestLag, correlation: bestCorrelation)
    }

    static func differenceWindow(
        _ source: any Lane3PCMChunkReadable,
        start: Int64,
        count: Int
    ) throws -> [Double] {
        guard count > 0 else { return [] }
        let readStart = max(Int64(0), start - 1)
        let prefix = start > 0 ? 1 : 0
        let mono = try Lane3LongTrackPCMAccess.readMono(source, start: readStart, count: count + prefix).samples
        var output = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let globalFrame = start + Int64(index)
            guard globalFrame > 0 else { output[index] = 0; continue }
            let current = mono[index + prefix]
            let previous = mono[index + prefix - 1]
            output[index] = current.isFinite && previous.isFinite ? current - previous : 0
        }
        return output
    }

    static func normalizedCorrelation(
        _ reference: [Double],
        _ observed: [Double],
        observedStart: Int,
        count: Int,
        stride: Int
    ) -> Double {
        var sumR = 0.0, sumO = 0.0, sumRR = 0.0, sumOO = 0.0, sumRO = 0.0, n = 0.0
        var i = 0
        let step = max(1, stride)
        while i < count {
            let r = reference[i]
            let o = observed[observedStart + i]
            if r.isFinite, o.isFinite {
                sumR += r; sumO += o; sumRR += r*r; sumOO += o*o; sumRO += r*o; n += 1
            }
            i += step
        }
        guard n >= 2 else { return -1 }
        let covariance = sumRO - sumR * sumO / n
        let varianceR = max(0, sumRR - sumR * sumR / n)
        let varianceO = max(0, sumOO - sumO * sumO / n)
        let denominator = sqrt(varianceR * varianceO)
        guard denominator > 1e-20 else { return covariance == 0 ? 0 : -1 }
        return max(-1, min(1, covariance / denominator))
    }

    static func alignedRanges(referenceCount: Int64, observedCount: Int64, lag: Int) -> AlignedRange {
        let referenceStart = Int64(max(0, -lag))
        let observedStart = Int64(max(0, lag))
        return AlignedRange(referenceStart: referenceStart, observedStart: observedStart, count: max(0, min(referenceCount-referenceStart, observedCount-observedStart)))
    }

}
