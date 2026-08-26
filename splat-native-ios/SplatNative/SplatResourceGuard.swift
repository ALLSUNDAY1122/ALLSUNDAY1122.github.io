import Foundation
import Darwin.Mach
import os

struct SplatResourceLimits: Codable, Equatable, Sendable {
    let residentMemoryBudgetBytes: UInt64
    let minimumAvailableMemoryReserveBytes: UInt64
    let maxSplatCount: Int

    static func conservative(physicalMemoryBytes: UInt64) -> SplatResourceLimits {
        let mib: UInt64 = 1_048_576
        let minimumBudget = 700 * mib
        let maximumBudget = 1_536 * mib
        let proportional = physicalMemoryBytes / 100 * 28
        let memoryBudget = min(maximumBudget, max(minimumBudget, proportional))

        // Keep enough headroom to checkpoint/export instead of training until the process is
        // already at its current iOS memory limit. os_proc_available_memory() is dynamic, so this
        // reserve complements rather than replaces the resident-footprint budget below.
        let minimumReserve = 256 * mib
        let maximumReserve = 512 * mib
        let proportionalReserve = physicalMemoryBytes / 100 * 6
        let availableMemoryReserve = min(maximumReserve, max(minimumReserve, proportionalReserve))

        // A degree-3 Gaussian carries parameters, gradients and optimizer state. Use 2 KiB/splat
        // as a deliberately conservative training-time envelope and reserve roughly half of the
        // process budget for images, render buffers and framework overhead.
        let estimatedTrainingBytesPerSplat: UInt64 = 2_048
        let rawCount = Int(memoryBudget / estimatedTrainingBytesPerSplat / 2)
        let splatBudget = min(900_000, max(300_000, rawCount))
        return SplatResourceLimits(
            residentMemoryBudgetBytes: memoryBudget,
            minimumAvailableMemoryReserveBytes: availableMemoryReserve,
            maxSplatCount: splatBudget
        )
    }
}

enum SplatResourcePauseReason: String, Codable, Sendable {
    case memoryWarning
    case availableMemoryReserve
    case residentMemoryBudget
    case splatBudget
    case thermalPressure

    var userMessage: String {
        switch self {
        case .memoryWarning, .availableMemoryReserve, .residentMemoryBudget:
            return "端末のメモリ余力が少なくなったため生成を安全に一時停止しました。ほかのアプリを閉じてから「生成だけもう一度試す」で続きから再開できます"
        case .splatBudget:
            return "3Dデータが端末の安全上限まで細かくなったため生成を一時停止しました。現在の結果を利用するか、より新しい端末で追加生成してください"
        case .thermalPressure:
            return "端末温度が高くなったため生成を安全に一時停止しました。端末が冷えてから「生成だけもう一度試す」で続きから再開できます"
        }
    }

    func diagnosticText(
        evaluation: SplatResourceEvaluation,
        limits: SplatResourceLimits,
        iteration: Int,
        splatCount: Int
    ) -> String {
        func mib(_ bytes: UInt64) -> String {
            String(format: "%.0f", Double(bytes) / 1_048_576.0)
        }
        return "reason=\(rawValue) · iteration=\(iteration) · splats=\(splatCount) · resident=\(mib(evaluation.residentMemoryBytes)) MiB / budget=\(mib(limits.residentMemoryBudgetBytes)) MiB · available=\(mib(evaluation.availableMemoryBytes)) MiB / reserve=\(mib(limits.minimumAvailableMemoryReserveBytes)) MiB"
    }

}

enum SplatReconstructionStopReason: String, Codable, Equatable, Sendable {
    case memoryWarning
    case availableMemoryReserve
    case residentMemoryBudget
    case splatBudget
    case thermal
    case cancellation
    case trainerError
    case other

    init(resourcePauseReason: SplatResourcePauseReason) {
        switch resourcePauseReason {
        case .memoryWarning: self = .memoryWarning
        case .availableMemoryReserve: self = .availableMemoryReserve
        case .residentMemoryBudget: self = .residentMemoryBudget
        case .splatBudget: self = .splatBudget
        case .thermalPressure: self = .thermal
        }
    }

    static func inferred(from outcome: String) -> SplatReconstructionStopReason? {
        if outcome.contains(SplatResourcePauseReason.memoryWarning.rawValue) { return .memoryWarning }
        if outcome.contains(SplatResourcePauseReason.availableMemoryReserve.rawValue) { return .availableMemoryReserve }
        if outcome.contains(SplatResourcePauseReason.residentMemoryBudget.rawValue) { return .residentMemoryBudget }
        if outcome.contains(SplatResourcePauseReason.splatBudget.rawValue) { return .splatBudget }
        if outcome.contains(SplatResourcePauseReason.thermalPressure.rawValue) || outcome.contains("thermal") { return .thermal }
        if outcome.contains("cancel") { return .cancellation }
        if outcome.contains("trainer") { return .trainerError }
        if outcome == "completed" { return nil }
        return outcome.contains("failed") ? .other : nil
    }
}

