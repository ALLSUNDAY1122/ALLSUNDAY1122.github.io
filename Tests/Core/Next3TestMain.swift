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

func approx(_ a: Double, _ b: Double, eps: Double = 0.03) -> Bool { abs(a - b) <= eps }
func floorWorld() -> StaticCollisionWorld { StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 30, y: 0.5))]) }
func settle(_ p: PlayerController, ticks: Int = 6) { for _ in 0..<ticks { p.step(dt: 1.0 / 120.0) } }

func simulateAtDisplayHz(_ hz: Double) -> (PlayerController, FixedStepClock) {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.airJump, enabled: true)
    p.setAbility(.dash, enabled: true)
    var clock = FixedStepClock()
    let frames = Int(hz * 3.0)
    for _ in 0..<frames {
        clock.advance(frameDelta: 1.0 / hz) { dt, tick in
            switch tick {
            case 0: p.setMoveAxis(1)
            case 36: p.requestJump()
            case 68: p.requestDash()
            case 92: p.requestJump()
            case 150: p.setMoveAxis(-1)
            case 220: p.setMoveAxis(0)
            default: break
            }
            p.step(dt: dt)
        }
    }
    return (p, clock)
}

func testFixedStep60Vs120Equivalence() {
    let a = simulateAtDisplayHz(60)
    let b = simulateAtDisplayHz(120)
    expect(a.1.tick == b.1.tick && a.1.tick == 360, "60/120 clocks must execute identical 120 Hz ticks")
    expect(approx(a.0.position.x, b.0.position.x, eps: 0.0001), "60/120 x position mismatch")
    expect(approx(a.0.position.y, b.0.position.y, eps: 0.0001), "60/120 y position mismatch")
    expect(approx(a.0.velocity.x, b.0.velocity.x, eps: 0.0001), "60/120 x velocity mismatch")
    expect(approx(a.0.velocity.y, b.0.velocity.y, eps: 0.0001), "60/120 y velocity mismatch")
    expect(a.0.locomotionState == b.0.locomotionState, "60/120 locomotion state mismatch")
}

func testFixedStepClampAndDropAccounting() {
    var clock = FixedStepClock()
    var count = 0
    let frame = clock.advance(frameDelta: 0.5) { _, _ in count += 1 }
    expect(count == 12, "stall frame must cap work")
    expect(frame.droppedTime > 0.39, "stall time must be surfaced instead of hidden")
    expect(clock.totalDroppedTime == frame.droppedTime, "drop accounting mismatch")
}

func testFixedStepLongRunNoDrift() {
    var a = FixedStepClock()
    var b = FixedStepClock()
    for _ in 0..<3600 { a.advance(frameDelta: 1.0 / 60.0) { _, _ in } }
    for _ in 0..<7200 { b.advance(frameDelta: 1.0 / 120.0) { _, _ in } }
    expect(a.tick == 7200 && b.tick == 7200, "one-minute fixed-step clocks must not drift")
    expect(abs(a.accumulator) < 1e-9 && abs(b.accumulator) < 1e-9, "one-minute accumulator drift")
}

func testIrregularDisplayDeltasStillProduceExpectedTicks() {
    var clock = FixedStepClock()
    var elapsed = 0.0
    let pattern = [0.007, 0.011, 0.016, 0.009, 0.013]
    var index = 0
    while elapsed < 1.0 - 1e-12 {
        let remaining = 1.0 - elapsed
        let delta = min(pattern[index % pattern.count], remaining)
        clock.advance(frameDelta: delta) { _, _ in }
        elapsed += delta
        index += 1
    }
    expect(clock.tick == 120, "irregular display timing should still yield 120 simulation ticks per second")
    expect(abs(clock.accumulator) < 1e-8, "irregular display timing left unexpected accumulator")
}

