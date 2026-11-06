import Foundation

public enum Lane3SpectralPerceptualDifferentialAnalyzer {
    public static func analyze(
        reference: Lane3PCMBufferDescriptor,
        observed: Lane3PCMBufferDescriptor,
        globalLagFrames: Int = 0,
        configuration: Lane3SpectralDifferentialConfiguration = Lane3SpectralDifferentialConfiguration()
    ) throws -> Lane3SpectralDifferentialReport {
        try validate(reference: reference, observed: observed, configuration: configuration)

        let refCollapsed = collapseToMono(reference)
        let obsCollapsed = collapseToMono(observed)
        let aligned = alignedRanges(
            referenceCount: refCollapsed.samples.count,
            observedCount: obsCollapsed.samples.count,
            lag: globalLagFrames
        )
        guard aligned.count >= configuration.windowSize else {
            throw Lane3SpectralDifferentialError.insufficientComparableFrames
        }

        let starts = selectedWindowStarts(
            comparableFrames: aligned.count,
            windowSize: configuration.windowSize,
            hopSize: configuration.hopSize,
            maximumWindows: configuration.maximumWindows
        )
        guard !starts.isEmpty else {
            throw Lane3SpectralDifferentialError.insufficientComparableFrames
        }

        let hann = hannWindow(configuration.windowSize)
        let nyquistBinCount = configuration.windowSize / 2 + 1
        var aggregateReference = [Double](repeating: 0, count: nyquistBinCount)
        var aggregateObserved = [Double](repeating: 0, count: nyquistBinCount)
        var referenceSpectra: [[Double]] = []
        var observedSpectra: [[Double]] = []
        var referenceRMS: [Double] = []
        var observedRMS: [Double] = []
        var analyzedStarts: [Int] = []
        referenceSpectra.reserveCapacity(starts.count)
        observedSpectra.reserveCapacity(starts.count)
        referenceRMS.reserveCapacity(starts.count)
        observedRMS.reserveCapacity(starts.count)
        analyzedStarts.reserveCapacity(starts.count)

        for localStart in starts {
            let refStart = aligned.referenceStart + localStart
            let obsStart = aligned.observedStart + localStart
            let refFrame = Array(refCollapsed.samples[refStart..<(refStart + configuration.windowSize)])
            let obsFrame = Array(obsCollapsed.samples[obsStart..<(obsStart + configuration.windowSize)])
            let refRMS = rms(refFrame)
            let obsRMS = rms(obsFrame)
            if refRMS < configuration.minimumWindowRMS && obsRMS < configuration.minimumWindowRMS { continue }
            let refPower = powerSpectrum(refFrame, window: hann)
            let obsPower = powerSpectrum(obsFrame, window: hann)
            for bin in 0..<nyquistBinCount {
                aggregateReference[bin] += refPower[bin]
                aggregateObserved[bin] += obsPower[bin]
            }
            analyzedStarts.append(localStart)
            referenceSpectra.append(refPower)
            observedSpectra.append(obsPower)
            referenceRMS.append(refRMS)
            observedRMS.append(obsRMS)
        }
        guard !analyzedStarts.isEmpty else {
            throw Lane3SpectralDifferentialError.insufficientComparableFrames
        }

        let search = estimateFrequencyRatio(
            referencePower: aggregateReference,
            observedPower: aggregateObserved,
            sampleRate: reference.sampleRate,
            configuration: configuration
        )
        let expectedScaleCorrelation = scaleCorrelation(
            referencePower: aggregateReference,
            observedPower: aggregateObserved,
            ratio: configuration.expectedFrequencyRatio,
            sampleRate: reference.sampleRate,
            configuration: configuration
        )
        let peakMatches = spectralPeakMatches(
            referencePower: aggregateReference,
            observedPower: aggregateObserved,
            sampleRate: reference.sampleRate,
            configuration: configuration
        )
        let peakSignedErrors = peakMatches.map(\.ratioErrorCents)
        let peakAbsoluteErrors = peakSignedErrors.map(abs)

        var observations: [Lane3SpectralWindowObservation] = []
        observations.reserveCapacity(analyzedStarts.count)
        var logDistances: [Double] = []
        var centroidErrors: [Double] = []
        var flatnessDeltas: [Double] = []
        var highBandDeltas: [Double] = []
        var bandDistances: [Double] = []
        var referenceFlux: [Double] = []
        var observedFlux: [Double] = []
        var previousReferenceNormalized: [Double]?
        var previousObservedNormalized: [Double]?

        for index in analyzedStarts.indices {
            let refPower = referenceSpectra[index]
            let obsPower = observedSpectra[index]
            let expectedReference = warpedReferencePower(
                referencePower: refPower,
                ratio: configuration.expectedFrequencyRatio,
                outputBinCount: obsPower.count
            )
            let normalizedReference = normalizeSpectrum(expectedReference)
            let normalizedObserved = normalizeSpectrum(obsPower)

            let lsd = logSpectralDistanceDB(
                expectedReference: normalizedReference,
                observed: normalizedObserved,
                sampleRate: reference.sampleRate,
                windowSize: configuration.windowSize,
                configuration: configuration
            )
            let referenceCentroid = spectralCentroidHz(
                power: refPower,
                sampleRate: reference.sampleRate,
                windowSize: configuration.windowSize,
                configuration: configuration
            )
            let observedCentroid = spectralCentroidHz(
                power: obsPower,
                sampleRate: observed.sampleRate,
                windowSize: configuration.windowSize,
                configuration: configuration
            )
            let centroidError = centsError(
                actualRatio: observedCentroid / max(referenceCentroid, 1e-12),
                expectedRatio: configuration.expectedFrequencyRatio
            )
            let refFlatness = spectralFlatness(power: refPower, sampleRate: reference.sampleRate, windowSize: configuration.windowSize, configuration: configuration)
            let obsFlatness = spectralFlatness(power: obsPower, sampleRate: observed.sampleRate, windowSize: configuration.windowSize, configuration: configuration)
            let flatnessDelta = powerLikeDBDelta(observed: obsFlatness, reference: refFlatness)
            let refHigh = highBandEnergyFraction(power: refPower, sampleRate: reference.sampleRate, windowSize: configuration.windowSize, configuration: configuration)
            let obsHigh = highBandEnergyFraction(power: obsPower, sampleRate: observed.sampleRate, windowSize: configuration.windowSize, configuration: configuration)
            let highDelta = powerLikeDBDelta(observed: obsHigh, reference: refHigh)
            let bandDistance = bandEnergyCosineDistance(
                referencePower: expectedReference,
                observedPower: obsPower,
                sampleRate: reference.sampleRate,
                windowSize: configuration.windowSize,
                configuration: configuration
            )

            if let previousReferenceNormalized, let previousObservedNormalized {
                referenceFlux.append(spectralFlux(previous: previousReferenceNormalized, current: normalizedReference))
                observedFlux.append(spectralFlux(previous: previousObservedNormalized, current: normalizedObserved))
            }
            previousReferenceNormalized = normalizedReference
            previousObservedNormalized = normalizedObserved

            observations.append(
                Lane3SpectralWindowObservation(
                    referenceStartFrame: Int64(aligned.referenceStart + analyzedStarts[index]),
                    observedStartFrame: Int64(aligned.observedStart + analyzedStarts[index]),
                    logSpectralDistanceDB: lsd,
                    spectralCentroidRatioErrorCents: centroidError,
                    spectralFlatnessDeltaDB: flatnessDelta,
                    highBandEnergyDeltaDB: highDelta,
                    bandEnergyCosineDistance: bandDistance,
                    referenceRMS: referenceRMS[index],
                    observedRMS: observedRMS[index]
                )
            )
            logDistances.append(lsd)
            centroidErrors.append(abs(centroidError))
            flatnessDeltas.append(abs(flatnessDelta))
            highBandDeltas.append(abs(highDelta))
            bandDistances.append(bandDistance)
        }

        let fluxDelta: Double
        if referenceFlux.isEmpty || observedFlux.isEmpty {
            fluxDelta = 0
        } else {
            fluxDelta = zip(referenceFlux, observedFlux).map { abs($0 - $1) }.reduce(0, +) / Double(min(referenceFlux.count, observedFlux.count))
        }

        return Lane3SpectralDifferentialReport(
            evidenceScope: "LANE3_SPECTRAL_PERCEPTUAL_PROXY_NON_PARITY",
            globalLagFramesApplied: globalLagFrames,
            windowSize: configuration.windowSize,
            hopSize: configuration.hopSize,
            windowsAnalyzed: observations.count,
            expectedFrequencyRatio: configuration.expectedFrequencyRatio,
            estimatedFrequencyRatio: search.ratio,
            frequencyRatioErrorCents: centsError(actualRatio: search.ratio, expectedRatio: configuration.expectedFrequencyRatio),
            expectedScaleCorrelation: expectedScaleCorrelation,
            bestScaleCorrelation: search.correlation,
            spectralPeakMatches: peakMatches,
            medianSpectralPeakRatioErrorCents: median(peakSignedErrors),
            p95AbsoluteSpectralPeakRatioErrorCents: peakAbsoluteErrors.isEmpty ? nil : percentile95(peakAbsoluteErrors),
            meanLogSpectralDistanceDB: mean(logDistances),
            p95LogSpectralDistanceDB: percentile95(logDistances),
            meanAbsoluteCentroidRatioErrorCents: mean(centroidErrors),
            meanAbsoluteSpectralFlatnessDeltaDB: mean(flatnessDeltas),
            meanAbsoluteHighBandEnergyDeltaDB: mean(highBandDeltas),
            meanBandEnergyCosineDistance: mean(bandDistances),
            rmsEnvelopeCorrelation: correlation(referenceRMS, observedRMS),
            meanSpectralFluxDelta: fluxDelta,
            referenceNonFiniteSampleCount: refCollapsed.nonFinite,
            observedNonFiniteSampleCount: obsCollapsed.nonFinite,
            windowObservations: observations,
            perceptualClaimAllowed: false,
            parityPromotionAllowed: false
        )
    }

}