enum SplatReconstructionPhase: String, Codable, Equatable, Sendable {
    case preflight
    case datasetInit
    case trainerInit
    case checkpointLoad
    case trainingStep
    case densificationOrRefine = "densification-or-refine"
    case checkpointSave
    case export
    case preview
    case unavailable

    static func inferred(from outcome: String) -> SplatReconstructionPhase {
        if outcome.hasPrefix("preflight-") { return .preflight }
        if outcome.hasPrefix("paused-") { return .trainingStep }
        if outcome == "completed" { return .preview }
        return .unavailable
    }
}

enum SplatCheckpointResumeOutcome: String, Codable, Equatable, Sendable {
    case notAttempted
    case noCheckpoint
    case loaded
    case loadFailed

    /// `GaussianTrainer.loadCheckpoint` returns the stored iteration as `Int?`. Iteration zero is
    /// still a successful load, so success must be classified from the optional return rather than
    /// inferred from `trainer.iteration > 0`.
    static func classify(checkpointExists: Bool, loadedIteration: Int?) -> SplatCheckpointResumeOutcome {
        guard checkpointExists else { return .noCheckpoint }
        return loadedIteration != nil ? .loaded : .loadFailed
    }
}

struct SplatReconstructionRunContext: Equatable, Sendable {
    let runID: UUID
    let sessionID: String
    let sourceFrameCount: Int
    let sourceImageWidth: Int?
    let sourceImageHeight: Int?
    let effectiveDownscale: Double?
    let checkpointPath: String?
}

/// Serializes reconstruction runs without retaining Dataset/Trainer themselves.
/// ScanModel keeps the token active until the detached autoreleasepool has returned, which makes
/// retry admission an explicit post-cleanup operation instead of a best-effort timing assumption.
final class SplatTrainingRunGate: @unchecked Sendable {
    struct Token: Hashable, Sendable {
        fileprivate let id: UUID
        var runID: UUID { id }
    }

    private let lock = NSLock()
    private var activeToken: Token?

    var isIdle: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeToken == nil
    }

    func beginRun(id: UUID = UUID()) -> Token? {
        lock.lock()
        defer { lock.unlock() }
        guard activeToken == nil else { return nil }
        let token = Token(id: id)
        activeToken = token
        return token
    }

    func finishRun(_ token: Token) {
        lock.lock()
        if activeToken == token {
            activeToken = nil
        }
        lock.unlock()
    }
}

struct SplatResourceEvaluation: Equatable, Sendable {
    let reason: SplatResourcePauseReason?
    let residentMemoryBytes: UInt64
    let availableMemoryBytes: UInt64
    let peakResidentMemoryBytes: UInt64
    let minimumAvailableMemoryBytes: UInt64
    let peakSplatCount: Int
}

/// Schema v3 retains all v2 keys and only appends optional diagnostic fields so existing v2 JSON
/// remains decodable by this type. M1/M2 can add their own optional fields without rewriting the
/// established reason/phase contract.
struct SplatReconstructionRunReport: Codable, Sendable {
    let schemaVersion: Int
    let startedAt: Date
    let finishedAt: Date
    let elapsedSeconds: Double
    let passStartIteration: Int
    let targetIteration: Int
    let finalIteration: Int
    let finalSplatCount: Int
    let peakSplatCount: Int
    let peakResidentMemoryBytes: UInt64
    let residentMemoryBudgetBytes: UInt64
    let minimumAvailableMemoryBytes: UInt64
    let minimumAvailableMemoryReserveBytes: UInt64
    let maxSplatCount: Int
    let physicalMemoryBytes: UInt64
    let initialThermalState: String
    let finalThermalState: String
    let outcome: String

    // v3 diagnostics. Optional keeps v2 report migration lossless.
    let runID: String?
    let sessionID: String?
    let phase: SplatReconstructionPhase?
    let stopReason: SplatReconstructionStopReason?
    let activeGaussianCount: Int?
    let gaussianCapacityCount: Int?
    let sourceFrameCount: Int?
    let sourceImageWidth: Int?
    let sourceImageHeight: Int?
    let effectiveDownscale: Double?
    let currentResidentMemoryBytes: UInt64?
    let currentAvailableMemoryBytes: UInt64?
    let worstThermalState: String?
    let checkpointPath: String?
    let checkpointIteration: Int?
    let resumeOutcome: SplatCheckpointResumeOutcome?
    let errorMessage: String?

