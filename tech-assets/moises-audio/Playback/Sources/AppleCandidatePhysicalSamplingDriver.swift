#if os(iOS) && canImport(UIKit) && canImport(CryptoKit)
import Foundation
import UIKit

public enum Lane3AppleCandidatePhysicalSamplingDriverError: Error, Equatable, Sendable {
    case applicationNotActive
    case alreadyStarted
    case notRunning
    case terminalState(Lane3CandidatePhysicalSamplingLifecycleState)
}

public struct Lane3AppleCandidatePhysicalSamplingHandoff: Sendable {
    public let sessionIdentifier: String
    public let receipt: Lane3PhysicalEvidenceResourceTraceReceipt
    public let canonicalArtifactData: Data
    public let lifecycle: Lane3CandidatePhysicalSamplingLifecycle
    public let parityPromotionAllowed: Bool

    public init(
        sessionIdentifier: String,
        receipt: Lane3PhysicalEvidenceResourceTraceReceipt,
        canonicalArtifactData: Data,
        lifecycle: Lane3CandidatePhysicalSamplingLifecycle
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.receipt = receipt
        self.canonicalArtifactData = canonicalArtifactData
        self.lifecycle = lifecycle
        self.parityPromotionAllowed = false
    }
}

@MainActor
private final class Lane3AppleCandidatePhysicalSamplingTimerTarget: NSObject {
    weak var owner: Lane3AppleCandidatePhysicalSamplingDriver?

    @objc func timerDidFire(_ timer: Timer) {
        guard let owner else {
            timer.invalidate()
            return
        }
        owner.handleScheduledSample()
    }
}

/// AW53 selected-iOS lifecycle driver for AW52 candidate resource measurement.
///
/// Contract:
/// - requires the app to be active at start;
/// - samples immediately, then schedules 15-second ticks on the main common run-loop mode;
/// - aborts on app resignation/background/termination, sample failure, or >30-second observed gap;
/// - every driver-controlled abort calls the AW52 recorder's `cancel()` and therefore restores the
///   previous UIDevice battery-monitoring state;
/// - a successful `finish()` returns one digest-bound AW51 candidate receipt + canonical artifact;
/// - no physical evidence or PARITY is implied until this code is run on the selected iPhone.
@MainActor
public final class Lane3AppleCandidatePhysicalSamplingDriver: NSObject {
    public static let samplingIntervalSeconds =
        Lane3CandidatePhysicalSamplingLifecycle.recommendedCadenceSeconds

    private let sessionIdentifier: String
    private let application: UIApplication
    private let notificationCenter: NotificationCenter
    private let timerTarget = Lane3AppleCandidatePhysicalSamplingTimerTarget()

    private var timer: Timer?
    private var recorder: Lane3AppleCandidatePhysicalResourceRecorder?
    private var lifecycleStorage = Lane3CandidatePhysicalSamplingLifecycle()
    private var lastSamplingErrorDescription: String?

    public init(
        sessionIdentifier: String,
        application: UIApplication = .shared,
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.sessionIdentifier = try Lane3CandidatePhysicalResourceTraceAccumulator
            .validatedSessionIdentifier(sessionIdentifier)
        self.application = application
        self.notificationCenter = notificationCenter
        super.init()
        timerTarget.owner = self
    }

    public var lifecycle: Lane3CandidatePhysicalSamplingLifecycle { lifecycleStorage }
    public var sampleCount: Int { recorder?.sampleCount ?? lifecycleStorage.acceptedSamples }
    public var lastSamplingFailure: String? { lastSamplingErrorDescription }

    public func start() throws {
        switch lifecycleStorage.state {
        case .prepared:
            break
        case .running:
            throw Lane3AppleCandidatePhysicalSamplingDriverError.alreadyStarted
        case .completed, .aborted:
            throw Lane3AppleCandidatePhysicalSamplingDriverError.terminalState(lifecycleStorage.state)
        }
        guard application.applicationState == .active else {
            throw Lane3AppleCandidatePhysicalSamplingDriverError.applicationNotActive
        }

        let createdRecorder = try Lane3AppleCandidatePhysicalResourceRecorder(
            sessionIdentifier: sessionIdentifier
        )
        do {
            let first = try createdRecorder.sample()
            try lifecycleStorage.start(firstSampleUptimeSeconds: first.uptimeSeconds)
        } catch {
            createdRecorder.cancel()
            lifecycleStorage.abort(.samplingFailed)
            lastSamplingErrorDescription = String(describing: error)
            throw error
        }
        recorder = createdRecorder
        installLifecycleObservers()
        installSamplingTimer()
    }

