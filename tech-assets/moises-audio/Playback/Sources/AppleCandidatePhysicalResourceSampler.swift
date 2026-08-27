#if os(iOS) && canImport(UIKit) && canImport(CryptoKit)
import CryptoKit
import Darwin
import Foundation
import UIKit

public enum Lane3AppleCandidatePhysicalResourceSamplerError: Error, Equatable, Sendable {
    case recorderFinished
    case batteryLevelUnavailable
    case batteryStateUnavailable
    case thermalStateUnavailable
    case residentSetQueryFailed(code: Int32)
}

public struct Lane3AppleCandidatePhysicalResourceTraceResult: Sendable {
    public let receipt: Lane3PhysicalEvidenceResourceTraceReceipt
    public let canonicalArtifactData: Data

    public init(
        receipt: Lane3PhysicalEvidenceResourceTraceReceipt,
        canonicalArtifactData: Data
    ) {
        self.receipt = receipt
        self.canonicalArtifactData = canonicalArtifactData
    }
}

/// Selected-iOS AW52 sampler for the candidate app's own process/device resource evidence.
///
/// The host should call `sample()` every 15 seconds while the rights-cleared long-track scenario is
/// running. AW52 does not attempt to inspect another app's process RSS. Current-Moises resource
/// evidence remains an HQ measurement-contract question when stock-iPhone APIs do not expose it.
@MainActor
public final class Lane3AppleCandidatePhysicalResourceRecorder {
    public static let recommendedSamplingIntervalSeconds =
        Lane3CandidatePhysicalResourceTraceAccumulator.recommendedSamplingIntervalSeconds

    private let sessionIdentifier: String
    private let device: UIDevice
    private let batteryMonitoringWasInitiallyEnabled: Bool
    private var accumulator = Lane3CandidatePhysicalResourceTraceAccumulator()
    private var finished = false

    public init(sessionIdentifier: String, device: UIDevice = .current) {
        self.sessionIdentifier = sessionIdentifier
        self.device = device
        self.batteryMonitoringWasInitiallyEnabled = device.isBatteryMonitoringEnabled
        if !device.isBatteryMonitoringEnabled {
            device.isBatteryMonitoringEnabled = true
        }
    }

    public var sampleCount: Int { accumulator.sampleCount }

    @discardableResult
    public func sample() throws -> Lane3CandidatePhysicalResourceSample {
        guard !finished else {
            throw Lane3AppleCandidatePhysicalResourceSamplerError.recorderFinished
        }

        let level = Double(device.batteryLevel)
        guard level.isFinite, (0...1).contains(level) else {
            throw Lane3AppleCandidatePhysicalResourceSamplerError.batteryLevelUnavailable
        }

        let externallyPowered: Bool
        switch device.batteryState {
        case .unplugged:
            externallyPowered = false
        case .charging, .full:
            externallyPowered = true
        case .unknown:
            throw Lane3AppleCandidatePhysicalResourceSamplerError.batteryStateUnavailable
        @unknown default:
            throw Lane3AppleCandidatePhysicalResourceSamplerError.batteryStateUnavailable
        }

        let thermal: Lane3CandidatePhysicalThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default:
            throw Lane3AppleCandidatePhysicalResourceSamplerError.thermalStateUnavailable
        }

        let resourceSample = Lane3CandidatePhysicalResourceSample(
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            residentSetBytes: try Self.currentResidentSetBytes(),
            thermalState: thermal,
            batteryLevel: level,
            externalPowerConnected: externallyPowered
        )
        try accumulator.append(resourceSample)
        return resourceSample
    }

    /// Finalizes only a complete AW51-compatible candidate trace. Calling this too early fails
    /// without closing the recorder, so the physical session may continue sampling.
    public func finish() throws -> Lane3AppleCandidatePhysicalResourceTraceResult {
        guard !finished else {
            throw Lane3AppleCandidatePhysicalResourceSamplerError.recorderFinished
        }
        let artifact = try accumulator.canonicalArtifactData(sessionIdentifier: sessionIdentifier)
        let digest = SHA256.hash(data: artifact).map { String(format: "%02x", $0) }.joined()
        let receipt = try accumulator.makeAW51CandidateReceipt(
            sessionIdentifier: sessionIdentifier,
            traceArtifactSHA256: digest
        )
        finished = true
        restoreBatteryMonitoringIfNeeded()
        return Lane3AppleCandidatePhysicalResourceTraceResult(
            receipt: receipt,
            canonicalArtifactData: artifact
        )
    }

    /// Explicit failure/abort path. No valid receipt is emitted from a cancelled trace.
    public func cancel() {
        guard !finished else { return }
        finished = true
        restoreBatteryMonitoringIfNeeded()
    }

    private func restoreBatteryMonitoringIfNeeded() {
        if !batteryMonitoringWasInitiallyEnabled {
            device.isBatteryMonitoringEnabled = false
        }
    }

    private static func currentResidentSetBytes() throws -> UInt64 {
        var info = mach_task_basic_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else {
            throw Lane3AppleCandidatePhysicalResourceSamplerError.residentSetQueryFailed(code: result)
        }
        guard info.resident_size > 0 else {
            throw Lane3CandidatePhysicalResourceTraceError.invalidResidentSetBytes
        }
        return UInt64(info.resident_size)
    }
}
#endif