    static func write(_ report: SplatReconstructionRunReport, projectURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report) else { return }

        // Preserve the legacy latest-report location for existing readers.
        let latestFilename = String(format: "reconstruction-run-%05d.json", report.targetIteration)
        try? data.write(to: projectURL.appendingPathComponent(latestFilename), options: .atomic)

        // Keep a per-run artifact as well so a retry never destroys the evidence from the run that
        // triggered it. The run ID is generated locally and contains only filesystem-safe UUID text.
        if let runID = report.runID, !runID.isEmpty {
            let uniqueFilename = "reconstruction-run-\(String(format: "%05d", report.targetIteration))-\(runID).json"
            try? data.write(to: projectURL.appendingPathComponent(uniqueFilename), options: .atomic)
        }
    }
}

final class SplatResourceGuard: @unchecked Sendable {
    let limits: SplatResourceLimits
    let physicalMemoryBytes: UInt64

    private let lock = NSLock()
    private var receivedMemoryWarning = false
    private var peakResidentMemoryBytes: UInt64 = 0
    private var minimumAvailableMemoryBytes: UInt64 = .max
    private var peakSplatCount = 0
    private var lastResidentMemoryBytes: UInt64 = 0
    private var lastAvailableMemoryBytes: UInt64 = 0
    private var worstThermalStateName = "nominal"
    private var worstThermalStateRank = 0

    init(physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.limits = .conservative(physicalMemoryBytes: physicalMemoryBytes)
    }

    func resetForPass() {
        lock.lock()
        receivedMemoryWarning = false
        peakResidentMemoryBytes = 0
        minimumAvailableMemoryBytes = .max
        peakSplatCount = 0
        lastResidentMemoryBytes = 0
        lastAvailableMemoryBytes = 0
        worstThermalStateName = "nominal"
        worstThermalStateRank = 0
        lock.unlock()
    }

    func noteMemoryWarning() {
        lock.lock()
        receivedMemoryWarning = true
        lock.unlock()
    }

    func evaluate(
        splatCount: Int,
        residentMemoryBytes overrideResidentMemoryBytes: UInt64? = nil,
        availableMemoryBytes overrideAvailableMemoryBytes: UInt64? = nil,
        thermalState overrideThermalState: ProcessInfo.ThermalState? = nil
    ) -> SplatResourceEvaluation {
        let syntheticSnapshot = overrideResidentMemoryBytes != nil || overrideAvailableMemoryBytes != nil
        let resident = overrideResidentMemoryBytes ?? Self.currentResidentMemoryBytes()
        let available = overrideAvailableMemoryBytes
            ?? (syntheticSnapshot ? 0 : Self.currentAvailableMemoryBytes())
        let thermalState = overrideThermalState
            ?? (syntheticSnapshot ? .nominal : ProcessInfo.processInfo.thermalState)
        let thermalName = splatThermalStateName(thermalState)
        let thermalRank = Self.thermalRank(thermalState)

        lock.lock()
        peakResidentMemoryBytes = max(peakResidentMemoryBytes, resident)
        lastResidentMemoryBytes = resident
        lastAvailableMemoryBytes = available
        if available > 0 {
            minimumAvailableMemoryBytes = min(minimumAvailableMemoryBytes, available)
        }
        if thermalRank > worstThermalStateRank {
            worstThermalStateRank = thermalRank
            worstThermalStateName = thermalName
        }
        peakSplatCount = max(peakSplatCount, splatCount)
        let warning = receivedMemoryWarning
        let peakMemory = peakResidentMemoryBytes
        let minimumAvailable = minimumAvailableMemoryBytes == .max ? 0 : minimumAvailableMemoryBytes
        let peakSplats = peakSplatCount
        lock.unlock()

        let reason: SplatResourcePauseReason?
        if warning {
            reason = .memoryWarning
        } else if SplatReconstructionPolicy.requiresThermalPause(thermalState) {
            reason = .thermalPressure
        } else if available > 0 && available <= limits.minimumAvailableMemoryReserveBytes {
            reason = .availableMemoryReserve
        } else if resident > 0 && resident >= limits.residentMemoryBudgetBytes {
            reason = .residentMemoryBudget
        } else if splatCount >= limits.maxSplatCount {
            reason = .splatBudget
        } else {
            reason = nil
        }
        return SplatResourceEvaluation(
            reason: reason,
            residentMemoryBytes: resident,
            availableMemoryBytes: available,
            peakResidentMemoryBytes: peakMemory,
            minimumAvailableMemoryBytes: minimumAvailable,
            peakSplatCount: peakSplats
        )
    }

