import Foundation

public final class PlayerController: PlayerControlling, CheckpointAccepting, @unchecked Sendable {
    public private(set) var position: Vector2
    public private(set) var velocity: Vector2 = .zero
    public private(set) var contacts = CollisionContacts()
    public private(set) var isAlive = true
    public private(set) var facing = 1
    public private(set) var locomotionState: PlayerLocomotionState = .airborne
    public private(set) var airJumpsRemaining = 0
    public private(set) var airDashAvailable = false

    public let config: PlayerConfig
    public var world: any CollisionWorld
    public weak var signalSink: CoreGameplaySignalSink?

    private var moveAxis: Double = 0
    private var jumpPressed = false
    private var jumpBufferRemaining: Double = 0
    private var forcedWallJumpBufferRemaining: Double = 0
    private var dashBufferRemaining: Double = 0
    private var coyoteRemaining: Double = 0
    private var wallGraceRemaining: Double = 0
    private var lastWallSide = 0 // -1 left, +1 right
    private var dashRemaining: Double = 0
    private var groundDashJumpRemaining: Double = 0
    private var dashDirection = 1
    private var horizontalControlLockRemaining: Double = 0
    private var respawnRemaining: Double = 0
    private let initialSpawn: SpawnPoint
    private var activeCheckpoint: CheckpointDescriptor?
    private var abilities: Set<PlayerAbility> = [.jump, .variableJump]

    public init(
        spawn: SpawnPoint,
        world: any CollisionWorld,
        config: PlayerConfig = PlayerConfig(),
        signalSink: CoreGameplaySignalSink? = nil
    ) {
        self.initialSpawn = spawn
        self.position = spawn.position
        self.facing = spawn.facing
        self.world = world
        self.config = config
        self.signalSink = signalSink
    }

    public func setMoveAxis(_ axis: Float) {
        moveAxis = max(-1, min(1, Double(axis)))
        if abs(moveAxis) > 0.001 { facing = moveAxis >= 0 ? 1 : -1 }
    }

    public func setJumpPressed(_ pressed: Bool) {
        if jumpPressed && !pressed && abilities.contains(.variableJump) && velocity.y > 0 && dashRemaining <= 0 {
            velocity.y *= config.jumpCutMultiplier
        }
        if !jumpPressed && pressed { requestJump() }
        jumpPressed = pressed
    }

    public func requestJump() {
        guard abilities.contains(.jump), isAlive else { return }
        jumpBufferRemaining = config.jumpBufferTime
    }

    public func requestDash() {
        guard abilities.contains(.dash), isAlive else { return }
        dashBufferRemaining = config.dashBufferTime
    }

    public func requestWallJump() {
        guard abilities.contains(.jump), abilities.contains(.wallJump), isAlive else { return }
        forcedWallJumpBufferRemaining = config.jumpBufferTime
    }

    public func setAbility(_ ability: PlayerAbility, enabled: Bool) {
        if enabled {
            let inserted = abilities.insert(ability).inserted
            if inserted {
                if ability == .airJump && contacts.floor { airJumpsRemaining = config.maxAirJumps }
                if ability == .dash && contacts.floor { airDashAvailable = true }
            }
        } else {
            abilities.remove(ability)
            switch ability {
            case .jump:
                jumpBufferRemaining = 0
                forcedWallJumpBufferRemaining = 0
            case .variableJump:
                break
            case .airJump:
                airJumpsRemaining = 0
            case .dash:
                dashBufferRemaining = 0
                dashRemaining = 0
                groundDashJumpRemaining = 0
                airDashAvailable = false
                if locomotionState == .dashing { locomotionState = contacts.floor ? .grounded : .airborne }
            case .wallJump:
                forcedWallJumpBufferRemaining = 0
                wallGraceRemaining = 0
                lastWallSide = 0
                horizontalControlLockRemaining = 0
            }
        }
    }

    public func hasAbility(_ ability: PlayerAbility) -> Bool { abilities.contains(ability) }

