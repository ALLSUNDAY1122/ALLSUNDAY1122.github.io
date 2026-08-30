import Foundation

final class SignalRecorder: CoreGameplaySignalSink {
    var signals: [CoreGameplaySignal] = []
    func emit(_ signal: CoreGameplaySignal) { signals.append(signal) }
}

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func approx(_ a: Double, _ b: Double, eps: Double = 0.02) -> Bool { abs(a - b) <= eps }

func makeFloorWorld() -> StaticCollisionWorld {
    StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 20, y: 0.5))])
}

func settle(_ player: PlayerController, ticks: Int = 4, dt: Double = 1.0 / 120.0) {
    for _ in 0..<ticks { player.step(dt: dt) }
}

func testHorizontalAccelerationAndDeceleration() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: makeFloorWorld())
    settle(p)
    p.setMoveAxis(1)
    for _ in 0..<120 { p.step(dt: 1.0 / 120.0) }
    expect(approx(p.velocity.x, p.config.maxRunSpeed), "run speed should reach configured max")
    p.setMoveAxis(0)
    for _ in 0..<30 { p.step(dt: 1.0 / 120.0) }
    expect(abs(p.velocity.x) < 0.01, "ground deceleration should stop player")
}

func testJumpAndVariableCut() {
    let full = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: makeFloorWorld())
    settle(full)
    full.setJumpPressed(true)
    full.step(dt: 1.0 / 120.0)
    let fullVy = full.velocity.y
    expect(fullVy > 10, "jump should create upward velocity")

    let cut = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: makeFloorWorld())
    settle(cut)
    cut.setJumpPressed(true)
    cut.step(dt: 1.0 / 120.0)
    cut.setJumpPressed(false)
    expect(cut.velocity.y < fullVy * 0.6, "jump release should cut ascent")
}

func testCeilingAndWallCollision() {
    let world = StaticCollisionWorld(solidBounds: [
        AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 10, y: 0.5)),
        AABB(center: Vector2(x: 2.0, y: 2.0), halfSize: Vector2(x: 0.25, y: 2.0)),
        AABB(center: Vector2(x: 0, y: 2.1), halfSize: Vector2(x: 2.0, y: 0.2))
    ])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: world)
    settle(p)
    p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0 / 120.0) }
    expect(p.position.x <= 1.41, "wall must stop horizontal motion")

    p.setMoveAxis(0)
    p.setJumpPressed(true)
    var hitCeiling = false
    for _ in 0..<120 {
        p.step(dt: 1.0 / 120.0)
        if p.contacts.ceiling { hitCeiling = true; break }
    }
    expect(hitCeiling, "ceiling collision should be reported")
    expect(p.velocity.y <= 0.001, "ceiling should cancel upward velocity")
}

func testCoyoteTime() {
    let world = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: -1, y: -0.5), halfSize: Vector2(x: 1, y: 0.5))])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: -0.2, y: 0.45)), world: world)
    settle(p)
    p.setMoveAxis(1)
    var leftFloor = false
    for _ in 0..<60 {
        p.step(dt: 1.0 / 120.0)
        if !p.contacts.floor && p.position.x > 0.3 { leftFloor = true; break }
    }
    expect(leftFloor, "test setup should leave platform")
    p.requestJump()
    p.step(dt: 1.0 / 120.0)
    expect(p.velocity.y > 9, "coyote jump should succeed shortly after leaving floor")
}

func testJumpBuffer() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 1.4)), world: makeFloorWorld())
    var requested = false
    var bufferedJumped = false
    for _ in 0..<120 {
        if !requested && p.position.y < 0.75 {
            p.requestJump()
            requested = true
        }
        p.step(dt: 1.0 / 120.0)
        if requested && p.velocity.y > 9 { bufferedJumped = true; break }
    }
    expect(requested && bufferedJumped, "jump buffer should fire on landing")
}

func testDeathCheckpointRespawnAndSignal() {
    let sink = SignalRecorder()
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: makeFloorWorld(), signalSink: sink)
    let checkpoint = CheckpointDescriptor(id: "cp1", spawn: SpawnPoint(position: Vector2(x: 5, y: 0.45), facing: -1))
    p.reachCheckpoint(checkpoint)
    p.kill(reason: .hazard)
    expect(!p.isAlive, "kill should mark player dead")
    for _ in 0..<40 { p.step(dt: 1.0 / 120.0) }
    expect(p.isAlive, "player should automatically respawn after delay")
    expect(p.position == checkpoint.spawn.position && p.facing == -1, "respawn should use active checkpoint")
    expect(sink.signals.contains(.checkpointReached(CheckpointEvent(checkpoint: checkpoint))), "checkpoint signal missing")
    expect(sink.signals.contains(.playerDied(DeathEvent(reason: .hazard, position: Vector2(x: 0, y: 0.45)))), "death signal missing")
}

@main
struct TestMain {
    static func main() {
        testHorizontalAccelerationAndDeceleration()
        testJumpAndVariableCut()
        testCeilingAndWallCollision()
        testCoyoteTime()
        testJumpBuffer()
        testDeathCheckpointRespawnAndSignal()
        print("PASS: 6 Core Gameplay test groups")
    }
}
