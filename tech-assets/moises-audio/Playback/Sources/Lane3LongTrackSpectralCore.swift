import Foundation

// MARK: - Spectral streaming analyzer (AW08-compatible report)

public enum Lane3LongTrackSpectralPerceptualDifferentialAnalyzer {
    struct AlignedRange { let referenceStart: Int64; let observedStart: Int64; let count: Int64 }
    struct Complex { var real: Double; var imag: Double }

    public static func analyze(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        globalLagFrames: Int = 0,
        configuration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration(),
        chunkFrames: Int = 16_384
    ) throws -> Lane3SpectralDifferentialReport {
        _ = try Lane3LongTrackPCMAccess.validatePair(reference: reference, observed: observed, chunkFrames: chunkFrames)
        try validate(configuration, sampleRate: reference.sampleRate)
        let aligned = alignedRanges(referenceCount: reference.frameCount, observedCount: observed.frameCount, lag: globalLagFrames)
        guard aligned.count >= Int64(configuration.windowSize) else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }
        let starts = selectedWindowStarts(comparableFrames: aligned.count, windowSize: configuration.windowSize, hopSize: configuration.hopSize, maximumWindows: configuration.maximumWindows)
        guard !starts.isEmpty else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }

        let hann = hannWindow(configuration.windowSize)
        let bins = configuration.windowSize/2+1
        var aggregateReference = [Double](repeating: 0, count: bins)
        var aggregateObserved = [Double](repeating: 0, count: bins)
        var refSpectra: [[Double]] = [], obsSpectra: [[Double]] = []
        var refRMS: [Double] = [], obsRMS: [Double] = []
        var analyzedStarts: [Int64] = []
        for local in starts {
            let rs = aligned.referenceStart + local
            let os = aligned.observedStart + local
            let rf = try Lane3LongTrackPCMAccess.readMono(reference, start: rs, count: configuration.windowSize).samples
            let of = try Lane3LongTrackPCMAccess.readMono(observed, start: os, count: configuration.windowSize).samples
            let rr = rms(rf), oo = rms(of)
            if rr < configuration.minimumWindowRMS && oo < configuration.minimumWindowRMS { continue }
            let rp = powerSpectrum(rf, window: hann), op = powerSpectrum(of, window: hann)
            for bin in 0..<bins { aggregateReference[bin] += rp[bin]; aggregateObserved[bin] += op[bin] }
            analyzedStarts.append(local); refSpectra.append(rp); obsSpectra.append(op); refRMS.append(rr); obsRMS.append(oo)
        }
        guard !analyzedStarts.isEmpty else { throw Lane3LongTrackEvidenceError.insufficientComparableFrames }

        let search = estimateFrequencyRatio(referencePower: aggregateReference, observedPower: aggregateObserved, sampleRate: reference.sampleRate, configuration: configuration)
        let expectedScale = scaleCorrelation(referencePower: aggregateReference, observedPower: aggregateObserved, ratio: configuration.expectedFrequencyRatio, sampleRate: reference.sampleRate, configuration: configuration)
        let peaks = spectralPeakMatches(referencePower: aggregateReference, observedPower: aggregateObserved, sampleRate: reference.sampleRate, configuration: configuration)
        let signed = peaks.map(\.ratioErrorCents), absolute = signed.map(abs)
        var observations: [Lane3SpectralWindowObservation] = []
        var logDistances:[Double]=[], centroidErrors:[Double]=[], flatness:[Double]=[], high:[Double]=[], bands:[Double]=[], refFlux:[Double]=[], obsFlux:[Double]=[]
        var prevRef:[Double]?, prevObs:[Double]?
        for i in analyzedStarts.indices {
            let rp=refSpectra[i], op=obsSpectra[i]
            let expected = warpedReferencePower(referencePower: rp, ratio: configuration.expectedFrequencyRatio, outputBinCount: op.count)
            let nr=normalizeSpectrum(expected), no=normalizeSpectrum(op)
            let lsd=logSpectralDistanceDB(expectedReference:nr, observed:no, sampleRate:reference.sampleRate, windowSize:configuration.windowSize, configuration:configuration)
            let rc=spectralCentroidHz(power:rp,sampleRate:reference.sampleRate,windowSize:configuration.windowSize,configuration:configuration)
            let oc=spectralCentroidHz(power:op,sampleRate:observed.sampleRate,windowSize:configuration.windowSize,configuration:configuration)
            let ce=centsError(actualRatio:oc/max(rc,1e-12),expectedRatio:configuration.expectedFrequencyRatio)
            let fd=powerLikeDBDelta(observed:spectralFlatness(power:op,sampleRate:observed.sampleRate,windowSize:configuration.windowSize,configuration:configuration), reference:spectralFlatness(power:rp,sampleRate:reference.sampleRate,windowSize:configuration.windowSize,configuration:configuration))
            let hd=powerLikeDBDelta(observed:highBandEnergyFraction(power:op,sampleRate:observed.sampleRate,windowSize:configuration.windowSize,configuration:configuration), reference:highBandEnergyFraction(power:rp,sampleRate:reference.sampleRate,windowSize:configuration.windowSize,configuration:configuration))
            let bd=bandEnergyCosineDistance(referencePower:expected,observedPower:op,sampleRate:reference.sampleRate,windowSize:configuration.windowSize,configuration:configuration)
            if let prevRef, let prevObs { refFlux.append(spectralFlux(previous:prevRef,current:nr)); obsFlux.append(spectralFlux(previous:prevObs,current:no)) }
            prevRef=nr; prevObs=no
            observations.append(.init(referenceStartFrame:aligned.referenceStart+analyzedStarts[i], observedStartFrame:aligned.observedStart+analyzedStarts[i], logSpectralDistanceDB:lsd, spectralCentroidRatioErrorCents:ce, spectralFlatnessDeltaDB:fd, highBandEnergyDeltaDB:hd, bandEnergyCosineDistance:bd, referenceRMS:refRMS[i], observedRMS:obsRMS[i]))
            logDistances.append(lsd); centroidErrors.append(abs(ce)); flatness.append(abs(fd)); high.append(abs(hd)); bands.append(bd)
        }
        let fluxDelta = refFlux.isEmpty ? 0 : zip(refFlux,obsFlux).map{abs($0-$1)}.reduce(0,+)/Double(min(refFlux.count,obsFlux.count))
        let refNonFinite = try Lane3LongTrackPCMAccess.countNonFinite(reference, chunkFrames: chunkFrames)
        let obsNonFinite = try Lane3LongTrackPCMAccess.countNonFinite(observed, chunkFrames: chunkFrames)
        return Lane3SpectralDifferentialReport(
            evidenceScope:"LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY", globalLagFramesApplied:globalLagFrames,
            windowSize:configuration.windowSize, hopSize:configuration.hopSize, windowsAnalyzed:observations.count,
            expectedFrequencyRatio:configuration.expectedFrequencyRatio, estimatedFrequencyRatio:search.ratio,
            frequencyRatioErrorCents:centsError(actualRatio:search.ratio,expectedRatio:configuration.expectedFrequencyRatio),
            expectedScaleCorrelation:expectedScale,bestScaleCorrelation:search.correlation,spectralPeakMatches:peaks,
            medianSpectralPeakRatioErrorCents:median(signed),p95AbsoluteSpectralPeakRatioErrorCents:absolute.isEmpty ? nil : percentile95(absolute),
            meanLogSpectralDistanceDB:mean(logDistances),p95LogSpectralDistanceDB:percentile95(logDistances),
            meanAbsoluteCentroidRatioErrorCents:mean(centroidErrors),meanAbsoluteSpectralFlatnessDeltaDB:mean(flatness),
            meanAbsoluteHighBandEnergyDeltaDB:mean(high),meanBandEnergyCosineDistance:mean(bands),rmsEnvelopeCorrelation:correlation(refRMS,obsRMS),
            meanSpectralFluxDelta:fluxDelta,referenceNonFiniteSampleCount:refNonFinite,observedNonFiniteSampleCount:obsNonFinite,
            windowObservations:observations,perceptualClaimAllowed:false,parityPromotionAllowed:false)
    }

}
