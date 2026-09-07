import Foundation

public enum Lane3PCMDifferentialError: Error, Equatable, Sendable {
    case invalidFormat
    case sampleRateMismatch(expected: Double, actual: Double)
    case channelMismatch(expected: Int, actual: Int)
    case invalidConfiguration
    case emptyPCM
    case eventFrameOutOfBounds(Int64)
    case insufficientComparableFrames
}

public struct Lane3PCMBufferDescriptor: Equatable, Codable, Sendable {
    public let interleavedSamples: [Float]
    public let channels: Int
    public let sampleRate: Double

    public init(interleavedSamples: [Float], channels: Int, sampleRate: Double) {
        self.interleavedSamples = interleavedSamples
        self.channels = channels
        self.sampleRate = sampleRate
    }

    public var frameCount: Int64 {
        channels > 0 ? Int64(interleavedSamples.count / channels) : 0
    }
}

public struct Lane3PCMDifferentialConfiguration: Equatable, Codable, Sendable {
    public let maximumAlignmentLagFrames: Int
    public let alignmentWindowFrames: Int
    public let localDriftSearchFrames: Int
    public let localWindowFrames: Int
    public let driftAnchorCount: Int
    public let onsetSearchRadiusFrames: Int
    public let expectedEventMaskRadiusFrames: Int
    public let minimumComparableFrames: Int
    public let silenceThreshold: Double
    public let discontinuityRMSMultiplier: Double
    public let discontinuityAbsoluteFloor: Double

    public init(
        maximumAlignmentLagFrames: Int = 4_096,
        alignmentWindowFrames: Int = 32_768,
        localDriftSearchFrames: Int = 512,
        localWindowFrames: Int = 8_192,
        driftAnchorCount: Int = 7,
        onsetSearchRadiusFrames: Int = 1_024,
        expectedEventMaskRadiusFrames: Int = 256,
        minimumComparableFrames: Int = 2_048,
        silenceThreshold: Double = 1e-7,
        discontinuityRMSMultiplier: Double = 10,
        discontinuityAbsoluteFloor: Double = 0.15
    ) {
        self.maximumAlignmentLagFrames = maximumAlignmentLagFrames
        self.alignmentWindowFrames = alignmentWindowFrames
        self.localDriftSearchFrames = localDriftSearchFrames
        self.localWindowFrames = localWindowFrames
        self.driftAnchorCount = driftAnchorCount
        self.onsetSearchRadiusFrames = onsetSearchRadiusFrames
        self.expectedEventMaskRadiusFrames = expectedEventMaskRadiusFrames
        self.minimumComparableFrames = minimumComparableFrames
        self.silenceThreshold = silenceThreshold
        self.discontinuityRMSMultiplier = discontinuityRMSMultiplier
        self.discontinuityAbsoluteFloor = discontinuityAbsoluteFloor
    }
}

public struct Lane3PCMOnsetObservation: Equatable, Codable, Sendable {
    public let scheduledReferenceFrame: Int64
    public let detectedReferenceOnsetFrame: Int64?
    public let expectedObservedFrameAfterGlobalAlignment: Int64?
    public let observedOnsetFrame: Int64?
    public let rawDeltaFrames: Int64?
    public let residualDeltaFrames: Int64?
    public let referenceEnergyIncrease: Double?
    public let observedEnergyIncrease: Double?
}

public struct Lane3PCMDriftObservation: Equatable, Codable, Sendable {
    public let referenceAnchorFrame: Int64
    public let localLagFrames: Int
    public let lagRelativeToGlobalFrames: Int
    public let normalizedCorrelation: Double
}