    /// Executes exactly one simulation tick. Session C should supply dt from FixedStepClock (120 Hz default).
    public func step(dt: Double) {
        guard dt > 0 else { return }
        guard isAlive else {
            respawnRemaining -= dt
            if respawnRemaining <= 0 { respawn(at: nil) }
            return
        }

        decayTimers(dt: dt)
        refreshContactResources()
        if locomotionState == .wallJumping && horizontalControlLockRemaining <= 0 { locomotionState = .airborne }

        // Deterministic action priority: wall jump > combined ground dash+jump > normal/air jump > dash.
        if resolveJumpIfPossible() {
            dashBufferRemaining = 0
        } else {
            resolveDashIfPossible()
        }

        let dashWasActive = dashRemaining > 0
        let dashEndsThisStep = dashRemaining > 0 && dashRemaining <= dt
        if dashRemaining > 0 {
            locomotionState = .dashing
            velocity.x = Double(dashDirection) * config.dashSpeed
            velocity.y = 0
            dashRemaining = max(0, dashRemaining - dt)
        } else {
            applyHorizontalControl(dt: dt)
            velocity.y = max(velocity.y - config.gravity * dt, -config.maxFallSpeed)
        }

        let solved = AxisSeparatedCollisionSolver.move(
            position: position,
            velocity: velocity,
            halfSize: config.halfSize,
            dt: dt,
            world: world
        )
        position = solved.position
        velocity = solved.velocity
        contacts = solved.contacts

        let hitDashWall = dashWasActive && ((dashDirection > 0 && contacts.wallRight) || (dashDirection < 0 && contacts.wallLeft))
        if hitDashWall {
            // Do not keep re-applying dash velocity into a wall for the rest of the timer.
            // Ending immediately makes dash -> wall-jump timing deterministic and responsive.
            dashRemaining = 0
            if !contacts.floor { groundDashJumpRemaining = 0 }
        } else if dashEndsThisStep {
            velocity.x *= config.dashExitSpeedRetain
        }

        if contacts.floor {
            airJumpsRemaining = abilities.contains(.airJump) ? config.maxAirJumps : 0
            airDashAvailable = abilities.contains(.dash)
            coyoteRemaining = config.coyoteTime
            if dashRemaining <= 0 && locomotionState != .wallJumping { locomotionState = .grounded }
        } else if dashRemaining <= 0 && locomotionState != .wallJumping {
            locomotionState = .airborne
        }

        updateWallGraceFromContacts()

        // Landing in the same fixed step should still consume a buffered jump immediately.
        if contacts.floor && jumpBufferRemaining > 0 && abilities.contains(.jump) {
            performGroundJump()
        }
    }

    private func decayTimers(dt: Double) {
        jumpBufferRemaining = max(0, jumpBufferRemaining - dt)
        forcedWallJumpBufferRemaining = max(0, forcedWallJumpBufferRemaining - dt)
        dashBufferRemaining = max(0, dashBufferRemaining - dt)
        groundDashJumpRemaining = max(0, groundDashJumpRemaining - dt)
        horizontalControlLockRemaining = max(0, horizontalControlLockRemaining - dt)
        if contacts.floor { coyoteRemaining = config.coyoteTime } else { coyoteRemaining = max(0, coyoteRemaining - dt) }
        if contacts.wallLeft || contacts.wallRight { wallGraceRemaining = config.wallGraceTime } else { wallGraceRemaining = max(0, wallGraceRemaining - dt) }
    }

    private func refreshContactResources() {
        if contacts.floor {
            airJumpsRemaining = abilities.contains(.airJump) ? config.maxAirJumps : 0
            airDashAvailable = abilities.contains(.dash)
        }
        updateWallGraceFromContacts()
    }

    private func updateWallGraceFromContacts() {
        if contacts.wallLeft {
            lastWallSide = -1
            wallGraceRemaining = config.wallGraceTime
        } else if contacts.wallRight {
            lastWallSide = 1
            wallGraceRemaining = config.wallGraceTime
        }
    }

    @discardableResult
    private func resolveJumpIfPossible() -> Bool {
        guard abilities.contains(.jump) else { return false }
        let wallAvailable = abilities.contains(.wallJump) && wallGraceRemaining > 0 && lastWallSide != 0 && !contacts.floor
        if forcedWallJumpBufferRemaining > 0 {
            guard wallAvailable else { return false }
            performWallJump(awayFrom: lastWallSide)
            return true
        }

        guard jumpBufferRemaining > 0 else { return false }
        if wallAvailable {
            performWallJump(awayFrom: lastWallSide)
            return true
        }

        let groundJumpAvailable = contacts.floor || coyoteRemaining > 0 || groundDashJumpRemaining > 0
        if groundJumpAvailable {
            if dashBufferRemaining > 0 && dashRemaining <= 0 && abilities.contains(.dash) {
                performGroundDashJump()
            } else {
                performGroundJump()
            }
            return true
        }

        if abilities.contains(.airJump), airJumpsRemaining > 0 {
            performAirJump()
            return true
        }
        return false
    }

    private func performGroundJump() {
        dashRemaining = 0
        groundDashJumpRemaining = 0
        velocity.y = config.jumpSpeed
        jumpBufferRemaining = 0
        forcedWallJumpBufferRemaining = 0
        coyoteRemaining = 0
        contacts.floor = false
        locomotionState = .airborne
    }

