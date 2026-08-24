import Foundation

public struct AnalysisPreparedReaderDiagnostics: Codable, Equatable, Sendable {
    public let sourceSampleRate: Double
    public let analysisSampleRate: Double
    public let durationSeconds: Double
    public let sourceSampleCount: Int
    public let analysisSampleCount: Int
    public let sourcePCMBytes: Int64
    public let logicalPreparedPCMBytes: Int64
    public let maximumCachedPreparedPCMBytes: Int64
    public let sectionEnergyFeaturePCMBytesEstimate: Int64
    public let avoidedWholeTrackPreparedPCMAllocationBytes: Int64
    public let usedResampling: Bool
}

public final class AnalysisPreparedSampleReader {
    public static let defaultBlockSampleCount = 16_384
    public let sourceSampleRate: Double
    public let sampleRate: Double
    public let sampleCount: Int
    public let durationSeconds: Double
    public let diagnostics: AnalysisPreparedReaderDiagnostics

    private let sourceSamples: [Float]
    private let ratio: Double
    private let needsResampling: Bool
    private let blockSampleCount: Int
    private var primary: (start: Int, values: [Float])?
    private var secondary: (start: Int, values: [Float])?

    public init(signal: AnalysisSignal, blockSampleCount: Int = defaultBlockSampleCount) {
        precondition(blockSampleCount >= 1_024)
        sourceSampleRate = signal.sampleRate
        sourceSamples = signal.monoSamples
        let target = min(signal.sampleRate, AnalysisWorkingSetPolicy.maximumAnalysisSampleRate)
        sampleRate = target
        needsResampling = signal.sampleRate > target * 1.05
        ratio = signal.sampleRate / target
        if needsResampling {
            sampleCount = max(1, Int((signal.durationSeconds * target).rounded()))
        } else {
            sampleCount = signal.monoSamples.count
        }
        durationSeconds = target > 0 ? Double(sampleCount) / target : 0
        self.blockSampleCount = blockSampleCount
        let sourceBytes = Int64(signal.monoSamples.count) * Int64(MemoryLayout<Float>.stride)
        let preparedBytes = Int64(sampleCount) * Int64(MemoryLayout<Float>.stride)
        diagnostics = .init(
            sourceSampleRate: signal.sampleRate,
            analysisSampleRate: target,
            durationSeconds: durationSeconds,
            sourceSampleCount: signal.monoSamples.count,
            analysisSampleCount: sampleCount,
            sourcePCMBytes: sourceBytes,
            logicalPreparedPCMBytes: preparedBytes,
            maximumCachedPreparedPCMBytes: Int64(blockSampleCount * 2 * MemoryLayout<Float>.stride),
            sectionEnergyFeaturePCMBytesEstimate: Self.sectionEnergyFeatureBytes(durationSeconds: durationSeconds),
            avoidedWholeTrackPreparedPCMAllocationBytes: preparedBytes,
            usedResampling: needsResampling
        )
    }

    public static func estimate(
        sourceSampleRate: Double,
        durationSeconds: Double,
        blockSampleCount: Int = defaultBlockSampleCount
    ) -> AnalysisPreparedReaderDiagnostics {
        precondition(sourceSampleRate.isFinite && sourceSampleRate > 0)
        precondition(durationSeconds.isFinite && durationSeconds >= 0)
        precondition(blockSampleCount >= 1_024)
        let target = min(sourceSampleRate, AnalysisWorkingSetPolicy.maximumAnalysisSampleRate)
        let sourceCount = max(0, Int((sourceSampleRate * durationSeconds).rounded()))
        let needsResampling = sourceSampleRate > target * 1.05
        let analysisCount = needsResampling
            ? max(durationSeconds > 0 ? 1 : 0, Int((durationSeconds * target).rounded()))
            : sourceCount
        let effectiveDuration = target > 0 ? Double(analysisCount) / target : 0
        let sourceBytes = Int64(sourceCount) * Int64(MemoryLayout<Float>.stride)
        let preparedBytes = Int64(analysisCount) * Int64(MemoryLayout<Float>.stride)
        return .init(
            sourceSampleRate: sourceSampleRate,
            analysisSampleRate: target,
            durationSeconds: effectiveDuration,
            sourceSampleCount: sourceCount,
            analysisSampleCount: analysisCount,
            sourcePCMBytes: sourceBytes,
            logicalPreparedPCMBytes: preparedBytes,
            maximumCachedPreparedPCMBytes: Int64(blockSampleCount * 2 * MemoryLayout<Float>.stride),
            sectionEnergyFeaturePCMBytesEstimate: sectionEnergyFeatureBytes(durationSeconds: effectiveDuration),
            avoidedWholeTrackPreparedPCMAllocationBytes: preparedBytes,
            usedResampling: needsResampling
        )
    }

