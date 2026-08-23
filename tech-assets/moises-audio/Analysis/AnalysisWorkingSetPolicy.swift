import Foundation

public struct AnalysisPreparationDiagnostics: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let analysisSampleRate: Double
    public let durationSeconds: Double
    public let sourceSampleCount: Int
    public let analysisSampleCount: Int
    public let sourcePCMBytes: Int64
    public let analysisPCMBytes: Int64
    public let avoidedLegacyWholeTrackDoubleBytes: Int64
    public let sampleRateReductionRatio: Double
    public let usedResampling: Bool

    enum CodingKeys: String, CodingKey {
        case sourceSampleRate = "source_sample_rate"
        case analysisSampleRate = "analysis_sample_rate"
        case durationSeconds = "duration_seconds"
        case sourceSampleCount = "source_sample_count"
        case analysisSampleCount = "analysis_sample_count"
        case sourcePCMBytes = "source_pcm_bytes"
        case analysisPCMBytes = "analysis_pcm_bytes"
        case avoidedLegacyWholeTrackDoubleBytes = "avoided_legacy_whole_track_double_bytes"
        case sampleRateReductionRatio = "sample_rate_reduction_ratio"
        case usedResampling = "used_resampling"
    }
}

public enum AnalysisWorkingSetPolicy {
    public static let maximumAnalysisSampleRate = 8_000.0
    public static let maximumAbsoluteSample: Float = 16
    public static let maximumRMSProbeSamples = 1_000_000

    public static func prepare(signal: AnalysisSignal) -> (signal: AnalysisSignal, diagnostics: AnalysisPreparationDiagnostics) {
        let targetSampleRate = min(signal.sampleRate, maximumAnalysisSampleRate)
        let needsResampling = signal.sampleRate > targetSampleRate * 1.05
        let prepared: AnalysisSignal

        if needsResampling {
            let ratio = signal.sampleRate / targetSampleRate
            let outputCount = max(1, Int((signal.durationSeconds * targetSampleRate).rounded()))
            var output = Array(repeating: Float(0), count: outputCount)

            for outputIndex in 0..<outputCount {
                let rawStart = Int((Double(outputIndex) * ratio).rounded(.down))
                let rawEnd = Int((Double(outputIndex + 1) * ratio).rounded(.down))
                let sourceStart = min(signal.monoSamples.count, max(0, rawStart))
                let sourceEnd = min(
                    signal.monoSamples.count,
                    max(sourceStart + 1, rawEnd)
                )
                guard sourceStart < signal.monoSamples.count else { break }

                var sum = 0.0
                var count = 0
                for sourceIndex in sourceStart..<sourceEnd {
                    let value = boundedFinite(signal.monoSamples[sourceIndex])
                    sum += Double(value)
                    count += 1
                }
                output[outputIndex] = count > 0 ? Float(sum / Double(count)) : 0
            }
            prepared = AnalysisSignal(sampleRate: targetSampleRate, monoSamples: output)
        } else {
            var requiresCopy = false
            for sample in signal.monoSamples {
                if !sample.isFinite || abs(sample) > maximumAbsoluteSample {
                    requiresCopy = true
                    break
                }
            }
            if requiresCopy {
                prepared = AnalysisSignal(
                    sampleRate: signal.sampleRate,
                    monoSamples: signal.monoSamples.map(boundedFinite)
                )
            } else {
                prepared = signal
            }
        }

        return (
            prepared,
            diagnostics(
                sourceSampleRate: signal.sampleRate,
                sourceSampleCount: signal.monoSamples.count,
                analysisSampleRate: prepared.sampleRate,
                analysisSampleCount: prepared.monoSamples.count
            )
        )
    }

    public static func diagnostics(
        sourceSampleRate: Double,
        sourceSampleCount: Int,
        analysisSampleRate: Double,
        analysisSampleCount: Int
    ) -> AnalysisPreparationDiagnostics {
        let duration = sourceSampleRate > 0 ? Double(sourceSampleCount) / sourceSampleRate : 0
        let sourceBytes = Int64(sourceSampleCount) * Int64(MemoryLayout<Float>.stride)
        let analysisBytes = Int64(analysisSampleCount) * Int64(MemoryLayout<Float>.stride)
        let avoidedDoubleBytes = Int64(sourceSampleCount) * Int64(MemoryLayout<Double>.stride)
        return AnalysisPreparationDiagnostics(
            sourceSampleRate: sourceSampleRate,
            analysisSampleRate: analysisSampleRate,
            durationSeconds: duration,
            sourceSampleCount: sourceSampleCount,
            analysisSampleCount: analysisSampleCount,
            sourcePCMBytes: sourceBytes,
            analysisPCMBytes: analysisBytes,
            avoidedLegacyWholeTrackDoubleBytes: avoidedDoubleBytes,
            sampleRateReductionRatio: analysisSampleRate > 0 ? sourceSampleRate / analysisSampleRate : 1,
            usedResampling: analysisSampleRate + 1e-9 < sourceSampleRate
        )
    }

    public static func estimate(sourceSampleRate: Double, durationSeconds: Double) -> AnalysisPreparationDiagnostics {
        guard sourceSampleRate.isFinite, sourceSampleRate > 0,
              durationSeconds.isFinite, durationSeconds >= 0 else {
            return diagnostics(
                sourceSampleRate: max(1, sourceSampleRate.isFinite ? sourceSampleRate : 1),
                sourceSampleCount: 0,
                analysisSampleRate: max(1, min(maximumAnalysisSampleRate, sourceSampleRate.isFinite ? sourceSampleRate : 1)),
                analysisSampleCount: 0
            )
        }
        let sourceCount = max(0, Int((sourceSampleRate * durationSeconds).rounded()))
        let analysisRate = min(sourceSampleRate, maximumAnalysisSampleRate)
        let analysisCount = max(0, Int((analysisRate * durationSeconds).rounded()))
        return diagnostics(
            sourceSampleRate: sourceSampleRate,
            sourceSampleCount: sourceCount,
            analysisSampleRate: analysisRate,
            analysisSampleCount: analysisCount
        )
    }

    static func finiteWindow(_ samples: [Float], range: Range<Int>) -> [Double] {
        let lower = max(0, min(samples.count, range.lowerBound))
        let upper = max(lower, min(samples.count, range.upperBound))
        var output: [Double] = []
        output.reserveCapacity(upper - lower)
        for index in lower..<upper {
            output.append(Double(boundedFinite(samples[index])))
        }
        return output
    }

    static func rms(_ samples: [Float], range: Range<Int>? = nil, maximumSamples: Int? = nil) -> Double {
        let lower = max(0, min(samples.count, range?.lowerBound ?? 0))
        let upper = max(lower, min(samples.count, range?.upperBound ?? samples.count))
        guard upper > lower else { return 0 }
        let length = upper - lower
        let limit = max(1, maximumSamples ?? length)
        let stride = max(1, Int(ceil(Double(length) / Double(limit))))
        var sumSquares = 0.0
        var count = 0
        var index = lower
        while index < upper {
            let value = Double(boundedFinite(samples[index]))
            sumSquares += value * value
            count += 1
            index += stride
        }
        return count > 0 ? sqrt(sumSquares / Double(count)) : 0
    }

    static func boundedFinite(_ sample: Float) -> Float {
        guard sample.isFinite else { return 0 }
        return min(maximumAbsoluteSample, max(-maximumAbsoluteSample, sample))
    }
}
