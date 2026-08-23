#if canImport(UIKit) && canImport(Darwin)
import Foundation
import UIKit
import Darwin

@MainActor
public final class AnalysisIOSDevicePerformanceSession {
    public struct Configuration: Sendable {
        public let sampleIntervalSeconds: Double
        public let maximumSampleCount: Int

        public init(sampleIntervalSeconds: Double = 1.0, maximumSampleCount: Int = 4_096) {
            self.sampleIntervalSeconds = sampleIntervalSeconds
            self.maximumSampleCount = maximumSampleCount
        }
    }

    private let configuration: Configuration
    private let provenance: AnalysisDevicePerformanceProvenance
    private let startUptime: TimeInterval
    private let originalBatteryMonitoringEnabled: Bool

    private var lastSampleOffset: Double?
    private var memorySamples: [AnalysisDeviceMemorySample] = []
    private var thermalSamples: [AnalysisDeviceThermalSample] = []
    private var batterySamples: [AnalysisDeviceBatterySample] = []
    private var pressureEvents: [AnalysisDeviceMemoryPressureEvent] = []
    private var cancellationRequestedOffset: Double?
    private var cancellationObservedOffset: Double?
    private var memoryWarningToken: NSObjectProtocol?
    private var limitations: Set<String> = []
    private var finished = false