    private func performGroundDashJump() {
        dashDirection = abs(moveAxis) > 0.001 ? (moveAxis >= 0 ? 1 : -1) : facing
        facing = dashDirection
        velocity.x = Double(dashDirection) * config.dashSpeed
        dashBufferRemaining = 0
        performGroundJump()
    }

    private func performAirJump() {
        groundDashJumpRemaining = 0
        velocity.y = config.airJumpSpeed
        airJumpsRemaining -= 1
        jumpBufferRemaining = 0
        forcedWallJumpBufferRemaining = 0
        dashRemaining = 0
        locomotionState = .airborne
    }

    private func performWallJump(awayFrom wallSide: Int) {
        let away = wallSide == -1 ? 1 : -1
        velocity.x = Double(away) * config.wallJumpHorizontalSpeed
        velocity.y = config.wallJumpVerticalSpeed
        facing = away
        jumpBufferRemaining = 0
        forcedWallJumpBufferRemaining = 0
        dashRemaining = 0
        groundDashJumpRemaining = 0
        wallGraceRemaining = 0
        lastWallSide = 0
        horizontalControlLockRemaining = config.wallJumpControlLockTime
        contacts.wallLeft = false
        contacts.wallRight = false
        locomotionState = .wallJumping
    }

    private func resolveDashIfPossible() {
        guard dashBufferRemaining > 0, abilities.contains(.dash), dashRemaining <= 0 else { return }
        let grounded = contacts.floor || coyoteRemaining > 0
        guard grounded || airDashAvailable else { return }

        dashDirection = abs(moveAxis) > 0.001 ? (moveAxis >= 0 ? 1 : -1) : facing
        facing = dashDirection
        dashRemaining = config.dashDuration
        dashBufferRemaining = 0
        if grounded {
            groundDashJumpRemaining = config.dashDuration
            coyoteRemaining = max(coyoteRemaining, config.coyoteTime)
        } else {
            airDashAvailable = false
        }
        locomotionState = .dashing
    }

    private func applyHorizontalControl(dt: Double) {
        if horizontalControlLockRemaining > 0 { return }

        let targetX = moveAxis * config.maxRunSpeed
        if contacts.floor {
            let accelerating = abs(targetX) > abs(velocity.x) || (targetX * velocity.x < 0)
            let accel = accelerating ? config.groundAcceleration : config.groundDeceleration
            velocity.x = approach(velocity.x, targetX, by: accel * dt)
            return
        }

        if abs(velocity.x) > config.maxRunSpeed {
            let inputOpposes = abs(moveAxis) > 0.001 && moveAxis * velocity.x < 0
            let overspeedTarget = velocity.x > 0 ? config.maxRunSpeed : -config.maxRunSpeed
            let decel = inputOpposes ? config.airDeceleration : config.airOverspeedDeceleration
            velocity.x = approach(velocity.x, overspeedTarget, by: decel * dt)
        } else {
            let accelerating = abs(targetX) > abs(velocity.x) || (targetX * velocity.x < 0)
            let accel = accelerating ? config.airAcceleration : config.airDeceleration
            velocity.x = approach(velocity.x, targetX, by: accel * dt)
        }
    }

    public func kill(reason: DeathReason) {
        guard isAlive else { return }
        isAlive = false
        velocity = .zero
        dashRemaining = 0
        groundDashJumpRemaining = 0
        dashBufferRemaining = 0
        jumpBufferRemaining = 0
        forcedWallJumpBufferRemaining = 0
        respawnRemaining = config.respawnDelay
        locomotionState = .dead
        signalSink?.emit(.playerDied(DeathEvent(reason: reason, position: position)))
    }

    public func respawn(at spawn: SpawnPoint?) {
        let target = spawn ?? activeCheckpoint?.spawn ?? initialSpawn
        position = target.position
        facing = target.facing
        velocity = .zero
        contacts = CollisionContacts()
        jumpBufferRemaining = 0
        forcedWallJumpBufferRemaining = 0
        dashBufferRemaining = 0
        coyoteRemaining = 0
        wallGraceRemaining = 0
        lastWallSide = 0
        dashRemaining = 0
        groundDashJumpRemaining = 0
        horizontalControlLockRemaining = 0
        respawnRemaining = 0
        airJumpsRemaining = 0
        airDashAvailable = false
        locomotionState = .airborne
        isAlive = true
    }

    public func reachCheckpoint(_ checkpoint: CheckpointDescriptor) {
        guard activeCheckpoint?.id != checkpoint.id else { return }
        activeCheckpoint = checkpoint
        signalSink?.emit(.checkpointReached(CheckpointEvent(checkpoint: checkpoint)))
    }

    public func clearCheckpoint(scope: CheckpointScope) { activeCheckpoint = nil }
}
