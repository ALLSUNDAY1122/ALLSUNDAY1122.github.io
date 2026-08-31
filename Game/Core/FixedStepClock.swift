import Foundation

public struct FixedStepFrame: Equatable, Sendable {
    public var steps: Int
    public var interpolationAlpha: Double
    public var droppedTime: Double
    public var tick: UInt64

    public init(steps: Int, interpolationAlpha: Double, droppedTime: Double, tick: UInt64) {
        self.steps = steps
        self.interpolationAlpha = interpolationAlpha
        self.droppedTime = droppedTime
        self.tick = tick
    }
}

/// Converts variable render-frame deltas into deterministic fixed simulation ticks.
/// Session C should feed display-link deltas here rather than calling gameplay with 60/120 Hz deltas directly.
public struct FixedStepClock: Sendable {
    public let fixedDelta: Double
    public let maxFrameDelta: Double
    public let maxStepsPerFrame: Int

    public private(set) var accumulator: Double = 0
    public private(set) var tick: UInt64 = 0
    public private(set) var totalDroppedTime: Double = 0

    public init(fixedDelta: Double = 1.0 / 120.0, maxFrameDelta: Double = 0.10, maxStepsPerFrame: Int = 12) {
        precondition(fixedDelta > 0)
        precondition(maxFrameDelta >= fixedDelta)
        precondition(maxStepsPerFrame > 0)
        self.fixedDelta = fixedDelta
        self.maxFrameDelta = maxFrameDelta
        self.maxStepsPerFrame = maxStepsPerFrame
    }

    @discardableResult
    public mutating func advance(frameDelta rawDelta: Double, step: (Double, UInt64) -> Void) -> FixedStepFrame {
        guard rawDelta > 0 else {
            return FixedStepFrame(steps: 0, interpolationAlpha: accumulator / fixedDelta, droppedTime: 0, tick: tick)
        }

        let clamped = min(rawDelta, maxFrameDelta)
        var dropped = max(0, rawDelta - clamped)
        accumulator += clamped

        var steps = 0
        let epsilon = fixedDelta * 1e-9
        while accumulator + epsilon >= fixedDelta && steps < maxStepsPerFrame {
            step(fixedDelta, tick)
            tick &+= 1
            accumulator -= fixedDelta
            if accumulator < 0 && accumulator > -epsilon { accumulator = 0 }
            steps += 1
        }

        if steps == maxStepsPerFrame && accumulator + epsilon >= fixedDelta {
            let retain = accumulator.truncatingRemainder(dividingBy: fixedDelta)
            dropped += accumulator - retain
            accumulator = retain
        }
        totalDroppedTime += dropped

        return FixedStepFrame(
            steps: steps,
            interpolationAlpha: max(0, min(1, accumulator / fixedDelta)),
            droppedTime: dropped,
            tick: tick
        )
    }

    public mutating func reset(tick: UInt64 = 0) {
        accumulator = 0
        self.tick = tick
        totalDroppedTime = 0
    }
}