    public init(
        runID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        manifestID: String,
        manifestSHA256: String,
        fixtureID: String,
        fixtureDurationSeconds: Double,
        configuration: Configuration = .init()
    ) {
        self.configuration = configuration
        self.startUptime = ProcessInfo.processInfo.systemUptime
        self.originalBatteryMonitoringEnabled = UIDevice.current.isBatteryMonitoringEnabled

        #if targetEnvironment(simulator)
        let runtime: AnalysisDeviceRuntimeClass = .iOSSimulator
        #else
        let runtime: AnalysisDeviceRuntimeClass = .physicalIOSDevice
        #endif

        let bundle = Bundle.main
        self.provenance = .init(
            runID: runID,
            runKind: runKind,
            startedAt: Date(),
            runtimeClass: runtime,
            deviceModel: Self.deviceModelIdentifier(),
            osVersion: UIDevice.current.systemVersion,
            appBundleIdentifier: bundle.bundleIdentifier ?? "",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            buildVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            manifestID: manifestID,
            manifestSHA256: manifestSHA256,
            fixtureID: fixtureID,
            fixtureDurationSeconds: fixtureDurationSeconds
        )

        UIDevice.current.isBatteryMonitoringEnabled = true
        self.memoryWarningToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.recordMemoryWarning() }
        }

        sample(force: true)
    }

    deinit {
        if let memoryWarningToken { NotificationCenter.default.removeObserver(memoryWarningToken) }
    }

    public func sample(force: Bool = false) {
        guard !finished else { return }
        let offset = elapsed()
        if !force {
            if memorySamples.count >= configuration.maximumSampleCount {
                limitations.insert("TELEMETRY_SAMPLE_CAP_REACHED")
                return
            }
            if let lastSampleOffset, offset - lastSampleOffset < configuration.sampleIntervalSeconds { return }
        }
        lastSampleOffset = offset
        memorySamples.append(Self.memorySample(offsetSeconds: offset))
        thermalSamples.append(Self.thermalSample(offsetSeconds: offset))
        batterySamples.append(Self.batterySample(offsetSeconds: offset))
    }

    public func recordCancellationRequested() {
        guard !finished, cancellationRequestedOffset == nil else { return }
        cancellationRequestedOffset = elapsed()
    }

    public func recordCancellationObserved() {
        guard !finished, cancellationObservedOffset == nil else { return }
        cancellationObservedOffset = elapsed()
    }

    public func finish(completedNormally: Bool, failureDescription: String? = nil) -> AnalysisDevicePerformanceEvidence {
        if !finished { sample(force: true); finished = true }
        if let memoryWarningToken {
            NotificationCenter.default.removeObserver(memoryWarningToken)
            self.memoryWarningToken = nil
        }
        UIDevice.current.isBatteryMonitoringEnabled = originalBatteryMonitoringEnabled

        let wall = elapsed()
        let memoryAvailable = !memorySamples.isEmpty && memorySamples.allSatisfy { $0.residentBytes != nil && $0.physicalFootprintBytes != nil }
        let thermalAvailable = !thermalSamples.isEmpty && thermalSamples.allSatisfy { $0.state != .unavailable }
        let batteryAvailable = batterySamples.count >= 2 && batterySamples.allSatisfy { $0.levelFraction != nil && $0.state != .unavailable }

        return .init(
            provenance: provenance,
            finishedAt: Date(),
            wallSeconds: wall,
            requestedSampleIntervalSeconds: configuration.sampleIntervalSeconds,
            maximumSampleCount: configuration.maximumSampleCount,
            memoryTelemetry: memoryAvailable ? .availableChannel : .unavailable("TASK_VM_INFO_NOT_AVAILABLE_FOR_ALL_SAMPLES"),
            thermalTelemetry: thermalAvailable ? .availableChannel : .unavailable("PROCESS_INFO_THERMAL_STATE_UNAVAILABLE"),
            batteryTelemetry: batteryAvailable ? .availableChannel : .unavailable("UIDEVICE_BATTERY_LEVEL_OR_STATE_UNAVAILABLE"),
            memoryPressureObservation: .availableChannel,
            memorySamples: memorySamples,
            thermalSamples: thermalSamples,
            batterySamples: batterySamples,
            memoryPressureEvents: pressureEvents,
            cancellation: .init(requestedOffsetSeconds: cancellationRequestedOffset, observedTerminationOffsetSeconds: cancellationObservedOffset),
            completedNormally: completedNormally,
            failureDescription: failureDescription,
            limitations: limitations.sorted()
        )
    }

    private func elapsed() -> Double { max(0, ProcessInfo.processInfo.systemUptime - startUptime) }

    private func recordMemoryWarning() {
        guard !finished else { return }
        if pressureEvents.count >= configuration.maximumSampleCount {
            limitations.insert("MEMORY_WARNING_EVENT_CAP_REACHED")
            return
        }
        pressureEvents.append(.init(offsetSeconds: elapsed(), source: "UIApplication.didReceiveMemoryWarningNotification", detail: "MEMORY_WARNING"))
    }

    private static func memorySample(offsetSeconds: Double) -> AnalysisDeviceMemorySample {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard status == KERN_SUCCESS else {
            let reason = "task_info(TASK_VM_INFO)_KERN_\(status)"
            return .init(offsetSeconds: offsetSeconds, residentBytes: nil, residentUnavailableReason: reason, physicalFootprintBytes: nil, physicalFootprintUnavailableReason: reason)
        }
        return .init(offsetSeconds: offsetSeconds, residentBytes: UInt64(info.resident_size), physicalFootprintBytes: UInt64(info.phys_footprint))
    }

    private static func thermalSample(offsetSeconds: Double) -> AnalysisDeviceThermalSample {
        let value: AnalysisDeviceThermalState
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: value = .nominal
        case .fair: value = .fair
        case .serious: value = .serious
        case .critical: value = .critical
        @unknown default: value = .unavailable
        }
        return value == .unavailable
            ? .init(offsetSeconds: offsetSeconds, state: .unavailable, unavailableReason: "UNKNOWN_PROCESS_INFO_THERMAL_STATE")
            : .init(offsetSeconds: offsetSeconds, state: value)
    }

    private static func batterySample(offsetSeconds: Double) -> AnalysisDeviceBatterySample {
        let device = UIDevice.current
        let level = Double(device.batteryLevel)
        let state: AnalysisDeviceBatteryState
        switch device.batteryState {
        case .unknown: state = .unknown
        case .unplugged: state = .unplugged
        case .charging: state = .charging
        case .full: state = .full
        @unknown default: state = .unavailable
        }
        guard level >= 0, level <= 1, state != .unavailable else {
            return .init(offsetSeconds: offsetSeconds, levelFraction: nil, state: .unavailable, unavailableReason: "UIDEVICE_BATTERY_TELEMETRY_UNAVAILABLE")
        }
        return .init(offsetSeconds: offsetSeconds, levelFraction: level, state: state)
    }

    private static func deviceModelIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let value = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !value.isEmpty { return value }
        #endif
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, child in
            guard let value = child.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }
}
#endif
