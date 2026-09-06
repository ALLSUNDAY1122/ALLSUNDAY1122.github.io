import Foundation

public enum StemKind: String, CaseIterable, Sendable, Codable {
    case vocals
    case drums
    case bass
    case other
}

public struct PCMBuffer: Sendable, Equatable {
    public let sampleRate: Double
    public let channels: Int
    public let samples: [Float]

    public init(sampleRate: Double, channels: Int, samples: [Float]) {
        precondition(sampleRate > 0)
        precondition(channels > 0)
        precondition(samples.count % channels == 0)
        self.sampleRate = sampleRate
        self.channels = channels
        self.samples = samples
    }

    public var frameCount: Int { samples.count / channels }

    public var rms: Double {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        } / Double(samples.count)
        return sqrt(meanSquare)
    }
}

public struct SeparationResult: Sendable {
    public let stems: [StemKind: PCMBuffer]
    public let processingSeconds: TimeInterval

    public init(stems: [StemKind: PCMBuffer], processingSeconds: TimeInterval) {
        self.stems = stems
        self.processingSeconds = processingSeconds
    }
}

public protocol SourceSeparating: Sendable {
    func separate(_ mixture: PCMBuffer, requestedStems: Set<StemKind>) async throws -> SeparationResult
}

public enum SeparationQuality {
    /// Scale-Invariant Signal-to-Distortion Ratio (SI-SDR), in dB.
    /// This metric lets model/runtime candidates be compared with the same fixture set.
    public static func siSDR(reference: [Float], estimate: [Float]) -> Double? {
        guard reference.count == estimate.count, !reference.isEmpty else { return nil }

        let referenceEnergy = reference.reduce(0.0) { $0 + Double($1 * $1) }
        guard referenceEnergy > 1e-12 else { return nil }

        let dot = zip(reference, estimate).reduce(0.0) { partial, pair in
            partial + Double(pair.0 * pair.1)
        }
        let scale = dot / referenceEnergy

        var targetEnergy = 0.0
        var noiseEnergy = 0.0
        for index in reference.indices {
            let target = scale * Double(reference[index])
            let noise = Double(estimate[index]) - target
            targetEnergy += target * target
            noiseEnergy += noise * noise
        }

        guard noiseEnergy > 1e-12 else { return 120.0 }
        guard targetEnergy > 1e-12 else { return nil }
        return 10.0 * log10(targetEnergy / noiseEnergy)
    }

    /// Checks whether separated stems approximately reconstruct the original mixture.
    public static func reconstructionError(mixture: PCMBuffer, stems: [PCMBuffer]) -> Double? {
        guard !stems.isEmpty else { return nil }
        guard stems.allSatisfy({ $0.sampleRate == mixture.sampleRate && $0.channels == mixture.channels && $0.samples.count == mixture.samples.count }) else {
            return nil
        }

        var squaredError = 0.0
        for index in mixture.samples.indices {
            let reconstructed = stems.reduce(0.0) { $0 + Double($1.samples[index]) }
            let error = Double(mixture.samples[index]) - reconstructed
            squaredError += error * error
        }
        return sqrt(squaredError / Double(mixture.samples.count))
    }
}