    /// Attempts finalization. If AW52 is not complete yet (for example, <1800 seconds), the
    /// recorder remains running and the caller may continue the same physical session.
    public func finish() throws -> Lane3AppleCandidatePhysicalSamplingHandoff {
        guard lifecycleStorage.state == .running, let recorder else {
            if lifecycleStorage.state == .prepared {
                throw Lane3AppleCandidatePhysicalSamplingDriverError.notRunning
            }
            throw Lane3AppleCandidatePhysicalSamplingDriverError.terminalState(lifecycleStorage.state)
        }
        let result = try recorder.finish()
        try lifecycleStorage.complete()
        cleanupSchedulingAndObservers()
        self.recorder = nil
        return Lane3AppleCandidatePhysicalSamplingHandoff(
            sessionIdentifier: sessionIdentifier,
            receipt: result.receipt,
            canonicalArtifactData: result.canonicalArtifactData,
            lifecycle: lifecycleStorage
        )
    }

    public func cancel() {
        abort(.hostCancelled)
    }

    /// Scope helper for physical hosts. Every throwing/early-return path cancels an unfinished
    /// session before leaving the scope; a successfully finished driver is already terminal.
    public static func withDriver<T>(
        sessionIdentifier: String,
        operation: @MainActor (Lane3AppleCandidatePhysicalSamplingDriver) async throws -> T
    ) async throws -> T {
        let driver = try Lane3AppleCandidatePhysicalSamplingDriver(sessionIdentifier: sessionIdentifier)
        try driver.start()
        defer {
            if !driver.lifecycle.isTerminal {
                driver.cancel()
            }
        }
        return try await operation(driver)
    }

    fileprivate func handleScheduledSample() {
        guard lifecycleStorage.state == .running, let recorder else { return }
        guard application.applicationState == .active else {
            abort(.applicationWillResignActive)
            return
        }
        do {
            let sample = try recorder.sample()
            do {
                try lifecycleStorage.acceptSample(uptimeSeconds: sample.uptimeSeconds)
            } catch Lane3CandidatePhysicalSamplingLifecycleError.cadenceGapExceeded {
                abort(.cadenceGapExceeded)
            } catch {
                lastSamplingErrorDescription = String(describing: error)
                abort(.samplingFailed)
            }
        } catch {
            lastSamplingErrorDescription = String(describing: error)
            abort(.samplingFailed)
        }
    }

    private func installSamplingTimer() {
        let timer = Timer(
            timeInterval: Self.samplingIntervalSeconds,
            target: timerTarget,
            selector: #selector(Lane3AppleCandidatePhysicalSamplingTimerTarget.timerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = min(1, Self.samplingIntervalSeconds * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func installLifecycleObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: application
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground(_:)),
            name: UIApplication.didEnterBackgroundNotification,
            object: application
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillTerminate(_:)),
            name: UIApplication.willTerminateNotification,
            object: application
        )
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        abort(.applicationWillResignActive)
    }

    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        abort(.applicationDidEnterBackground)
    }

    @objc private func applicationWillTerminate(_ notification: Notification) {
        abort(.applicationWillTerminate)
    }

    private func abort(_ reason: Lane3CandidatePhysicalSamplingAbortReason) {
        guard lifecycleStorage.state == .prepared || lifecycleStorage.state == .running else { return }
        cleanupSchedulingAndObservers()
        recorder?.cancel()
        recorder = nil
        lifecycleStorage.abort(reason)
    }

    private func cleanupSchedulingAndObservers() {
        timer?.invalidate()
        timer = nil
        notificationCenter.removeObserver(self)
    }
}
#endif
