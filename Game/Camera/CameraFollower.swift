import Foundation

public struct CameraConfig: Equatable, Sendable {
    public var horizontalDeadZone: Double = 0.90
    public var verticalDeadZone: Double = 0.65
    public var horizontalLookAhead: Double = 1.15
    public var verticalBias: Double = 0.30
    public var followHalfLife: Double = 0.085
    public var lookAheadHalfLife: Double = 0.055
    public var teleportSnapDistance: Double = 8.0

    public init() {}
}

public struct CameraSnapshot: Equatable, Sendable {
    public var position: Vector2
    public var lookAhead: Double

    public init(position: Vector2, lookAhead: Double) {
        self.position = position
        self.lookAhead = lookAhead
    }
}

/// Engine/UI-independent camera target solver. Rendering code may interpolate its snapshots.
public final class CameraFollower: @unchecked Sendable {
    public private(set) var position: Vector2
    public private(set) var lookAhead: Double = 0
    public let config: CameraConfig

    public init(initialTarget: Vector2, config: CameraConfig = CameraConfig()) {
        self.position = Vector2(x: initialTarget.x, y: initialTarget.y + config.verticalBias)
        self.config = config
    }

    public func snap(to target: Vector2, facing: Int = 1) {
        position = Vector2(x: target.x, y: target.y + config.verticalBias)
        lookAhead = Double(facing >= 0 ? 1 : -1) * config.horizontalLookAhead
    }

    public func step(dt: Double, target: Vector2, velocity: Vector2, facing: Int) {
        guard dt > 0 else { return }
        let desiredLook = Double(facing >= 0 ? 1 : -1) * config.horizontalLookAhead
        lookAhead = expSmooth(current: lookAhead, target: desiredLook, halfLife: config.lookAheadHalfLife, dt: dt)

        let desired = Vector2(x: target.x + lookAhead, y: target.y + config.verticalBias)
        let dx = desired.x - position.x
        let dy = desired.y - position.y
        if hypot(dx, dy) >= config.teleportSnapDistance {
            position = desired
            return
        }

        var constrained = position
        if abs(dx) > config.horizontalDeadZone {
            constrained.x = desired.x - copysign(config.horizontalDeadZone, dx)
        }
        if abs(dy) > config.verticalDeadZone {
            constrained.y = desired.y - copysign(config.verticalDeadZone, dy)
        }

        // During fast movement, slightly reduce perceived lag without making the camera jitter at rest.
        let speedBoost = min(1.8, 1.0 + hypot(velocity.x, velocity.y) / 30.0)
        let effectiveHalfLife = config.followHalfLife / speedBoost
        position.x = expSmooth(current: position.x, target: constrained.x, halfLife: effectiveHalfLife, dt: dt)
        position.y = expSmooth(current: position.y, target: constrained.y, halfLife: effectiveHalfLife, dt: dt)
    }

    public func snapshot() -> CameraSnapshot { CameraSnapshot(position: position, lookAhead: lookAhead) }

    private func expSmooth(current: Double, target: Double, halfLife: Double, dt: Double) -> Double {
        guard halfLife > 0 else { return target }
        let decay = exp(-log(2.0) * dt / halfLife)
        return target + (current - target) * decay
    }
}
