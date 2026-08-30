import Foundation

public final class PlayerController: PlayerControlling, CheckpointAccepting, @unchecked Sendable {
    public private(set) var position: Vector2
    public private(set) var velocity: Vector2 = .zero
    public private(set) var contacts = CollisionContacts()
    public private(set) var isAlive = true
    public private(set) var facing = 1

    public let config: PlayerConfig
    public var world: any CollisionWorld
    public weak var signalSink: CoreGameplaySignalSink?

    private var moveAxis: Double = 0
    private var jumpPressed = false
    private var jumpBufferRemaining: Double = 0
    private var coyoteRemaining: Double = 0
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
        if jumpPressed && !pressed && abilities.contains(.variableJump) && velocity.y > 0 {
            velocity.y *= config.jumpCutMultiplier
        }
        if !jumpPressed && pressed { requestJump() }
        jumpPressed = pressed
    }

    public func requestJump() {
        guard abilities.contains(.jump), isAlive else { return }
        jumpBufferRemaining = config.jumpBufferTime
    }

    public func requestDash() {}
    public func requestWallJump() {}

    public func setAbility(_ ability: PlayerAbility, enabled: Bool) {
        if enabled { abilities.insert(ability) } else { abilities.remove(ability) }
        if ability == .jump && !enabled { jumpBufferRemaining = 0 }
    }

    public func hasAbility(_ ability: PlayerAbility) -> Bool {
        abilities.contains(ability)
    }

    public func step(dt: Double) {
        guard dt > 0 else { return }
        guard isAlive else {
            respawnRemaining -= dt
            if respawnRemaining <= 0 { respawn(at: nil) }
            return
        }

        jumpBufferRemaining = max(0, jumpBufferRemaining - dt)
        if contacts.floor {
            coyoteRemaining = config.coyoteTime
        } else {
            coyoteRemaining = max(0, coyoteRemaining - dt)
        }

        let canGroundJump = contacts.floor || coyoteRemaining > 0
        if jumpBufferRemaining > 0 && canGroundJump && abilities.contains(.jump) {
            velocity.y = config.jumpSpeed
            jumpBufferRemaining = 0
            coyoteRemaining = 0
            contacts.floor = false
        }

        let targetX = moveAxis * config.maxRunSpeed
        let accelerating = abs(targetX) > abs(velocity.x) || (targetX * velocity.x < 0)
        let accel: Double
        if contacts.floor {
            accel = accelerating ? config.groundAcceleration : config.groundDeceleration
        } else {
            accel = accelerating ? config.airAcceleration : config.airDeceleration
        }
        velocity.x = approach(velocity.x, targetX, by: accel * dt)

        velocity.y = max(velocity.y - config.gravity * dt, -config.maxFallSpeed)

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

        if contacts.floor && jumpBufferRemaining > 0 && abilities.contains(.jump) {
            velocity.y = config.jumpSpeed
            jumpBufferRemaining = 0
            coyoteRemaining = 0
            contacts.floor = false
        }
    }

    public func kill(reason: DeathReason) {
        guard isAlive else { return }
        isAlive = false
        velocity = .zero
        respawnRemaining = config.respawnDelay
        signalSink?.emit(.playerDied(DeathEvent(reason: reason, position: position)))
    }

    public func respawn(at spawn: SpawnPoint?) {
        let target = spawn ?? activeCheckpoint?.spawn ?? initialSpawn
        position = target.position
        facing = target.facing
        velocity = .zero
        contacts = CollisionContacts()
        jumpBufferRemaining = 0
        coyoteRemaining = 0
        respawnRemaining = 0
        isAlive = true
    }

    public func reachCheckpoint(_ checkpoint: CheckpointDescriptor) {
        guard activeCheckpoint?.id != checkpoint.id else { return }
        activeCheckpoint = checkpoint
        signalSink?.emit(.checkpointReached(CheckpointEvent(checkpoint: checkpoint)))
    }

    public func clearCheckpoint(scope: CheckpointScope) {
        activeCheckpoint = nil
    }
}
