import Foundation

final class FinalSignalSink: CoreGameplaySignalSink {
    var signals: [CoreGameplaySignal] = []
    func emit(_ signal: CoreGameplaySignal) { signals.append(signal) }
}

final class FinalReplayStub: ReplayStateSource {
    var position = Vector2.zero
    var velocity = Vector2.zero
    var facing = 1
    var locomotionState: PlayerLocomotionState = .grounded
    var airJumpsRemaining = 1
    var airDashAvailable = true
    var isAlive = true
}

@inline(__always) func require(_ ok: @autoclosure () -> Bool, _ message: String) {
    if !ok() { print("FAIL: \(message)"); exit(1) }
}

func floorWorld() -> StaticCollisionWorld {
    StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 0, y: -0.5), halfSize: Vector2(x: 50, y: 0.5))])
}

func settle(_ p: PlayerController) { for _ in 0..<5 { p.step(dt: 1.0 / 120.0) } }

func testDashJumpRegressions() {
    let same = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    same.setAbility(.dash, enabled: true); settle(same); same.setMoveAxis(1)
    same.requestDash(); same.requestJump(); same.step(dt: 1.0 / 120.0)
    require(same.velocity.x > same.config.maxRunSpeed * 2 && same.velocity.y > 10, "same-tick dash+jump")

    let ledge = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: -1, y: -0.5), halfSize: Vector2(x: 1, y: 0.5))])
    let late = PlayerController(spawn: SpawnPoint(position: Vector2(x: -0.05, y: 0.45)), world: ledge)
    late.setAbility(.dash, enabled: true); settle(late); late.setMoveAxis(1); late.requestDash()
    for _ in 0..<15 { late.step(dt: 1.0 / 120.0) }
    require(!late.contacts.floor, "ledge setup")
    late.requestJump(); late.step(dt: 1.0 / 120.0)
    require(late.velocity.y > 10 && late.velocity.x > late.config.maxRunSpeed, "late ledge dash-jump")
}

func testWallPriorityAndAbilityCleanup() {
    let world = StaticCollisionWorld(solidBounds: [AABB(center: Vector2(x: 2, y: 2), halfSize: Vector2(x: 0.2, y: 4))])
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0.7, y: 2.5)), world: world)
    p.setAbility(.wallJump, enabled: true); p.setAbility(.dash, enabled: true); p.setMoveAxis(1)
    for _ in 0..<60 { p.step(dt: 1.0 / 120.0); if p.contacts.wallRight { break } }
    p.requestDash(); p.requestJump(); p.step(dt: 1.0 / 120.0)
    require(p.locomotionState == .wallJumping && p.velocity.x < 0 && p.velocity.y > 9, "wall priority")
    p.setAbility(.dash, enabled: false); p.setAbility(.airJump, enabled: false)
    require(!p.airDashAvailable && p.airJumpsRemaining == 0, "ability cleanup")
}

func testLapSignal() {
    let sink = FinalSignalSink(); let lap = FixedTickLapTimer(signalSink: sink)
    require(lap.beginLap(courseID: "c", atTick: 120), "lap begin")
    require(!lap.beginLap(courseID: "c", atTick: 121), "duplicate lap begin")
    let event = lap.finishLap(courseID: "c", atTick: 360)
    require(event == LapEvent(courseID: "c", elapsed: 2), "lap elapsed")
    require(sink.signals == [.lapCompleted(LapEvent(courseID: "c", elapsed: 2))], "lap signal")
    lap.beginLap(courseID: "x", atTick: 1); lap.cancelLap(courseID: "x")
    require(lap.finishLap(courseID: "x", atTick: 2) == nil, "lap cancel")
}

func makeRecording(count: Int = 7) -> ReplayRecording {
    let s = FinalReplayStub(); let replay = ReplaySystem()
    replay.startRecording(context: ReplayContext(courseID: "r", startedAtTick: 10))
    for i in 0..<count {
        s.position = Vector2(x: Double(i), y: Double(i % 2)); s.velocity = Vector2(x: Double(i), y: -Double(i))
        s.isAlive = i != count - 2
        require(replay.captureTick(tick: 10 + UInt64(i), state: s), "record capture")
        if i == 2 { require(replay.recordMarker(tick: 12, kind: .checkpointReached("cp")), "marker") }
    }
    return replay.stopRecording()!
}

func testReplayValidation() {
    let s = FinalReplayStub(); let recorder = ReplayRecorder()
    recorder.start(context: ReplayContext(courseID: "gap", startedAtTick: 0))
    require(recorder.capture(tick: 0, state: s, input: ReplayInputSample()), "gap first")
    require(!recorder.capture(tick: 2, state: s, input: ReplayInputSample()), "gap reject")
    require(recorder.stop() == nil, "gap invalidates run")

    let valid = makeRecording(count: 3)
    let gap = [valid.frames[0], ReplayFrame(tick: valid.frames[0].tick + 2, position: .zero, velocity: .zero, input: ReplayInputSample(), locomotionState: .airborne, resources: ReplayResourceState(airJumpsRemaining: 0, airDashAvailable: false), facing: 1, isAlive: true)]
    do { _ = try ReplayRecording(context: valid.context, frames: gap); require(false, "external gap accepted") }
    catch let e as ReplayValidationError { require(e == .nonContiguousTicks, "gap error") }
    catch { require(false, "unexpected gap error") }

    let badMarker = ReplayMarker(tick: valid.frames[0].tick + 1, frameIndex: 0, kind: .checkpointReached("bad"))
    do { _ = try ReplayRecording(context: valid.context, frames: valid.frames, markers: [badMarker]); require(false, "marker mismatch accepted") }
    catch let e as ReplayValidationError { require(e == .markerTickMismatch, "marker error") }
    catch { require(false, "unexpected marker error") }
}

