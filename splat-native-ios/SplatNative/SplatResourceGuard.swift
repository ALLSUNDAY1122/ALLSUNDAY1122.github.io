import Foundation
import Darwin.Mach

struct SplatResourceLimits: Codable, Equatable, Sendable {
    let residentMemoryBudgetBytes: UInt64
    let maxSplatCount: Int

    static func conservative(physicalMemoryBytes: UInt64) -> SplatResourceLimits {
        let mib: UInt64 = 1_048_576
        let minimumBudget = 700 * mib
        let maximumBudget = 1_536 * mib
        let proportional = physicalMemoryBytes / 100 * 28
        let memoryBudget = min(maximumBudget, max(minimumBudget, proportional))

        // A degree-3 Gaussian carries parameters, gradients and optimizer state. Use 2 KiB/splat
        // as a deliberately conservative training-time envelope and reserve roughly half of the
        // process budget for images, render buffers and framework overhead.
        let estimatedTrainingBytesPerSplat: UInt64 = 2_048
        let rawCount = Int(memoryBudget / estimatedTrainingBytesPerSplat / 2)
        let splatBudget = min(900_000, max(300_000, rawCount))
        return SplatResourceLimits(
            residentMemoryBudgetBytes: memoryBudget,
            maxSplatCount: splatBudget
        )
    }
}

enum SplatResourcePauseReason: String, Codable, Sendable {
    case memoryWarning
    case residentMemoryBudget
    case splatBudget

    var userMessage: String {
        switch self {
        case .memoryWarning, .residentMemoryBudget:
            return "端末のメモリ使用量が高くなったため生成を安全に一時停止しました。ほかのアプリを閉じてから「生成だけもう一度試す」で続きから再開できます"
        case .splatBudget:
            return "3Dデータが端末の安全上限まで細かくなったため生成を一時停止しました。現在の結果を利用するか、より新しい端末で追加生成してください"
        }
    }
}

struct SplatResourceEvaluation: Equatable, Sendable {
    let reason: SplatResourcePauseReason?
    let residentMemoryBytes: UInt64
    let peakResidentMemoryBytes: UInt64
    let peakSplatCount: Int
}

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
    let maxSplatCount: Int
    let physicalMemoryBytes: UInt64
    let initialThermalState: String
    let finalThermalState: String
    let outcome: String

    static func write(_ report: SplatReconstructionRunReport, projectURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(report) else { return }
        let filename = String(format: "reconstruction-run-%05d.json", report.targetIteration)
        try? data.write(to: projectURL.appendingPathComponent(filename), options: .atomic)
    }
}

final class SplatResourceGuard: @unchecked Sendable {
    let limits: SplatResourceLimits
    let physicalMemoryBytes: UInt64

    private let lock = NSLock()
    private var receivedMemoryWarning = false
    private var peakResidentMemoryBytes: UInt64 = 0
    private var peakSplatCount = 0

    init(physicalMemoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.physicalMemoryBytes = physicalMemoryBytes
        self.limits = .conservative(physicalMemoryBytes: physicalMemoryBytes)
    }

    func resetForPass() {
        lock.lock()
        receivedMemoryWarning = false
        peakResidentMemoryBytes = 0
        peakSplatCount = 0
        lock.unlock()
    }

    func noteMemoryWarning() {
        lock.lock()
        receivedMemoryWarning = true
        lock.unlock()
    }

    func evaluate(
        splatCount: Int,
        residentMemoryBytes overrideResidentMemoryBytes: UInt64? = nil
    ) -> SplatResourceEvaluation {
        let resident = overrideResidentMemoryBytes ?? Self.currentResidentMemoryBytes()
        lock.lock()
        peakResidentMemoryBytes = max(peakResidentMemoryBytes, resident)
        peakSplatCount = max(peakSplatCount, splatCount)
        let warning = receivedMemoryWarning
        let peakMemory = peakResidentMemoryBytes
        let peakSplats = peakSplatCount
        lock.unlock()

        let reason: SplatResourcePauseReason?
        if warning {
            reason = .memoryWarning
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
            peakResidentMemoryBytes: peakMemory,
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
        outcome: String
    ) -> SplatReconstructionRunReport {
        let peaks = snapshotPeaks(finalSplatCount: finalSplatCount)
        return SplatReconstructionRunReport(
            schemaVersion: 1,
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
            maxSplatCount: limits.maxSplatCount,
            physicalMemoryBytes: physicalMemoryBytes,
            initialThermalState: initialThermalState,
            finalThermalState: finalThermalState,
            outcome: outcome
        )
    }

    private func snapshotPeaks(finalSplatCount: Int) -> (memory: UInt64, splats: Int) {
        lock.lock()
        peakSplatCount = max(peakSplatCount, finalSplatCount)
        let snapshot = (peakResidentMemoryBytes, peakSplatCount)
        lock.unlock()
        return snapshot
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
