import Foundation

public struct TrackedPoint: Sendable, Equatable {
    public let time: TimeInterval
    /// Normalized image coordinate, 0...1 from left to right.
    public let x: Double
    /// Normalized image coordinate, 0...1 from top to bottom.
    public let y: Double

    public init(time: TimeInterval, x: Double, y: Double) {
        self.time = time
        self.x = x
        self.y = y
    }
}

public struct RimRegion: Sendable, Equatable {
    public let centerX: Double
    public let centerY: Double
    public let halfWidth: Double
    public let halfHeight: Double

    public func contains(_ point: TrackedPoint) -> Bool {
        abs(point.x - centerX) <= halfWidth && abs(point.y - centerY) <= halfHeight
    }
}

public struct ShotEvent: Sendable, Equatable {
    public let apexTime: TimeInterval
    public let crossingTime: TimeInterval
    public let confidence: Double
}

public struct ShotEventDetector: Sendable {
    public var minimumRise: Double = 0.06
    public var minimumFall: Double = 0.05
    public var maximumDuration: TimeInterval = 2.5
    public var rimRegion: RimRegion

    public init(rimRegion: RimRegion) {
        self.rimRegion = rimRegion
    }

    /// Detects a basic shot arc from a tracked ball trajectory.
    /// Image y decreases while the ball rises and increases while it falls.
    /// This deliberately stays independent from Vision/Core ML so it can be reused
    /// with different object detectors.
    public func detect(in points: [TrackedPoint]) -> [ShotEvent] {
        guard points.count >= 5 else { return [] }
        let sorted = points.sorted { $0.time < $1.time }
        var events: [ShotEvent] = []

        for apexIndex in 2..<(sorted.count - 2) {
            let apex = sorted[apexIndex]
            let before = sorted[apexIndex - 2]
            let after = sorted[apexIndex + 2]

            let rise = before.y - apex.y
            let fall = after.y - apex.y
            guard rise >= minimumRise, fall >= minimumFall else { continue }
            guard after.time - before.time <= maximumDuration else { continue }

            let postApex = sorted[(apexIndex + 1)...]
            guard let crossing = postApex.first(where: rimRegion.contains) else { continue }

            let horizontalError = abs(crossing.x - rimRegion.centerX) / max(rimRegion.halfWidth, 0.0001)
            let verticalError = abs(crossing.y - rimRegion.centerY) / max(rimRegion.halfHeight, 0.0001)
            let geometryScore = max(0, 1.0 - 0.5 * (horizontalError + verticalError))
            let arcScore = min(1.0, (rise + fall) / max(minimumRise + minimumFall, 0.0001))
            let confidence = min(1.0, 0.55 * geometryScore + 0.45 * arcScore)

            if events.last.map({ crossing.time - $0.crossingTime > 0.35 }) ?? true {
                events.append(
                    ShotEvent(
                        apexTime: apex.time,
                        crossingTime: crossing.time,
                        confidence: confidence
                    )
                )
            }
        }

        return events
    }
}
