import Foundation

struct AnalysisReusableChordSpectralBin: Sendable {
    let pitchClass: Int
    let coefficient: Double
    let bassWeight: Double?
}

struct AnalysisReusableChordSpectralKernel: Sendable {
    let sampleRate: Double
    let windowSampleCount: Int
    let hannWeights: [Double]
    let bins: [AnalysisReusableChordSpectralBin]

    init(sampleRate: Double, windowSampleCount: Int) {
        precondition(sampleRate.isFinite && sampleRate > 0)
        precondition(windowSampleCount > 0)
        self.sampleRate = sampleRate
        self.windowSampleCount = windowSampleCount
        if windowSampleCount > 1 {
            hannWeights = (0..<windowSampleCount).map { index in
                0.5 - 0.5 * cos((2 * Double.pi * Double(index)) / Double(windowSampleCount - 1))
            }
        } else {
            hannWeights = [1]
        }

        var preparedBins: [AnalysisReusableChordSpectralBin] = []
        preparedBins.reserveCapacity(48)
        for midi in 36...83 {
            let frequency = 440.0 * pow(2.0, Double(midi - 69) / 12.0)
            guard frequency < sampleRate * 0.45 else { continue }
            preparedBins.append(
                .init(
                    pitchClass: (midi % 12 + 12) % 12,
                    coefficient: 2 * cos(2 * Double.pi * frequency / sampleRate),
                    bassWeight: midi <= 59 ? 1.0 + Double(59 - midi) / 46.0 : nil
                )
            )
        }
        bins = preparedBins
    }
}

enum AnalysisChordSpectralBackend: Sendable {
    case referencePerBin
    case interleavedMultiBin
}

struct AnalysisReusableChordSpectralWorkspace {
    let kernel: AnalysisReusableChordSpectralKernel
    var windowedScratch: [Double]
    var recurrenceS1: [Double]
    var recurrenceS2: [Double]
    var backendGuard = AnalysisChordBackendEquivalenceGuard()
    private(set) var classificationCount = 0

    init(sampleRate: Double, windowSampleCount: Int) {
        kernel = .init(sampleRate: sampleRate, windowSampleCount: windowSampleCount)
        windowedScratch = Array(repeating: 0, count: windowSampleCount)
        recurrenceS1 = Array(repeating: 0, count: kernel.bins.count)
        recurrenceS2 = Array(repeating: 0, count: kernel.bins.count)
    }

    mutating func markClassification() { classificationCount += 1 }

    var backendGuardDiagnostics: AnalysisChordBackendGuardDiagnostics {
        backendGuard.diagnostics
    }
}

enum AnalysisChordSpectralEvidenceComputer {
    static func compute(
        samples: [Double],
        workspace: inout AnalysisReusableChordSpectralWorkspace,
        backend: AnalysisChordSpectralBackend
    ) -> AnalysisChordSpectrumEvidence {
        guard samples.count > 1,
              samples.count == workspace.kernel.windowSampleCount else {
            return AnalysisChordSpectrumEvidence(
                chroma: Array(repeating: 0, count: 12),
                bassPitchClass: nil,
                bassDominance: 0
            )
        }

        for index in samples.indices {
            workspace.windowedScratch[index] = samples[index] * workspace.kernel.hannWeights[index]
        }

        let powers: [Double]
        switch backend {
        case .referencePerBin:
            powers = referencePowers(samples: workspace.windowedScratch, bins: workspace.kernel.bins)
        case .interleavedMultiBin:
            powers = interleavedPowers(
                samples: workspace.windowedScratch,
                bins: workspace.kernel.bins,
                s1: &workspace.recurrenceS1,
                s2: &workspace.recurrenceS2
            )
        }

        var chroma = Array(repeating: 0.0, count: 12)
        var bassChroma = Array(repeating: 0.0, count: 12)
        for index in workspace.kernel.bins.indices {
            let bin = workspace.kernel.bins[index]
            let amplitude = sqrt(max(0, powers[index]))
            chroma[bin.pitchClass] += amplitude
            if let bassWeight = bin.bassWeight {
                bassChroma[bin.pitchClass] += amplitude * bassWeight
            }
        }

        let totalBass = bassChroma.reduce(0, +)
        let bassIndex = bassChroma.indices.max(by: { bassChroma[$0] < bassChroma[$1] })
        let bestBass = bassIndex.map { bassChroma[$0] } ?? 0
        let sortedBass = bassChroma.sorted(by: >)
        let secondBass = sortedBass.dropFirst().first ?? 0
        let dominance = totalBass > 1e-12 ? max(0, (bestBass - secondBass) / totalBass) : 0
        return AnalysisChordSpectrumEvidence(
            chroma: chroma,
            bassPitchClass: bestBass > 1e-10 ? bassIndex : nil,
            bassDominance: dominance
        )
    }

