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

func approx(_ a: Double, _ b: Double, eps: Double = 0.05) -> Bool { abs(a - b) <= eps }
func floorWorld() -> StaticCollisionWorld { StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 20, y: 0.5))]) }
func wallWorld() -> StaticCollisionWorld { StaticCollisionWorld(solidBounds: [
    AABB(center: Vector2(x: 2.0, y: 2.0), halfSize: Vector2(x: 0.25, y: 4.0))
]) }
func settle(_ p: PlayerController, ticks: Int = 6, dt: Double = 1.0/120.0) { for _ in 0..<ticks { p.step(dt: dt) } }

func testBaselineMoveAndJump() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    settle(p)
    p.setMoveAxis(1)
    for _ in 0..<120 { p.step(dt: 1.0/120.0) }
    expect(approx(p.velocity.x, p.config.maxRunSpeed), "baseline run speed")
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y > 10, "baseline jump")
}

func testAirJumpSingleChargeAndReset() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.airJump, enabled: true)
    settle(p)
    expect(p.airJumpsRemaining == 1, "air jump charge should refresh on ground")
    p.requestJump(); p.step(dt: 1.0/120.0)
    for _ in 0..<20 { p.step(dt: 1.0/120.0) }
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.airJumpsRemaining == 0, "air jump should consume one charge")
    let secondVy = p.velocity.y
    for _ in 0..<5 { p.step(dt: 1.0/120.0) }
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y < secondVy, "third jump should not be granted")
    for _ in 0..<240 { p.step(dt: 1.0/120.0) }
    expect(p.contacts.floor, "player should land")
    expect(p.airJumpsRemaining == 1, "air jump should reset after landing")
}

func testDashGroundAndAirResource() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true)
    settle(p)
    p.setMoveAxis(1); p.requestDash(); p.step(dt: 1.0/120.0)
    expect(p.locomotionState == .dashing, "ground dash should start")
    expect(p.velocity.x > p.config.maxRunSpeed * 2, "dash should exceed run speed")
    for _ in 0..<20 { p.step(dt: 1.0/120.0) }
    expect(p.velocity.x > p.config.maxRunSpeed, "dash should preserve some exit inertia")

    p.requestJump(); p.step(dt: 1.0/120.0)
    for _ in 0..<20 { p.step(dt: 1.0/120.0) }
    expect(p.airDashAvailable, "air dash should be available after leaving ground")
    p.requestDash(); p.step(dt: 1.0/120.0)
    expect(!p.airDashAvailable, "air dash should consume airborne resource")
    for _ in 0..<20 { p.step(dt: 1.0/120.0) }
    let before = p.velocity.x
    p.requestDash(); p.step(dt: 1.0/120.0)
    expect(p.velocity.x <= before + 0.5, "second air dash should not start")
}

func testDashJumpWindowAcrossDash() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true)
    settle(p)
    p.setMoveAxis(1); p.requestDash()
    for _ in 0..<12 { p.step(dt: 1.0/120.0) }
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y > 9, "ground-origin dash should remain jumpable through dash window")
}

func testWallJumpNaturalAndExplicit() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.5, y: 2.5)), world: wallWorld())
    p.setAbility(.wallJump, enabled: true)
    p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0/120.0); if p.contacts.wallRight { break } }
    expect(p.contacts.wallRight, "test must contact right wall")
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.x < -7 && p.velocity.y > 9, "natural jump on right wall should launch left/up")

    let q = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.5, y: 2.5)), world: wallWorld())
    q.setAbility(.wallJump, enabled: true); q.setMoveAxis(1)
    for _ in 0..<60 { q.step(dt: 1.0/120.0); if q.contacts.wallRight { break } }
    q.requestWallJump(); q.step(dt: 1.0/120.0)
    expect(q.velocity.x < -7 && q.velocity.y > 9, "explicit wall jump should work")
}

