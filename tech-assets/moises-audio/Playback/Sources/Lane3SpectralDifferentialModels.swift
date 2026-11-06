import Foundation

public enum Lane3SpectralDifferentialError: Error, Equatable, Sendable {
    case invalidFormat
    case sampleRateMismatch(expected: Double, actual: Double)
    case channelMismatch(expected: Int, actual: Int)
    case invalidConfiguration
    case insufficientComparableFrames
}

public struct Lane3SpectralDifferentialConfiguration: Equatable, Codable, Sendable {
    public let windowSize: Int
    public let hopSize: Int
    public let minimumFrequencyHz: Double
    public let maximumFrequencyHz: Double
    public let expectedFrequencyRatio: Double
    public let frequencyRatioSearchRadiusCents: Double
    public let frequencyRatioSearchStepCents: Double
    public let highBandStartHz: Double
    public let spectralFloorDB: Double
    public let minimumWindowRMS: Double
    public let maximumWindows: Int

    public init(
        windowSize: Int = 2_048,
        hopSize: Int = 512,
        minimumFrequencyHz: Double = 40,
        maximumFrequencyHz: Double = 16_000,
        expectedFrequencyRatio: Double = 1,
        frequencyRatioSearchRadiusCents: Double = 200,
        frequencyRatioSearchStepCents: Double = 10,
        highBandStartHz: Double = 6_000,
        spectralFloorDB: Double = -120,
        minimumWindowRMS: Double = 1e-7,
        maximumWindows: Int = 512
    ) {
        self.windowSize = windowSize
        self.hopSize = hopSize
        self.minimumFrequencyHz = minimumFrequencyHz
        self.maximumFrequencyHz = maximumFrequencyHz
        self.expectedFrequencyRatio = expectedFrequencyRatio
        self.frequencyRatioSearchRadiusCents = frequencyRatioSearchRadiusCents
        self.frequencyRatioSearchStepCents = frequencyRatioSearchStepCents
        self.highBandStartHz = highBandStartHz
        self.spectralFloorDB = spectralFloorDB
        self.minimumWindowRMS = minimumWindowRMS
        self.maximumWindows = maximumWindows
    }
}

public struct Lane3SpectralWindowObservation: Equatable, Codable, Sendable {
    public let referenceStartFrame: Int64
    public let observedStartFrame: Int64
    public let logSpectralDistanceDB: Double
    public let spectralCentroidRatioErrorCents: Double
    public let spectralFlatnessDeltaDB: Double
    public let highBandEnergyDeltaDB: Double
    public let bandEnergyCosineDistance: Double
    public let referenceRMS: Double
    public let observedRMS: Double
}


public struct Lane3SpectralPeakMatchObservation: Equatable, Codable, Sendable {
    public let referenceFrequencyHz: Double
    public let expectedObservedFrequencyHz: Double
    public let observedFrequencyHz: Double
    public let ratioErrorCents: Double
}

public struct Lane3SpectralDifferentialReport: Equatable, Codable, Sendable {
    public let evidenceScope: String
    public let globalLagFramesApplied: Int
    public let windowSize: Int
    public let hopSize: Int
    public let windowsAnalyzed: Int
    public let expectedFrequencyRatio: Double
    public let estimatedFrequencyRatio: Double
    public let frequencyRatioErrorCents: Double
    public let expectedScaleCorrelation: Double
    public let bestScaleCorrelation: Double
    public let spectralPeakMatches: [Lane3SpectralPeakMatchObservation]
    public let medianSpectralPeakRatioErrorCents: Double?
    public let p95AbsoluteSpectralPeakRatioErrorCents: Double?
    public let meanLogSpectralDistanceDB: Double
    public let p95LogSpectralDistanceDB: Double
    public let meanAbsoluteCentroidRatioErrorCents: Double
    public let meanAbsoluteSpectralFlatnessDeltaDB: Double
    public let meanAbsoluteHighBandEnergyDeltaDB: Double
    public let meanBandEnergyCosineDistance: Double
    public let rmsEnvelopeCorrelation: Double
    public let meanSpectralFluxDelta: Double
    public let referenceNonFiniteSampleCount: Int64
    public let observedNonFiniteSampleCount: Int64
    public let windowObservations: [Lane3SpectralWindowObservation]
    public let perceptualClaimAllowed: Bool
    public let parityPromotionAllowed: Bool
}

/// Lane-3 spectral/perceptual-proxy differential. This intentionally does not claim a standardized
/// perceptual score (PESQ/POLQA/PEAQ) or human audibility. It adds deterministic STFT evidence for
/// tempo/pitch evaluation: expected frequency-scale tracking, log-spectral distance, coarse band
/// shape, centroid, flatness, high-band energy and transient spectral-flux behavior.