public struct Lane3PCMDifferentialReport: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let referenceFrameCount: Int64
    public let observedFrameCount: Int64
    public let globalLagFrames: Int
    public let globalNormalizedCorrelation: Double
    public let comparableFrameCount: Int64
    public let residualRMS: Double
    public let referenceRMS: Double
    public let residualToReferenceDB: Double
    public let derivativeRMSRatio: Double
    public let derivativeRMSDeltaDB: Double
    public let driftObservations: [Lane3PCMDriftObservation]
    public let driftSpanFrames: Int
    public let onsetObservations: [Lane3PCMOnsetObservation]
    public let maximumAbsoluteOnsetOffsetFrames: Int64?
    public let maximumAbsoluteResidualOnsetErrorFrames: Int64?
    public let unexpectedDiscontinuityCount: Int
    public let maximumUnexpectedDerivative: Double
    public let observedClippedSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let parityPromotionAllowed: Bool
}

public enum Lane3PCMDifferentialAnalyzer {
    public static func analyze(
        reference: Lane3PCMBufferDescriptor,
        observed: Lane3PCMBufferDescriptor,
        expectedEventFrames: [Int64] = [],
        configuration: Lane3PCMDifferentialConfiguration = Lane3PCMDifferentialConfiguration()
    ) throws -> Lane3PCMDifferentialReport {
        try validate(reference, observed, expectedEventFrames, configuration)
        let ref = collapseToMono(reference)
        let obs = collapseToMono(observed)
        let refAlignment = firstDifference(ref)
        let obsAlignment = firstDifference(obs)

        let global = try bestLag(
            reference: refAlignment,
            observed: obsAlignment,
            referenceCenter: ref.count / 2,
            expectedLag: 0,
            searchRadius: configuration.maximumAlignmentLagFrames,
            windowFrames: min(configuration.alignmentWindowFrames, ref.count, obs.count),
            minimumComparableFrames: configuration.minimumComparableFrames
        )

        let aligned = alignedRanges(referenceCount: ref.count, observedCount: obs.count, lag: global.lag)
        guard aligned.count >= configuration.minimumComparableFrames else {
            throw Lane3PCMDifferentialError.insufficientComparableFrames
        }

        var residualSquares = 0.0
        var referenceSquares = 0.0
        var derivativeReferenceSquares = 0.0
        var derivativeObservedSquares = 0.0
        var previousReference: Double?
        var previousObserved: Double?
        var finiteResidualSamples = 0
        for offset in 0..<aligned.count {
            let r = ref[aligned.referenceStart + offset]
            let o = obs[aligned.observedStart + offset]
            guard r.isFinite, o.isFinite else { continue }
            let residual = o - r
            residualSquares += residual * residual
            referenceSquares += r * r
            finiteResidualSamples += 1
            if let previousReference, let previousObserved {
                let dr = r - previousReference
                let `do` = o - previousObserved
                derivativeReferenceSquares += dr * dr
                derivativeObservedSquares += `do` * `do`
            }
            previousReference = r
            previousObserved = o
        }
        guard finiteResidualSamples >= configuration.minimumComparableFrames else {
            throw Lane3PCMDifferentialError.insufficientComparableFrames
        }

        let residualRMS = sqrt(residualSquares / Double(finiteResidualSamples))
        let referenceRMS = sqrt(referenceSquares / Double(finiteResidualSamples))
        let residualDB = amplitudeDB(residualRMS / max(referenceRMS, 1e-12))
        let derivativeRMSRatio = sqrt(derivativeObservedSquares / max(derivativeReferenceSquares, 1e-24))
        let derivativeRMSDeltaDB = amplitudeDB(derivativeRMSRatio)

        let drift = try driftObservations(
            reference: refAlignment,
            observed: obsAlignment,
            globalLag: global.lag,
            configuration: configuration
        )
        let driftSpan = drift.isEmpty ? 0 : (drift.map(\.localLagFrames).max()! - drift.map(\.localLagFrames).min()!)

        let onset = try onsetObservations(
            referenceMono: ref,
            observedMono: obs,
            expectedEventFrames: expectedEventFrames,
            globalLag: global.lag,
            configuration: configuration
        )
        let maxOnsetOffset = onset.compactMap { $0.rawDeltaFrames.map { abs($0) } }.max()
        let maxResidualOnset = onset.compactMap { $0.residualDeltaFrames.map { abs($0) } }.max()

        let discontinuities = unexpectedDiscontinuities(
            observedMono: obs,
            expectedEventFrames: expectedEventFrames,
            globalLag: global.lag,
            configuration: configuration
        )
        let observedHealth = observedSampleHealth(observed)

        return Lane3PCMDifferentialReport(
            evidenceScope: "LANE3_PCM_DIFFERENTIAL_NON_PARITY",
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount,
            globalLagFrames: global.lag,
            globalNormalizedCorrelation: global.correlation,
            comparableFrameCount: Int64(aligned.count),
            residualRMS: residualRMS,
            referenceRMS: referenceRMS,
            residualToReferenceDB: residualDB,
            derivativeRMSRatio: derivativeRMSRatio,
            derivativeRMSDeltaDB: derivativeRMSDeltaDB,
            driftObservations: drift,
            driftSpanFrames: driftSpan,
            onsetObservations: onset,
            maximumAbsoluteOnsetOffsetFrames: maxOnsetOffset,
            maximumAbsoluteResidualOnsetErrorFrames: maxResidualOnset,
            unexpectedDiscontinuityCount: discontinuities.count,
            maximumUnexpectedDerivative: discontinuities.maximum,
            observedClippedSampleCount: observedHealth.clipped,
            observedNonFiniteSampleCount: observedHealth.nonFinite,
            parityPromotionAllowed: false
        )
    }

