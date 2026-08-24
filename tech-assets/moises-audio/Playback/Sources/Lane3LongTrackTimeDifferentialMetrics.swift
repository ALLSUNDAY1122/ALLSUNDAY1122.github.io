import Foundation

extension Lane3LongTrackPCMDifferentialAnalyzer {
    static func residualAndDerivative(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        aligned: AlignedRange,
        chunkFrames: Int,
        minimumComparableFrames: Int
    ) throws -> (residualRMS: Double, referenceRMS: Double, derivativeRMSRatio: Double, comparable: Int64) {
        var residualSquares = 0.0, referenceSquares = 0.0, derivativeReferenceSquares = 0.0, derivativeObservedSquares = 0.0
        var previousReference: Double?, previousObserved: Double?
        var finite: Int64 = 0
        var offset: Int64 = 0
        while offset < aligned.count {
            let count = min(chunkFrames, Int(aligned.count - offset))
            let ref = try Lane3LongTrackPCMAccess.readMono(reference, start: aligned.referenceStart + offset, count: count).samples
            let obs = try Lane3LongTrackPCMAccess.readMono(observed, start: aligned.observedStart + offset, count: count).samples
            for index in 0..<count {
                let r = ref[index], o = obs[index]
                guard r.isFinite, o.isFinite else { continue }
                let residual = o-r
                residualSquares += residual*residual; referenceSquares += r*r; finite += 1
                if let previousReference, let previousObserved {
                    let dr = r-previousReference, dO = o-previousObserved
                    derivativeReferenceSquares += dr*dr; derivativeObservedSquares += dO*dO
                }
                previousReference = r; previousObserved = o
            }
            offset += Int64(count)
        }
        guard finite >= Int64(minimumComparableFrames) else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }
        return (
            sqrt(residualSquares / Double(finite)),
            sqrt(referenceSquares / Double(finite)),
            sqrt(derivativeObservedSquares / max(derivativeReferenceSquares, 1e-24)),
            aligned.count
        )
    }

    static func driftObservations(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration
    ) throws -> [Lane3PCMDriftObservation] {
        let usable = alignedRanges(referenceCount: reference.frameCount, observedCount: observed.frameCount, lag: globalLag)
        guard usable.count >= Int64(configuration.localWindowFrames) else { return [] }
        let anchors = max(1, configuration.driftAnchorCount)
        let margin = Int64(configuration.localWindowFrames / 2 + configuration.localDriftSearchFrames)
        let start = usable.referenceStart + margin
        let end = usable.referenceStart + usable.count - margin
        guard end > start else { return [] }
        var output: [Lane3PCMDriftObservation] = []
        for index in 0..<anchors {
            let fraction = anchors == 1 ? 0.5 : Double(index) / Double(anchors-1)
            let center = start + Int64((Double(end-start)*fraction).rounded())
            let half = Int64(max(1, configuration.localWindowFrames/2))
            let refStart = max(Int64(0), center-half)
            let refEnd = min(reference.frameCount, center+half)
            let refDiff = try differenceWindow(reference, start: refStart, count: Int(refEnd-refStart))
            let local = try bestLag(referenceDiff: refDiff, referenceStart: refStart, observed: observed, expectedLag: globalLag, searchRadius: configuration.localDriftSearchFrames, minimumComparableFrames: min(configuration.minimumComparableFrames, configuration.localWindowFrames))
            output.append(Lane3PCMDriftObservation(referenceAnchorFrame: center, localLagFrames: local.lag, lagRelativeToGlobalFrames: local.lag-globalLag, normalizedCorrelation: local.correlation))
        }
        return output
    }

    static func onsetObservations(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        expectedEventFrames: [Int64],
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration
    ) throws -> [Lane3PCMOnsetObservation] {
        var result: [Lane3PCMOnsetObservation] = []
        for scheduled in expectedEventFrames {
            let ref = try strongestEnergyOnset(source: reference, target: scheduled, radius: configuration.onsetSearchRadiusFrames, minimum: configuration.silenceThreshold*configuration.silenceThreshold)
            guard let ref else {
                result.append(.init(scheduledReferenceFrame: scheduled, detectedReferenceOnsetFrame: nil, expectedObservedFrameAfterGlobalAlignment: nil, observedOnsetFrame: nil, rawDeltaFrames: nil, residualDeltaFrames: nil, referenceEnergyIncrease: nil, observedEnergyIncrease: nil)); continue
            }
            let predicted = ref.frame + Int64(globalLag)
            let obs = try strongestEnergyOnset(source: observed, target: predicted, radius: configuration.onsetSearchRadiusFrames, minimum: configuration.silenceThreshold*configuration.silenceThreshold)
            guard let obs else {
                result.append(.init(scheduledReferenceFrame: scheduled, detectedReferenceOnsetFrame: ref.frame, expectedObservedFrameAfterGlobalAlignment: predicted, observedOnsetFrame: nil, rawDeltaFrames: nil, residualDeltaFrames: nil, referenceEnergyIncrease: ref.energy, observedEnergyIncrease: nil)); continue
            }
            result.append(.init(scheduledReferenceFrame: scheduled, detectedReferenceOnsetFrame: ref.frame, expectedObservedFrameAfterGlobalAlignment: predicted, observedOnsetFrame: obs.frame, rawDeltaFrames: obs.frame-ref.frame, residualDeltaFrames: obs.frame-predicted, referenceEnergyIncrease: ref.energy, observedEnergyIncrease: obs.energy))
        }
        return result
    }

    static func strongestEnergyOnset(
        source: any Lane3PCMChunkReadable,
        target: Int64,
        radius: Int,
        minimum: Double
    ) throws -> (frame: Int64, energy: Double)? {
        let lower = max(Int64(1), target-Int64(radius))
        let upper = min(source.frameCount-1, target+Int64(radius))
        guard lower <= upper else { return nil }
        let start = lower-1
        let mono = try Lane3LongTrackPCMAccess.readMono(source, start: start, count: Int(upper-start+1)).samples
        var best: Int64?, bestIncrease = minimum
        for frame in lower...upper {
            let i = Int(frame-start)
            let current = mono[i], previous = mono[i-1]
            guard current.isFinite, previous.isFinite else { continue }
            let increase = current*current - previous*previous
            if increase > bestIncrease { bestIncrease = increase; best = frame }
        }
        return best.map { ($0, bestIncrease) }
    }

    static func discontinuitySummary(
        observed: any Lane3PCMChunkReadable,
        expectedEventFrames: [Int64],
        globalLag: Int,
        configuration: Lane3PCMDifferentialConfiguration,
        chunkFrames: Int
    ) throws -> (count: Int, maximum: Double) {
        var sumSquares = 0.0, finiteCount: Int64 = 0
        var previous: Double?
        var frame: Int64 = 0
        while frame < observed.frameCount {
            let count = min(chunkFrames, Int(observed.frameCount-frame))
            let mono = try Lane3LongTrackPCMAccess.readMono(observed, start: frame, count: count).samples
            for value in mono {
                if let previous, previous.isFinite, value.isFinite {
                    let d = abs(value-previous); sumSquares += d*d; finiteCount += 1
                }
                previous = value
            }
            frame += Int64(count)
        }
        let derivativeRMS = finiteCount > 0 ? sqrt(sumSquares/Double(finiteCount)) : 0
        let threshold = max(configuration.discontinuityAbsoluteFloor, derivativeRMS*configuration.discontinuityRMSMultiplier)
        let targets = expectedEventFrames.map { $0 + Int64(globalLag) }
        var count = 0, maximum = 0.0
        previous = nil; frame = 0
        while frame < observed.frameCount {
            let n = min(chunkFrames, Int(observed.frameCount-frame))
            let mono = try Lane3LongTrackPCMAccess.readMono(observed, start: frame, count: n).samples
            for (i, value) in mono.enumerated() {
                let globalFrame = frame + Int64(i)
                if let previous, previous.isFinite, value.isFinite {
                    let d = abs(value-previous)
                    if d > threshold {
                        let masked = targets.contains { abs($0-globalFrame) <= Int64(configuration.expectedEventMaskRadiusFrames) }
                        if !masked { count += 1; maximum = max(maximum, d) }
                    }
                }
                previous = value
            }
            frame += Int64(n)
        }
        return (count, maximum)
    }

    static func amplitudeDB(_ ratio: Double) -> Double { 20 * log10(max(ratio, 1e-12)) }
}
