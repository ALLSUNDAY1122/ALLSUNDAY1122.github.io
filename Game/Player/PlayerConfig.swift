import Foundation

public struct PlayerConfig: Equatable, Sendable {
    public var halfSize = Vector2(x: 0.35, y: 0.45)
    public var maxRunSpeed: Double = 7.0
    public var groundAcceleration: Double = 60.0
    public var groundDeceleration: Double = 70.0
    public var airAcceleration: Double = 34.0
    public var airDeceleration: Double = 18.0
    public var airOverspeedDeceleration: Double = 7.0
    public var jumpSpeed: Double = 12.0
    public var airJumpSpeed: Double = 11.5
    public var gravity: Double = 34.0
    public var maxFallSpeed: Double = 22.0
    public var jumpCutMultiplier: Double = 0.45
    public var coyoteTime: Double = 0.10
    public var jumpBufferTime: Double = 0.11
    public var wallGraceTime: Double = 0.10
    public var wallJumpHorizontalSpeed: Double = 9.0
    public var wallJumpVerticalSpeed: Double = 11.5
    public var wallJumpControlLockTime: Double = 0.09
    public var maxAirJumps: Int = 1
    public var dashSpeed: Double = 15.5
    public var dashDuration: Double = 0.13
    public var dashBufferTime: Double = 0.10
    public var dashExitSpeedRetain: Double = 0.82
    public var respawnDelay: Double = 0.20

    public init() {}
}
