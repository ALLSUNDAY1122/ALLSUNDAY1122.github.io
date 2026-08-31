import Foundation

public protocol LapTiming: AnyObject {
    @discardableResult func beginLap(courseID: String, atTick tick: UInt64) -> Bool
    @discardableResult func finishLap(courseID: String, atTick tick: UInt64) -> LapEvent?
    func cancelLap(courseID: String)
    func cancelAllLaps()
}

/// Deterministic lap timer keyed to the same fixed simulation tick used by player/replay.
/// Session C passes `FixedStepClock.tick` values into begin/finish; no wall clock is consulted.
public final class FixedTickLapTimer: LapTiming, @unchecked Sendable {
    public let ticksPerSecond: Double
    public weak var signalSink: CoreGameplaySignalSink?

    private var startedAtTick: [String: UInt64] = [:]

    public init(ticksPerSecond: Double = 120.0, signalSink: CoreGameplaySignalSink? = nil) {
        precondition(ticksPerSecond > 0 && ticksPerSecond.isFinite)
        self.ticksPerSecond = ticksPerSecond
        self.signalSink = signalSink
    }

    public func isLapActive(courseID: String) -> Bool { startedAtTick[courseID] != nil }

    @discardableResult
    public func beginLap(courseID: String, atTick tick: UInt64) -> Bool {
        guard startedAtTick[courseID] == nil else { return false }
        startedAtTick[courseID] = tick
        return true
    }

    @discardableResult
    public func finishLap(courseID: String, atTick tick: UInt64) -> LapEvent? {
        guard let start = startedAtTick[courseID], tick >= start else { return nil }
        startedAtTick.removeValue(forKey: courseID)
        let event = LapEvent(courseID: courseID, elapsed: Double(tick - start) / ticksPerSecond)
        signalSink?.emit(.lapCompleted(event))
        return event
    }

    public func cancelLap(courseID: String) { startedAtTick.removeValue(forKey: courseID) }
    public func cancelAllLaps() { startedAtTick.removeAll(keepingCapacity: true) }
}