func testExplicitWallJumpDoesNotBecomeAirJump() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 4)), world: floorWorld())
    p.setAbility(.wallJump, enabled: true)
    p.setAbility(.airJump, enabled: true)
    p.requestWallJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y < 0, "explicit wall jump away from wall must not consume as air jump")
    expect(p.airJumpsRemaining == 0, "enabling air jump midair should not grant a charge")
}

func testWallJumpControlLockAndRecovery() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.5, y: 2.5)), world: wallWorld())
    p.setAbility(.wallJump, enabled: true); p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0/120.0); if p.contacts.wallRight { break } }
    p.requestJump(); p.step(dt: 1.0/120.0)
    let launchX = p.velocity.x
    p.setMoveAxis(1)
    for _ in 0..<5 { p.step(dt: 1.0/120.0) }
    expect(p.velocity.x < launchX + 0.5, "input must not instantly reverse wall jump")
    for _ in 0..<20 { p.step(dt: 1.0/120.0) }
    expect(p.locomotionState != .wallJumping, "wall jump state should recover after lock")
    expect(p.velocity.x > launchX, "air control should resume after wall jump lock")
}

func testActionPriorityWallJumpOverDash() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.5, y: 2.5)), world: wallWorld())
    p.setAbility(.wallJump, enabled: true); p.setAbility(.dash, enabled: true); p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0/120.0); if p.contacts.wallRight { break } }
    p.requestDash(); p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.x < 0 && p.velocity.y > 0, "wall jump must win same-tick dash/jump priority")
    expect(p.locomotionState == .wallJumping, "priority state should be wallJumping")
}

func testAbilityDisableClearsTransientState() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); settle(p); p.requestDash(); p.step(dt: 1.0/120.0)
    expect(p.locomotionState == .dashing, "dash precondition")
    p.setAbility(.dash, enabled: false)
    expect(!p.airDashAvailable && p.locomotionState != .dashing, "dash disable must clear active transient state")
    let vx = p.velocity.x
    p.requestDash(); p.step(dt: 1.0/120.0)
    expect(p.velocity.x <= vx + 0.1, "disabled dash request ignored")

    p.setAbility(.airJump, enabled: true)
    settle(p); expect(p.airJumpsRemaining == 1, "air jump enabled on ground should arm")
    p.setAbility(.airJump, enabled: false)
    expect(p.airJumpsRemaining == 0, "air jump disable clears charge")
}

func testAirInertiaBleedsToRunCap() {
    var cfg = PlayerConfig(); cfg.dashDuration = 0.05
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld(), config: cfg)
    p.setAbility(.dash, enabled: true); settle(p); p.setMoveAxis(1); p.requestDash()
    for _ in 0..<8 { p.step(dt: 1.0/120.0) }
    p.requestJump(); p.step(dt: 1.0/120.0)
    let initial = abs(p.velocity.x)
    for _ in 0..<120 { p.step(dt: 1.0/120.0) }
    expect(initial > cfg.maxRunSpeed, "test must begin overspeed")
    expect(abs(p.velocity.x) < initial, "overspeed inertia should bleed gradually")
    expect(abs(p.velocity.x) >= cfg.maxRunSpeed - 0.2, "same-direction air control should not snap below run cap")
}

func testVariableJumpAbilityToggle() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    settle(p); p.setAbility(.variableJump, enabled: false)
    p.setJumpPressed(true); p.step(dt: 1.0/120.0); let vy = p.velocity.y; p.setJumpPressed(false)
    expect(approx(p.velocity.y, vy, eps: 0.001), "disabling variable jump must prevent release cut")
}

func testDeathClearsAdvancedState() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); p.setAbility(.airJump, enabled: true); settle(p)
    p.requestDash(); p.step(dt: 1.0/120.0); p.kill(reason: .hazard)
    expect(p.locomotionState == .dead && p.velocity == .zero, "death clears movement")
    for _ in 0..<30 { p.step(dt: 1.0/120.0) }
    expect(p.isAlive && p.locomotionState != .dead && p.locomotionState != .dashing, "respawn clears advanced locomotion state")
    expect(p.contacts.floor && p.airDashAvailable && p.airJumpsRemaining == 1, "ground contact after respawn should re-arm enabled resources")
}

