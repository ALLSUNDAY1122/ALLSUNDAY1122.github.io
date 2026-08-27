import Foundation

public enum Lane3CandidatePhysicalThermalState: UInt8, Codable, CaseIterable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
}

public struct Lane3CandidatePhysicalResourceSample: Equatable, Codable, Sendable {
    public let uptimeSeconds: Double
    public let residentSetBytes: UInt64
    public let thermalState: Lane3CandidatePhysicalThermalState
    public let batteryLevel: Double
    public let externalPowerConnected: Bool

    public init(
        uptimeSeconds: Double,
        residentSetBytes: UInt64,
        thermalState: Lane3CandidatePhysicalThermalState,
        batteryLevel: Double,
        externalPowerConnected: Bool
    ) {
        self.uptimeSeconds = uptimeSeconds
        self.residentSetBytes = residentSetBytes
        self.thermalState = thermalState
        self.batteryLevel = batteryLevel
        self.externalPowerConnected = externalPowerConnected
    }
}

public enum Lane3CandidatePhysicalResourceTraceError: Error, Equatable, Sendable {
    case invalidSessionIdentifier
    case invalidUptime
    case nonMonotonicUptime(previous: Double, next: Double)
    case invalidResidentSetBytes
    case invalidBatteryLevel
    case insufficientSamples(required: Int, observed: Int)
    case insufficientDuration(requiredSeconds: Double, observedSeconds: Double)
    case samplingGapExceeded(maximumAllowedSeconds: Double, observedSeconds: Double)
    case externalPowerConnected
    case invalidArtifactDigest
}

/// Portable AW52 accumulator used by the selected-iOS sampler and by Linux regression tests.
/// It intentionally records only aggregate process/device resource observations: no audio, file path,
/// project identifier, persistent device identifier, or individual playback generation/ticket.
public struct Lane3CandidatePhysicalResourceTraceAccumulator: Sendable {
    public static let recommendedSamplingIntervalSeconds: Double = 15
    public static let maximumSamplingIntervalSeconds: Double = 30
    public static let minimumDurationSeconds: Double = 1_800
    public static let minimumSamples: Int = 60

    private var samples: [Lane3CandidatePhysicalResourceSample] = []

    public init() {}

    public var sampleCount: Int { samples.count }

    public var latestSample: Lane3CandidatePhysicalResourceSample? { samples.last }

    public mutating func append(_ sample: Lane3CandidatePhysicalResourceSample) throws {
        guard sample.uptimeSeconds.isFinite, sample.uptimeSeconds >= 0 else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidUptime
        }
        if let previous = samples.last?.uptimeSeconds, sample.uptimeSeconds <= previous {
            throw Lane3CandidatePhysicalResourceTraceError.nonMonotonicUptime(
                previous: previous,
                next: sample.uptimeSeconds
            )
        }
        guard sample.residentSetBytes > 0 else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidResidentSetBytes
        }
        guard sample.batteryLevel.isFinite, (0...1).contains(sample.batteryLevel) else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidBatteryLevel
        }
        samples.append(sample)
    }

    /// Binary canonical artifact for hashing/storage by the selected Apple recorder.
    /// Doubles are bound by IEEE-754 bitPattern and integers are little-endian.
    public func canonicalArtifactData(sessionIdentifier: String) throws -> Data {
        let session = sessionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !session.isEmpty, session.utf8.count <= 128 else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidSessionIdentifier
        }

        var data = Data("LANE3_AW52_CANDIDATE_RESOURCE_TRACE_V1\0".utf8)
        let sessionBytes = Array(session.utf8)
        appendLittleEndian(UInt64(sessionBytes.count), to: &data)
        data.append(contentsOf: sessionBytes)
        appendLittleEndian(UInt64(samples.count), to: &data)

        for sample in samples {
            appendLittleEndian(sample.uptimeSeconds.bitPattern, to: &data)
            appendLittleEndian(sample.residentSetBytes, to: &data)
            data.append(sample.thermalState.rawValue)
            appendLittleEndian(sample.batteryLevel.bitPattern, to: &data)
            data.append(sample.externalPowerConnected ? 1 : 0)
        }
        return data
    }

    public func makeAW51CandidateReceipt(
        sessionIdentifier: String,
        traceArtifactSHA256: String
    ) throws -> Lane3PhysicalEvidenceResourceTraceReceipt {
        _ = try canonicalArtifactData(sessionIdentifier: sessionIdentifier)
        guard isLowercaseHex(traceArtifactSHA256, length: 64) else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidArtifactDigest
        }
        guard samples.count >= Self.minimumSamples else {
            throw Lane3CandidatePhysicalResourceTraceError.insufficientSamples(
                required: Self.minimumSamples,
                observed: samples.count
            )
        }
        guard let first = samples.first, let last = samples.last else {
            throw Lane3CandidatePhysicalResourceTraceError.insufficientSamples(
                required: Self.minimumSamples,
                observed: samples.count
            )
        }
        let duration = last.uptimeSeconds - first.uptimeSeconds
        guard duration >= Self.minimumDurationSeconds else {
            throw Lane3CandidatePhysicalResourceTraceError.insufficientDuration(
                requiredSeconds: Self.minimumDurationSeconds,
                observedSeconds: duration
            )
        }

        var maximumGap = 0.0
        if samples.count > 1 {
            for index in 1..<samples.count {
                maximumGap = max(maximumGap, samples[index].uptimeSeconds - samples[index - 1].uptimeSeconds)
            }
        }
        guard maximumGap > 0, maximumGap <= Self.maximumSamplingIntervalSeconds else {
            throw Lane3CandidatePhysicalResourceTraceError.samplingGapExceeded(
                maximumAllowedSeconds: Self.maximumSamplingIntervalSeconds,
                observedSeconds: maximumGap
            )
        }
        guard !samples.contains(where: { $0.externalPowerConnected }) else {
            throw Lane3CandidatePhysicalResourceTraceError.externalPowerConnected
        }

        var nominal = 0
        var fair = 0
        var serious = 0
        var critical = 0
        var peakRSS: UInt64 = 0
        for sample in samples {
            peakRSS = max(peakRSS, sample.residentSetBytes)
            switch sample.thermalState {
            case .nominal: nominal += 1
            case .fair: fair += 1
            case .serious: serious += 1
            case .critical: critical += 1
            }
        }

        return Lane3PhysicalEvidenceResourceTraceReceipt(
            sessionIdentifier: sessionIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: .candidate,
            observedDurationSeconds: duration,
            sampleCount: samples.count,
            maximumSampleIntervalSeconds: maximumGap,
            peakRSSBytes: peakRSS,
            thermalNominalSamples: nominal,
            thermalFairSamples: fair,
            thermalSeriousSamples: serious,
            thermalCriticalSamples: critical,
            batteryStartLevel: first.batteryLevel,
            batteryEndLevel: last.batteryLevel,
            externalPowerConnectedDuringBatteryWindow: false,
            traceArtifactSHA256: traceArtifactSHA256
        )
    }

    private func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }

    private func appendLittleEndian(_ value: UInt64, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { raw in
            data.append(contentsOf: raw)
        }
    }
}