    private static func validate(
        _ reference: Lane3PCMBufferDescriptor,
        _ observed: Lane3PCMBufferDescriptor,
        _ expectedEventFrames: [Int64],
        _ configuration: Lane3PCMDifferentialConfiguration
    ) throws {
        for item in [reference, observed] {
            guard item.channels > 0,
                  item.sampleRate.isFinite, item.sampleRate > 0,
                  !item.interleavedSamples.isEmpty,
                  item.interleavedSamples.count % item.channels == 0 else {
                throw Lane3PCMDifferentialError.invalidFormat
            }
        }
        guard abs(reference.sampleRate - observed.sampleRate) <= 0.5 else {
            throw Lane3PCMDifferentialError.sampleRateMismatch(expected: reference.sampleRate, actual: observed.sampleRate)
        }
        guard reference.channels == observed.channels else {
            throw Lane3PCMDifferentialError.channelMismatch(expected: reference.channels, actual: observed.channels)
        }
        guard configuration.maximumAlignmentLagFrames >= 0,
              configuration.alignmentWindowFrames > 0,
              configuration.localDriftSearchFrames >= 0,
              configuration.localWindowFrames > 0,
              configuration.driftAnchorCount > 0,
              configuration.onsetSearchRadiusFrames >= 0,
              configuration.expectedEventMaskRadiusFrames >= 0,
              configuration.minimumComparableFrames > 0,
              configuration.silenceThreshold.isFinite,
              configuration.silenceThreshold >= 0,
              configuration.discontinuityRMSMultiplier.isFinite,
              configuration.discontinuityRMSMultiplier > 0,
              configuration.discontinuityAbsoluteFloor.isFinite,
              configuration.discontinuityAbsoluteFloor >= 0 else {
            throw Lane3PCMDifferentialError.invalidConfiguration
        }
        guard reference.frameCount > 0, observed.frameCount > 0 else {
            throw Lane3PCMDifferentialError.emptyPCM
        }
        var prior: Int64? = nil
        for frame in expectedEventFrames {
            guard frame >= 0, frame < reference.frameCount else {
                throw Lane3PCMDifferentialError.eventFrameOutOfBounds(frame)
            }
            if let prior, frame <= prior {
                throw Lane3PCMDifferentialError.invalidConfiguration
            }
            prior = frame
        }
    }

    private static func collapseToMono(_ input: Lane3PCMBufferDescriptor) -> [Double] {
        let frames = Int(input.frameCount)
        var mono = [Double](repeating: 0, count: frames)
        for frame in 0..<frames {
            var sum = 0.0
            var finite = 0
            for channel in 0..<input.channels {
                let value = Double(input.interleavedSamples[frame * input.channels + channel])
                if value.isFinite {
                    sum += value
                    finite += 1
                }
            }
            mono[frame] = finite > 0 ? sum / Double(finite) : 0
        }
        return mono
    }