    private static func referencePowers(
        samples: [Double],
        bins: [AnalysisReusableChordSpectralBin]
    ) -> [Double] {
        var powers = Array(repeating: 0.0, count: bins.count)
        for binIndex in bins.indices {
            let coefficient = bins[binIndex].coefficient
            var s0 = 0.0
            var s1 = 0.0
            var s2 = 0.0
            for sample in samples {
                s0 = sample + coefficient * s1 - s2
                s2 = s1
                s1 = s0
            }
            powers[binIndex] = max(0, s1 * s1 + s2 * s2 - coefficient * s1 * s2)
        }
        return powers
    }

    private static func interleavedPowers(
        samples: [Double],
        bins: [AnalysisReusableChordSpectralBin],
        s1: inout [Double],
        s2: inout [Double]
    ) -> [Double] {
        if s1.count != bins.count { s1 = Array(repeating: 0, count: bins.count) }
        if s2.count != bins.count { s2 = Array(repeating: 0, count: bins.count) }
        for index in bins.indices {
            s1[index] = 0
            s2[index] = 0
        }

        // Preserve the exact recurrence and each bin's sample order, but traverse
        // the sample window once and update all active bins together. This is a
        // mathematically identical layout change, not an FFT approximation.
        for sample in samples {
            for binIndex in bins.indices {
                let previousS1 = s1[binIndex]
                let s0 = sample + bins[binIndex].coefficient * previousS1 - s2[binIndex]
                s2[binIndex] = previousS1
                s1[binIndex] = s0
            }
        }

        var powers = Array(repeating: 0.0, count: bins.count)
        for binIndex in bins.indices {
            let coefficient = bins[binIndex].coefficient
            let finalS1 = s1[binIndex]
            let finalS2 = s2[binIndex]
            powers[binIndex] = max(
                0,
                finalS1 * finalS1 + finalS2 * finalS2 - coefficient * finalS1 * finalS2
            )
        }
        return powers
    }
}

enum AnalysisReusableChordFrameClassifier {
    static func classify(
        samples: [Double],
        workspace: inout AnalysisReusableChordSpectralWorkspace,
        sampleRate: Double,
        configuration: MusicAnalysisConfiguration,
        vocabulary: ChordVocabularyMode = .conservativeMajorMinor
    ) -> (label: String, confidence: Double?) {
        guard !samples.isEmpty else { return ("N", 1) }
        guard samples.count == workspace.kernel.windowSampleCount,
              sampleRate == workspace.kernel.sampleRate else {
            return ChordFrameClassifier.classify(
                samples: samples,
                sampleRate: sampleRate,
                configuration: configuration,
                vocabulary: vocabulary
            )
        }
        guard rms(samples) >= configuration.noChordRMS else { return ("N", 1) }

        workspace.markClassification()
        switch workspace.backendGuard.state {
        case .verifying:
            let referenceEvidence = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .referencePerBin
            )
            let vectorizedEvidence = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .interleavedMultiBin
            )
            let referenceDecision = AnalysisChordDecisionScorer.classify(
                evidence: referenceEvidence,
                configuration: configuration,
                vocabulary: vocabulary
            )
            let vectorizedDecision = AnalysisChordDecisionScorer.classify(
                evidence: vectorizedEvidence,
                configuration: configuration,
                vocabulary: vocabulary
            )
            return workspace.backendGuard.resolveVerification(
                referenceEvidence: referenceEvidence,
                vectorizedEvidence: vectorizedEvidence,
                referenceDecision: referenceDecision,
                vectorizedDecision: vectorizedDecision
            )

        case .vectorizedVerified:
            let evidence = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .interleavedMultiBin
            )
            let decision = AnalysisChordDecisionScorer.classify(
                evidence: evidence,
                configuration: configuration,
                vocabulary: vocabulary
            )
            workspace.backendGuard.recordVectorizedPublication()
            return decision

        case .scalarFallback:
            let evidence = AnalysisChordSpectralEvidenceComputer.compute(
                samples: samples,
                workspace: &workspace,
                backend: .referencePerBin
            )
            let decision = AnalysisChordDecisionScorer.classify(
                evidence: evidence,
                configuration: configuration,
                vocabulary: vocabulary
            )
            workspace.backendGuard.recordReferencePublication()
            return decision
        }
    }

    private static func rms(_ samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0.0) { $0 + $1 * $1 } / Double(samples.count))
    }
}