func testHighSpeedHorizontalNoTunneling() {
    let wall = AABB(center: Vector2(x: 3, y: 1), halfSize: Vector2(x: 0.04, y: 2))
    let result = AxisSeparatedCollisionSolver.move(
        position: Vector2(x: 0, y: 1), velocity: Vector2(x: 500, y: 0),
        halfSize: Vector2(x: 0.35, y: 0.45), dt: 1.0 / 30.0,
        world: StaticCollisionWorld(solidBounds: [wall])
    )
    expect(result.contacts.wallRight, "high-speed wall collision not reported")
    expect(result.position.x <= wall.minX - 0.35 + 0.0001, "high-speed body tunneled through wall")
    expect(abs(result.velocity.x) < 0.001, "wall impact must cancel x velocity")
}

func testHighSpeedVerticalNoTunneling() {
    let floor = AABB(center: Vector2(x: 0, y: 0), halfSize: Vector2(x: 10, y: 0.05))
    let result = AxisSeparatedCollisionSolver.move(
        position: Vector2(x: 0, y: 10), velocity: Vector2(x: 0, y: -600),
        halfSize: Vector2(x: 0.35, y: 0.45), dt: 1.0 / 30.0,
        world: StaticCollisionWorld(solidBounds: [floor])
    )
    expect(result.contacts.floor, "high-speed floor collision not reported")
    expect(result.position.y >= floor.maxY + 0.45 - 0.0001, "high-speed body tunneled through floor")
}

func testDiagonalCornerNoSkip() {
    let corner = AABB(center: Vector2(x: 2, y: 2), halfSize: Vector2(x: 0.12, y: 0.12))
    let result = AxisSeparatedCollisionSolver.move(
        position: Vector2(x: 0, y: 0), velocity: Vector2(x: 110, y: 110),
        halfSize: Vector2(x: 0.35, y: 0.45), dt: 0.03,
        world: StaticCollisionWorld(solidBounds: [corner])
    )
    let body = AABB(center: result.position, halfSize: Vector2(x: 0.35, y: 0.45))
    let overlaps = body.maxX > corner.minX && body.minX < corner.maxX && body.maxY > corner.minY && body.minY < corner.maxY
    expect(!overlaps, "diagonal corner must not end penetrated")
    expect(result.contacts.wallRight || result.contacts.ceiling || result.contacts.floor || result.contacts.wallLeft, "diagonal crossing should produce a contact")
}

func testInitialPenetrationRecovery() {
    let solid = AABB(center: Vector2(x: 0, y: 0), halfSize: Vector2(x: 1, y: 1))
    let result = AxisSeparatedCollisionSolver.move(
        position: Vector2(x: 0.9, y: 0), velocity: .zero,
        halfSize: Vector2(x: 0.35, y: 0.45), dt: 1.0 / 120.0,
        world: StaticCollisionWorld(solidBounds: [solid])
    )
    let body = AABB(center: result.position, halfSize: Vector2(x: 0.35, y: 0.45))
    let overlaps = body.maxX > solid.minX && body.minX < solid.maxX && body.maxY > solid.minY && body.minY < solid.maxY
    expect(!overlaps, "defensive depenetration failed")
}

func testRestingFloorContactDuringZeroVerticalDash() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); settle(p)
    p.setMoveAxis(1); p.requestDash(); p.step(dt: 1.0 / 120.0)
    expect(p.contacts.floor, "floor contact should persist during zero-y dash")
    for _ in 0..<8 { p.step(dt: 1.0 / 120.0); expect(p.contacts.floor, "dash should not flicker floor contact") }
}

func testRestingWallProbe() {
    let wall = AABB(center: Vector2(x: 2, y: 2), halfSize: Vector2(x: 0.2, y: 3))
    let world = StaticCollisionWorld(solidBounds: [wall])
    let touchingX = wall.minX - 0.35
    let result = AxisSeparatedCollisionSolver.move(
        position: Vector2(x: touchingX, y: 2), velocity: Vector2(x: 0, y: -0.1),
        halfSize: Vector2(x: 0.35, y: 0.45), dt: 1.0 / 120.0, world: world
    )
    expect(result.contacts.wallRight, "resting wall contact should remain visible without x velocity")
}