    private static func firstDifference(_ signal: [Double]) -> [Double] {
        guard !signal.isEmpty else { return [] }
        var output = [Double](repeating: 0, count: signal.count)
        if signal.count > 1 {
            for index in 1..<signal.count {
                let current = signal[index]
                let previous = signal[index - 1]
                output[index] = current.isFinite && previous.isFinite ? current - previous : 0
            }
        }
        return output
    }

    private struct LagResult {
        let lag: Int
        let correlation: Double
    }

    private static func bestLag(
        reference: [Double],
        observed: [Double],
        referenceCenter: Int,
        expectedLag: Int,
        searchRadius: Int,
        windowFrames: Int,
        minimumComparableFrames: Int
    ) throws -> LagResult {
        let half = max(1, windowFrames / 2)
        let referenceStart = max(0, referenceCenter - half)
        let referenceEnd = min(reference.count, referenceCenter + half)
        guard referenceEnd - referenceStart >= minimumComparableFrames else {
            throw Lane3PCMDifferentialError.insufficientComparableFrames
        }
        let coarseSampleStride = max(1, (referenceEnd - referenceStart) / 1_024)
        var bestLag = expectedLag
        var bestCorrelation = -Double.infinity
        for candidate in (expectedLag - searchRadius)...(expectedLag + searchRadius) {
            let observedStart = referenceStart + candidate
            let observedEnd = referenceEnd + candidate
            guard observedStart >= 0, observedEnd <= observed.count else { continue }
            let correlation = normalizedCorrelation(
                reference: reference,
                observed: observed,
                referenceStart: referenceStart,
                observedStart: observedStart,
                count: referenceEnd - referenceStart,
                sampleStride: coarseSampleStride
            )
            if correlation > bestCorrelation || (correlation == bestCorrelation && abs(candidate - expectedLag) < abs(bestLag - expectedLag)) {
                bestCorrelation = correlation
                bestLag = candidate
            }
        }

        let refineLower = max(expectedLag - searchRadius, bestLag - 2)
        let refineUpper = min(expectedLag + searchRadius, bestLag + 2)
        let refineSampleStride = max(1, (referenceEnd - referenceStart) / 16_384)
        for candidate in refineLower...refineUpper {
            let observedStart = referenceStart + candidate
            let observedEnd = referenceEnd + candidate
            guard observedStart >= 0, observedEnd <= observed.count else { continue }
            let correlation = normalizedCorrelation(
                reference: reference,
                observed: observed,
                referenceStart: referenceStart,
                observedStart: observedStart,
                count: referenceEnd - referenceStart,
                sampleStride: refineSampleStride
            )
            if correlation > bestCorrelation || (correlation == bestCorrelation && abs(candidate - expectedLag) < abs(bestLag - expectedLag)) {
                bestCorrelation = correlation
                bestLag = candidate
            }
        }
        guard bestCorrelation.isFinite else {
            throw Lane3PCMDifferentialError.insufficientComparableFrames
        }
        return LagResult(lag: bestLag, correlation: bestCorrelation)
    }

    private static func normalizedCorrelation(
        reference: [Double],
        observed: [Double],
        referenceStart: Int,
        observedStart: Int,
        count: Int,
        sampleStride: Int = 1
    ) -> Double {
        var sumR = 0.0
        var sumO = 0.0
        var sumRR = 0.0
        var sumOO = 0.0
        var sumRO = 0.0
        var n = 0.0
        let strideValue = max(1, sampleStride)
        var i = 0
        while i < count {
            let r = reference[referenceStart + i]
            let o = observed[observedStart + i]
            if r.isFinite, o.isFinite {
                sumR += r
                sumO += o
                sumRR += r * r
                sumOO += o * o
                sumRO += r * o
                n += 1
            }
            i += strideValue
        }
        guard n >= 2 else { return -1 }
        let covariance = sumRO - (sumR * sumO / n)
        let varianceR = max(0, sumRR - sumR * sumR / n)
        let varianceO = max(0, sumOO - sumO * sumO / n)
        let denominator = sqrt(varianceR * varianceO)
        guard denominator > 1e-20 else { return covariance == 0 ? 0 : -1 }
        return max(-1, min(1, covariance / denominator))
    }