func testCeilingCollisionRegression() {
    let world = StaticCollisionWorld(solidBounds: [
        AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 10, y: 0.5)),
        AABB(center: Vector2(x: 0, y: 2.1), halfSize: Vector2(x: 2.0, y: 0.2))
    ])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: world)
    settle(p); p.requestJump()
    var hit = false
    for _ in 0..<120 { p.step(dt: 1.0/120.0); if p.contacts.ceiling { hit = true; break } }
    expect(hit && p.velocity.y <= 0.001, "ceiling collision regression")
}

func testCoyoteRegression() {
    let world = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: -1, y: -0.5), halfSize: Vector2(x: 1, y: 0.5))])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: -0.2, y: 0.45)), world: world)
    settle(p); p.setMoveAxis(1)
    var left = false
    for _ in 0..<60 { p.step(dt: 1.0/120.0); if !p.contacts.floor && p.position.x > 0.3 { left = true; break } }
    expect(left, "coyote setup")
    p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y > 9, "coyote regression")
}

func testJumpBufferRegression() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 1.4)), world: floorWorld())
    var requested = false, fired = false
    for _ in 0..<120 {
        if !requested && p.position.y < 0.75 { p.requestJump(); requested = true }
        p.step(dt: 1.0/120.0)
        if requested && p.velocity.y > 9 { fired = true; break }
    }
    expect(requested && fired, "jump buffer regression")
}

func testCheckpointDeathSignalRegression() {
    let sink = SignalRecorder()
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld(), signalSink: sink)
    let cp = CheckpointDescriptor(id: "cp2", spawn: SpawnPoint(position: Vector2(x: 4, y: 0.45), facing: -1))
    p.reachCheckpoint(cp); p.kill(reason: .hazard)
    for _ in 0..<30 { p.step(dt: 1.0/120.0) }
    expect(p.position == cp.spawn.position && p.facing == -1, "checkpoint respawn regression")
    expect(sink.signals.contains(.checkpointReached(CheckpointEvent(checkpoint: cp))), "checkpoint signal regression")
    expect(sink.signals.contains(.playerDied(DeathEvent(reason: .hazard, position: Vector2(x: 0, y: 0.45)))), "death signal regression")
}

func testAdvancedAbilitiesDefaultOff() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    settle(p)
    expect(!p.hasAbility(.airJump) && !p.hasAbility(.dash) && !p.hasAbility(.wallJump), "advanced abilities must remain progression-controlled by default")
}

func testGroundJumpPriorityOverDash() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); settle(p); p.setMoveAxis(1)
    p.requestDash(); p.requestJump(); p.step(dt: 1.0/120.0)
    expect(p.velocity.y > 9 && p.locomotionState != .dashing, "same-tick ground jump should deterministically win over dash")
}

@main
struct TestMain {
    static func main() {
        testBaselineMoveAndJump()
        testAirJumpSingleChargeAndReset()
        testDashGroundAndAirResource()
        testDashJumpWindowAcrossDash()
        testWallJumpNaturalAndExplicit()
        testExplicitWallJumpDoesNotBecomeAirJump()
        testWallJumpControlLockAndRecovery()
        testActionPriorityWallJumpOverDash()
        testAbilityDisableClearsTransientState()
        testAirInertiaBleedsToRunCap()
        testVariableJumpAbilityToggle()
        testDeathClearsAdvancedState()
        testCeilingCollisionRegression()
        testCoyoteRegression()
        testJumpBufferRegression()
        testCheckpointDeathSignalRegression()
        testAdvancedAbilitiesDefaultOff()
        testGroundJumpPriorityOverDash()
        print("PASS: 18 Next2 Core Gameplay test groups")
    }
}