    private static func sectionEnergyFeatureBytes(durationSeconds: Double) -> Int64 {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return 0 }
        let count = max(1, Int((durationSeconds * AnalysisSectionEnergyFeatureExtractor.targetFramesPerSecond).rounded()))
        return Int64(count) * Int64(MemoryLayout<Float>.stride)
    }

    public func sample(at index: Int) throws -> Float {
        guard index >= 0, index < sampleCount else { return 0 }
        let blockStart = (index / blockSampleCount) * blockSampleCount
        if let primary, primary.start == blockStart { return primary.values[index - blockStart] }
        if let secondary, secondary.start == blockStart {
            let value = secondary.values[index - blockStart]
            self.secondary = primary
            self.primary = secondary
            return value
        }
        let loaded = try loadBlock(start: blockStart)
        secondary = primary
        primary = loaded
        return loaded.values[index - blockStart]
    }

    public func rms(range: Range<Int>? = nil, maximumSamples: Int? = nil) throws -> Double {
        let lower = max(0, min(sampleCount, range?.lowerBound ?? 0))
        let upper = max(lower, min(sampleCount, range?.upperBound ?? sampleCount))
        guard upper > lower else { return 0 }
        let length = upper - lower
        let limit = max(1, maximumSamples ?? length)
        let stride = max(1, Int(ceil(Double(length) / Double(limit))))
        var sumSquares = 0.0
        var count = 0
        var index = lower
        while index < upper {
            let value = Double(try sample(at: index))
            sumSquares += value * value
            count += 1
            index += stride
        }
        return count > 0 ? sqrt(sumSquares / Double(count)) : 0
    }

    public func finiteWindow(range: Range<Int>) throws -> [Double] {
        let lower = max(0, min(sampleCount, range.lowerBound))
        let upper = max(lower, min(sampleCount, range.upperBound))
        var output: [Double] = []
        output.reserveCapacity(upper - lower)
        for index in lower..<upper { output.append(Double(try sample(at: index))) }
        return output
    }

    private func loadBlock(start: Int) throws -> (start: Int, values: [Float]) {
        let end = min(sampleCount, start + blockSampleCount)
        var values = Array(repeating: Float(0), count: max(0, end - start))
        for outputIndex in start..<end {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: outputIndex - start, stride: 2_048)
            values[outputIndex - start] = computePreparedSample(outputIndex)
        }
        return (start, values)
    }

    private func computePreparedSample(_ outputIndex: Int) -> Float {
        if !needsResampling {
            guard outputIndex < sourceSamples.count else { return 0 }
            return AnalysisWorkingSetPolicy.boundedFinite(sourceSamples[outputIndex])
        }
        let rawStart = Int((Double(outputIndex) * ratio).rounded(.down))
        let rawEnd = Int((Double(outputIndex + 1) * ratio).rounded(.down))
        let sourceStart = min(sourceSamples.count, max(0, rawStart))
        let sourceEnd = min(sourceSamples.count, max(sourceStart + 1, rawEnd))
        guard sourceStart < sourceSamples.count else { return 0 }
        var sum = 0.0
        var count = 0
        for sourceIndex in sourceStart..<sourceEnd {
            sum += Double(AnalysisWorkingSetPolicy.boundedFinite(sourceSamples[sourceIndex]))
            count += 1
        }
        return count > 0 ? Float(sum / Double(count)) : 0
    }
}

public enum AnalysisSectionEnergyFeatureExtractor {
    public static let targetFramesPerSecond = 100.0

    public static func makeSignal(from reader: AnalysisPreparedSampleReader) throws -> AnalysisSignal {
        try AnalysisCancellationPolicy.check()
        guard reader.durationSeconds > 0, reader.sampleCount > 0 else {
            return AnalysisSignal(sampleRate: 1, monoSamples: [])
        }
        let frameCount = max(1, Int((reader.durationSeconds * targetFramesPerSecond).rounded()))
        let effectiveRate = Double(frameCount) / reader.durationSeconds
        var values = Array(repeating: Float(0), count: frameCount)
        for frame in 0..<frameCount {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: frame, stride: 256)
            let start = Int((Double(frame) * Double(reader.sampleCount) / Double(frameCount)).rounded(.down))
            let rawEnd = Int((Double(frame + 1) * Double(reader.sampleCount) / Double(frameCount)).rounded(.down))
            let end = min(reader.sampleCount, max(start + 1, rawEnd))
            values[frame] = Float(try reader.rms(range: start..<end))
        }
        return AnalysisSignal(sampleRate: effectiveRate, monoSamples: values)
    }
}