    func makeReport(
        startedAt: Date,
        startUptime: TimeInterval,
        passStartIteration: Int,
        targetIteration: Int,
        finalIteration: Int,
        finalSplatCount: Int,
        initialThermalState: String,
        finalThermalState: String,
        outcome: String,
        context: SplatReconstructionRunContext? = nil,
        phase: SplatReconstructionPhase = .unavailable,
        stopReason: SplatReconstructionStopReason? = nil,
        checkpointIteration: Int? = nil,
        resumeOutcome: SplatCheckpointResumeOutcome? = nil,
        errorMessage: String? = nil,
        gaussianCapacityCount: Int? = nil
    ) -> SplatReconstructionRunReport {
        let peaks = snapshotPeaks(finalSplatCount: finalSplatCount)
        let resolvedPhase = phase == .unavailable ? SplatReconstructionPhase.inferred(from: outcome) : phase
        let resolvedReason = stopReason ?? SplatReconstructionStopReason.inferred(from: outcome)
        let worstThermal = Self.worstThermalName(
            existing: peaks.worstThermalState,
            initial: initialThermalState,
            final: finalThermalState
        )
        return SplatReconstructionRunReport(
            schemaVersion: 3,
            startedAt: startedAt,
            finishedAt: Date(),
            elapsedSeconds: max(0, ProcessInfo.processInfo.systemUptime - startUptime),
            passStartIteration: passStartIteration,
            targetIteration: targetIteration,
            finalIteration: finalIteration,
            finalSplatCount: finalSplatCount,
            peakSplatCount: peaks.splats,
            peakResidentMemoryBytes: peaks.memory,
            residentMemoryBudgetBytes: limits.residentMemoryBudgetBytes,
            minimumAvailableMemoryBytes: peaks.minimumAvailable,
            minimumAvailableMemoryReserveBytes: limits.minimumAvailableMemoryReserveBytes,
            maxSplatCount: limits.maxSplatCount,
            physicalMemoryBytes: physicalMemoryBytes,
            initialThermalState: initialThermalState,
            finalThermalState: finalThermalState,
            outcome: outcome,
            runID: context?.runID.uuidString,
            sessionID: context?.sessionID,
            phase: resolvedPhase,
            stopReason: resolvedReason,
            activeGaussianCount: finalSplatCount,
            gaussianCapacityCount: gaussianCapacityCount,
            sourceFrameCount: context?.sourceFrameCount,
            sourceImageWidth: context?.sourceImageWidth,
            sourceImageHeight: context?.sourceImageHeight,
            effectiveDownscale: context?.effectiveDownscale,
            currentResidentMemoryBytes: peaks.currentResident > 0 ? peaks.currentResident : nil,
            currentAvailableMemoryBytes: peaks.currentAvailable > 0 ? peaks.currentAvailable : nil,
            worstThermalState: worstThermal,
            checkpointPath: context?.checkpointPath,
            checkpointIteration: checkpointIteration,
            resumeOutcome: resumeOutcome,
            errorMessage: errorMessage
        )
    }

    private func snapshotPeaks(finalSplatCount: Int) -> (
        memory: UInt64,
        minimumAvailable: UInt64,
        splats: Int,
        currentResident: UInt64,
        currentAvailable: UInt64,
        worstThermalState: String
    ) {
        lock.lock()
        peakSplatCount = max(peakSplatCount, finalSplatCount)
        let minimumAvailable = minimumAvailableMemoryBytes == .max ? 0 : minimumAvailableMemoryBytes
        let snapshot = (
            peakResidentMemoryBytes,
            minimumAvailable,
            peakSplatCount,
            lastResidentMemoryBytes,
            lastAvailableMemoryBytes,
            worstThermalStateName
        )
        lock.unlock()
        return snapshot
    }

    private static func thermalRank(_ state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 4
        }
    }

    private static func thermalRank(name: String) -> Int {
        switch name {
        case "nominal": return 0
        case "fair": return 1
        case "serious": return 2
        case "critical": return 3
        default: return 4
        }
    }

    private static func worstThermalName(existing: String, initial: String, final: String) -> String {
        [existing, initial, final].max { lhs, rhs in
            thermalRank(name: lhs) < thermalRank(name: rhs)
        } ?? "unknown"
    }

    static func currentResidentMemoryBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
    }

    static func currentAvailableMemoryBytes() -> UInt64 {
        UInt64(os_proc_available_memory())
    }
}

func splatThermalStateName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
}