func testDashWallImpactEndsImmediately() {
    let world = StaticCollisionWorld(solidBounds: [
        AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 20, y: 0.5)),
        AABB(center: Vector2(x: 2, y: 1.5), halfSize: Vector2(x: 0.15, y: 2))
    ])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: world)
    p.setAbility(.dash, enabled: true); p.setAbility(.wallJump, enabled: true); settle(p)
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    for _ in 0..<8 { p.step(dt: 1.0 / 120.0) }
    p.setMoveAxis(1); p.requestDash()
    var hit = false
    for _ in 0..<30 {
        p.step(dt: 1.0 / 120.0)
        if p.contacts.wallRight { hit = true; break }
    }
    expect(hit, "dash-wall setup failed")
    expect(p.locomotionState != .dashing, "wall impact should terminate active dash")
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.x < 0 && p.velocity.y > 9, "wall jump should be available on tick after dash impact")
}

func testDashLateJumpStillResponsive() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); settle(p); p.setMoveAxis(1); p.requestDash()
    for _ in 0..<15 { p.step(dt: 1.0 / 120.0) }
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.y > 9, "late dash jump should not be swallowed")
    expect(p.velocity.x > p.config.maxRunSpeed, "late dash jump should retain useful horizontal momentum")
}

func testAirJumpAfterLongJumpDashSequence() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.airJump, enabled: true); p.setAbility(.dash, enabled: true); settle(p)
    p.setJumpPressed(true); p.step(dt: 1.0 / 120.0)
    for _ in 0..<28 { p.step(dt: 1.0 / 120.0) }
    p.requestDash(); p.step(dt: 1.0 / 120.0)
    for _ in 0..<5 { p.step(dt: 1.0 / 120.0) }
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.y > 9, "air jump after held jump + dash should be deterministic")
    expect(p.airJumpsRemaining == 0, "air jump resource should consume exactly once")
}

func testCoyoteAndJumpBufferRegression() {
    let ledge = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: -1, y: -0.5), halfSize: Vector2(x: 1, y: 0.5))])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: -0.2, y: 0.45)), world: ledge)
    settle(p); p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0 / 120.0); if !p.contacts.floor && p.position.x > 0.2 { break } }
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.y > 9, "coyote regression")

    let q = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 1.4)), world: floorWorld())
    var fired = false
    for _ in 0..<120 {
        if q.position.y < 0.72 && q.velocity.y < 0 { q.requestJump() }
        q.step(dt: 1.0 / 120.0)
        if q.velocity.y > 9 { fired = true; break }
    }
    expect(fired, "jump buffer regression")
}

func testAbilityDisableRegression() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); settle(p); p.requestDash(); p.step(dt: 1.0 / 120.0)
    p.setAbility(.dash, enabled: false)
    expect(p.locomotionState != .dashing && !p.airDashAvailable, "dash disable cleanup regression")
    p.setAbility(.airJump, enabled: true); settle(p); expect(p.airJumpsRemaining == 1, "air jump enable on ground")
    p.setAbility(.airJump, enabled: false); expect(p.airJumpsRemaining == 0, "air jump disable cleanup")
}

func testDeathRespawnAdvancedResources() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.dash, enabled: true); p.setAbility(.airJump, enabled: true); settle(p)
    p.kill(reason: .hazard)
    for _ in 0..<30 { p.step(dt: 1.0 / 120.0) }
    expect(p.isAlive, "respawn regression")
    p.step(dt: 1.0 / 120.0)
    expect(p.contacts.floor && p.airDashAvailable && p.airJumpsRemaining == 1, "respawn must deterministically restore grounded resources")
}

func testCameraDeadZoneStability() {
    let c = CameraFollower(initialTarget: .zero)
    let before = c.position
    for _ in 0..<120 { c.step(dt: 1.0 / 120.0, target: Vector2(x: 0.1, y: 0.1), velocity: .zero, facing: 1) }
    expect(abs(c.position.y - before.y) < 0.05, "small vertical motion inside dead zone should not cause camera drift")
}