    private struct AlignedRange {
        let referenceStart: Int
        let observedStart: Int
        let count: Int
    }

    private static func alignedRanges(referenceCount: Int, observedCount: Int, lag: Int) -> AlignedRange {
        let referenceStart = max(0, -lag)
        let observedStart = max(0, lag)
        let count = max(0, min(referenceCount - referenceStart, observedCount - observedStart))
        return AlignedRange(referenceStart: referenceStart, observedStart: observedStart, count: count)
    }

    private static func driftObservations(
        reference: [Double],
        observed: [Double],
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration
    ) throws -> [Lane3PCMDriftObservation] {
        let usable = alignedRanges(referenceCount: reference.count, observedCount: observed.count, lag: globalLag)
        guard usable.count >= configuration.localWindowFrames else { return [] }
        let anchors = max(1, configuration.driftAnchorCount)
        let halfWindow = configuration.localWindowFrames / 2
        let margin = halfWindow + configuration.localDriftSearchFrames
        let start = usable.referenceStart + margin
        let end = usable.referenceStart + usable.count - margin
        guard end > start else { return [] }
        var output: [Lane3PCMDriftObservation] = []
        output.reserveCapacity(anchors)
        for index in 0..<anchors {
            let fraction = anchors == 1 ? 0.5 : Double(index) / Double(anchors - 1)
            let center = start + Int((Double(end - start) * fraction).rounded())
            let local = try bestLag(
                reference: reference,
                observed: observed,
                referenceCenter: center,
                expectedLag: globalLag,
                searchRadius: configuration.localDriftSearchFrames,
                windowFrames: configuration.localWindowFrames,
                minimumComparableFrames: min(configuration.minimumComparableFrames, configuration.localWindowFrames)
            )
            output.append(
                Lane3PCMDriftObservation(
                    referenceAnchorFrame: Int64(center),
                    localLagFrames: local.lag,
                    lagRelativeToGlobalFrames: local.lag - globalLag,
                    normalizedCorrelation: local.correlation
                )
            )
        }
        return output
    }

    private static func onsetObservations(
        referenceMono: [Double],
        observedMono: [Double],
        expectedEventFrames: [Int64],
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration
    ) throws -> [Lane3PCMOnsetObservation] {
        var output: [Lane3PCMOnsetObservation] = []
        output.reserveCapacity(expectedEventFrames.count)
        for scheduled in expectedEventFrames {
            let referenceDetection = strongestEnergyOnset(
                signal: referenceMono,
                targetFrame: Int(scheduled),
                radius: configuration.onsetSearchRadiusFrames,
                minimumEnergyIncrease: configuration.silenceThreshold * configuration.silenceThreshold
            )
            guard let referenceDetection else {
                output.append(
                    Lane3PCMOnsetObservation(
                        scheduledReferenceFrame: scheduled,
                        detectedReferenceOnsetFrame: nil,
                        expectedObservedFrameAfterGlobalAlignment: nil,
                        observedOnsetFrame: nil,
                        rawDeltaFrames: nil,
                        residualDeltaFrames: nil,
                        referenceEnergyIncrease: nil,
                        observedEnergyIncrease: nil
                    )
                )
                continue
            }
            let predictedObserved = referenceDetection.frame + globalLag
            let observedDetection = strongestEnergyOnset(
                signal: observedMono,
                targetFrame: predictedObserved,
                radius: configuration.onsetSearchRadiusFrames,
                minimumEnergyIncrease: configuration.silenceThreshold * configuration.silenceThreshold
            )
            guard let observedDetection else {
                output.append(
                    Lane3PCMOnsetObservation(
                        scheduledReferenceFrame: scheduled,
                        detectedReferenceOnsetFrame: Int64(referenceDetection.frame),
                        expectedObservedFrameAfterGlobalAlignment: Int64(predictedObserved),
                        observedOnsetFrame: nil,
                        rawDeltaFrames: nil,
                        residualDeltaFrames: nil,
                        referenceEnergyIncrease: referenceDetection.energyIncrease,
                        observedEnergyIncrease: nil
                    )
                )
                continue
            }
            let referenceFrame = Int64(referenceDetection.frame)
            let observedFrame = Int64(observedDetection.frame)
            let predictedFrame = Int64(predictedObserved)
            output.append(
                Lane3PCMOnsetObservation(
                    scheduledReferenceFrame: scheduled,
                    detectedReferenceOnsetFrame: referenceFrame,
                    expectedObservedFrameAfterGlobalAlignment: predictedFrame,
                    observedOnsetFrame: observedFrame,
                    rawDeltaFrames: observedFrame - referenceFrame,
                    residualDeltaFrames: observedFrame - predictedFrame,
                    referenceEnergyIncrease: referenceDetection.energyIncrease,
                    observedEnergyIncrease: observedDetection.energyIncrease
                )
            )
        }
        return output
    }