func testCloneStress() {
    let r = makeRecording(count: 11); let replay = ReplaySystem(); _ = replay.spawnClone(recording: r)
    var last: CloneSnapshot! = nil
    for _ in 0..<200_000 { last = replay.stepClones()[0] }
    let expected = (200_000 - 1) % r.frameCount
    require(last.frameIndex == expected && last.position == r.frames[expected].position, "single clone drift")
    replay.removeAllClones()
    for i in 0..<64 { _ = replay.spawnClone(recording: r, options: CloneSpawnOptions(startFrame: i % r.frameCount, phaseOffsetTicks: i % 5)) }
    for _ in 0..<20_000 { _ = replay.stepClones() }
    let states = replay.stepClones(); require(states.count == 64, "clone count")
    for state in states { require(state.position == r.frames[state.frameIndex].position, "multi clone drift") }
}

func testFixedClock60Vs120() {
    func run(_ hz: Double) -> UInt64 {
        var clock = FixedStepClock()
        for _ in 0..<Int(hz * 600) { clock.advance(frameDelta: 1 / hz) { _, _ in } }
        require(abs(clock.accumulator) < 1e-8, "clock accumulator")
        return clock.tick
    }
    require(run(60) == 72_000 && run(120) == 72_000, "10-minute fixed clock equivalence")
}

func testDeathRespawnStress() {
    let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
    p.setAbility(.airJump, enabled: true); p.setAbility(.dash, enabled: true); settle(p)
    for _ in 0..<100 {
        p.requestDash(); p.step(dt: 1.0 / 120.0); p.kill(reason: .hazard)
        for _ in 0..<26 { p.step(dt: 1.0 / 120.0) }
        p.step(dt: 1.0 / 120.0)
        require(p.isAlive && p.contacts.floor && p.airJumpsRemaining == 1 && p.airDashAvailable, "death/respawn stress")
    }
}

func testCollisionAndCamera() {
    let wall = AABB(center: Vector2(x: 3, y: 1), halfSize: Vector2(x: 0.04, y: 2))
    let hit = AxisSeparatedCollisionSolver.move(position: Vector2(x: 0, y: 1), velocity: Vector2(x: 500, y: 0), halfSize: Vector2(x: 0.35, y: 0.45), dt: 1.0 / 30.0, world: StaticCollisionWorld(solidBounds: [wall]))
    require(hit.contacts.wallRight && hit.velocity.x == 0, "high-speed collision")
    let camera = CameraFollower(initialTarget: .zero); camera.snap(to: Vector2(x: 20, y: 7), facing: -1)
    require(camera.position == Vector2(x: 20, y: 7.3) && camera.lookAhead < 0, "camera snap")
}

func testAllAbilityCombinationsDeterministic() {
    let list: [PlayerAbility] = [.jump, .variableJump, .airJump, .dash, .wallJump]
    for mask in 0..<32 {
        func player() -> PlayerController {
            let p = PlayerController(spawn: SpawnPoint(position: Vector2(x: 0, y: 0.45)), world: floorWorld())
            for (bit, ability) in list.enumerated() { p.setAbility(ability, enabled: mask & (1 << bit) != 0) }
            return p
        }
        let a = player(), b = player()
        for tick in 0..<600 {
            for p in [a, b] {
                if tick == 0 { p.setMoveAxis(1) }
                if tick == 24 { p.requestDash(); p.requestJump() }
                if tick == 80 { p.requestDash() }
                if tick == 105 { p.requestJump() }
                if tick == 180 { p.setMoveAxis(-1) }
                if tick == 220 { p.requestDash(); p.requestJump() }
                if tick == 400 { p.setMoveAxis(1) }
                p.step(dt: 1.0 / 120.0)
            }
        }
        require(a.position == b.position && a.velocity == b.velocity && a.locomotionState == b.locomotionState, "ability mask \(mask)")
        if mask & (1 << 2) == 0 { require(a.airJumpsRemaining == 0, "air jump leak \(mask)") }
        if mask & (1 << 3) == 0 { require(!a.airDashAvailable, "dash leak \(mask)") }
    }
}

@main
struct Next5RegressionMain {
    static func main() {
        testDashJumpRegressions(); testWallPriorityAndAbilityCleanup(); testLapSignal(); testReplayValidation(); testCloneStress()
        testFixedClock60Vs120(); testDeathRespawnStress(); testCollisionAndCamera(); testAllAbilityCombinationsDeterministic()
        print("PASS: 9 Next5 committed regression groups")
    }
}