func testCameraTeleportSnap() {
    let c = CameraFollower(initialTarget: .zero)
    c.step(dt: 1.0 / 120.0, target: Vector2(x: 50, y: 20), velocity: .zero, facing: -1)
    expect(abs(c.position.x - (50 + c.lookAhead)) < 0.001, "large teleport should snap camera x")
    expect(abs(c.position.y - 20.3) < 0.001, "large teleport should snap camera y")
}

func simulateCamera(_ hz: Double) -> CameraSnapshot {
    let c = CameraFollower(initialTarget: .zero)
    var clock = FixedStepClock()
    var target = Vector2.zero
    var velocity = Vector2.zero
    for _ in 0..<Int(hz * 2) {
        clock.advance(frameDelta: 1.0 / hz) { dt, tick in
            if tick < 120 { velocity = Vector2(x: 6, y: 2) } else { velocity = Vector2(x: -4, y: -1) }
            target = target + velocity * dt
            c.step(dt: dt, target: target, velocity: velocity, facing: velocity.x >= 0 ? 1 : -1)
        }
    }
    return c.snapshot()
}

func testCamera60Vs120Equivalence() {
    let a = simulateCamera(60)
    let b = simulateCamera(120)
    expect(approx(a.position.x, b.position.x, eps: 0.0001), "camera x differs at 60/120")
    expect(approx(a.position.y, b.position.y, eps: 0.0001), "camera y differs at 60/120")
    expect(approx(a.lookAhead, b.lookAhead, eps: 0.0001), "camera lookahead differs at 60/120")
}

func testCameraExplicitRespawnSnap() {
    let c = CameraFollower(initialTarget: Vector2(x: 3, y: 4))
    c.snap(to: Vector2(x: -12, y: 8), facing: -1)
    expect(approx(c.position.x, -12, eps: 0.001), "camera respawn snap x")
    expect(approx(c.position.y, 8.3, eps: 0.001), "camera respawn snap y")
    expect(c.lookAhead < 0, "camera snap should align lookahead with facing")
}

func testGroundMoveJumpRegression() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    settle(p); p.setMoveAxis(1)
    for _ in 0..<120 { p.step(dt: 1.0 / 120.0) }
    expect(approx(p.velocity.x, p.config.maxRunSpeed), "run regression")
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.y > 10, "jump regression")
}

func testWallJumpGraceRegression() {
    let world = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 2, y: 2), halfSize: Vector2(x: 0.2, y: 4))])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.7, y: 2.5)), world: world)
    p.setAbility(.wallJump, enabled: true); p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0 / 120.0); if p.contacts.wallRight { break } }
    expect(p.contacts.wallRight, "wall setup")
    p.setMoveAxis(-1); p.step(dt: 1.0 / 120.0)
    p.requestJump(); p.step(dt: 1.0 / 120.0)
    expect(p.velocity.x < 0 && p.velocity.y > 9, "wall grace should survive brief separation")
}

@main
struct TestMain {
    static func main() {
        testFixedStep60Vs120Equivalence()
        testFixedStepClampAndDropAccounting()
        testFixedStepLongRunNoDrift()
        testIrregularDisplayDeltasStillProduceExpectedTicks()
        testHighSpeedHorizontalNoTunneling()
        testHighSpeedVerticalNoTunneling()
        testDiagonalCornerNoSkip()
        testInitialPenetrationRecovery()
        testRestingFloorContactDuringZeroVerticalDash()
        testRestingWallProbe()
        testDashWallImpactEndsImmediately()
        testDashLateJumpStillResponsive()
        testAirJumpAfterLongJumpDashSequence()
        testCoyoteAndJumpBufferRegression()
        testAbilityDisableRegression()
        testDeathRespawnAdvancedResources()
        testCameraDeadZoneStability()
        testCameraTeleportSnap()
        testCamera60Vs120Equivalence()
        testCameraExplicitRespawnSnap()
        testGroundMoveJumpRegression()
        testWallJumpGraceRegression()
        print("PASS: 22 Next3 Core Gameplay quality test groups")
    }
}