    private static func strongestEnergyOnset(
        signal: [Double],
        targetFrame: Int,
        radius: Int,
        minimumEnergyIncrease: Double
    ) -> (frame: Int, energyIncrease: Double)? {
        guard signal.count > 1 else { return nil }
        let lower = max(1, targetFrame - radius)
        let upper = min(signal.count - 1, targetFrame + radius)
        guard lower <= upper else { return nil }
        var bestFrame: Int?
        var bestIncrease = minimumEnergyIncrease
        for frame in lower...upper {
            let current = signal[frame]
            let previous = signal[frame - 1]
            guard current.isFinite, previous.isFinite else { continue }
            let increase = current * current - previous * previous
            if increase > bestIncrease {
                bestIncrease = increase
                bestFrame = frame
            }
        }
        guard let bestFrame else { return nil }
        return (bestFrame, bestIncrease)
    }

    private struct DiscontinuitySummary {
        let count: Int
        let maximum: Double
    }

    private static func unexpectedDiscontinuities(
        observedMono: [Double],
        expectedEventFrames: [Int64],
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration
    ) -> DiscontinuitySummary {
        guard observedMono.count > 1 else { return DiscontinuitySummary(count: 0, maximum: 0) }
        var sumSquares = 0.0
        var finiteCount = 0
        var derivatives = [Double](repeating: 0, count: observedMono.count)
        for frame in 1..<observedMono.count {
            let current = observedMono[frame]
            let previous = observedMono[frame - 1]
            guard current.isFinite, previous.isFinite else { continue }
            let derivative = abs(current - previous)
            derivatives[frame] = derivative
            sumSquares += derivative * derivative
            finiteCount += 1
        }
        let derivativeRMS = finiteCount > 0 ? sqrt(sumSquares / Double(finiteCount)) : 0
        let threshold = max(
            configuration.discontinuityAbsoluteFloor,
            derivativeRMS * configuration.discontinuityRMSMultiplier
        )
        let expectedTargets = expectedEventFrames.map { Int($0) + globalLag }
        var count = 0
        var maximum = 0.0
        for frame in 1..<derivatives.count where derivatives[frame] > threshold {
            let masked = expectedTargets.contains { abs($0 - frame) <= configuration.expectedEventMaskRadiusFrames }
            if !masked {
                count += 1
                maximum = max(maximum, derivatives[frame])
            }
        }
        return DiscontinuitySummary(count: count, maximum: maximum)
    }

    private static func observedSampleHealth(_ observed: Lane3PCMBufferDescriptor) -> (clipped: Int64, nonFinite: Int64) {
        var clipped: Int64 = 0
        var nonFinite: Int64 = 0
        for sample in observed.interleavedSamples {
            let value = Double(sample)
            if !value.isFinite {
                nonFinite += 1
            } else if abs(value) > 1 {
                clipped += 1
            }
        }
        return (clipped, nonFinite)
    }

    private static func amplitudeDB(_ ratio: Double) -> Double {
        20 * log10(max(ratio, 1e-12))
    }
}
