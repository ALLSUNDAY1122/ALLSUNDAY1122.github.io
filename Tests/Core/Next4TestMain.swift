import Foundation

final class StateStub: ReplayStateSource {
    var position = Vector2.zero
    var velocity = Vector2.zero
    var facing = 1
    var locomotionState: PlayerLocomotionState = .grounded
    var airJumpsRemaining = 1
    var airDashAvailable = true
    var isAlive = true
}

final class SignalRecorder: CoreGameplaySignalSink {
    var signals: [CoreGameplaySignal] = []
    func emit(_ signal: CoreGameplaySignal) { signals.append(signal) }
}

@inline(__always)
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

func makeRecording(frameCount: Int = 8, courseID: String = "course-A") -> ReplayRecording {
    let source = StateStub()
    let system = ReplaySystem()
    system.startRecording(context: ReplayContext(courseID: courseID, startedAtTick: 100))
    for i in 0..<frameCount {
        source.position = Vector2(x: Double(i) * 0.25, y: Double(i % 3))
        source.velocity = Vector2(x: 3 + Double(i), y: Double(i) * 0.1)
        source.facing = i % 2 == 0 ? 1 : -1
        source.locomotionState = i == 3 ? .dashing : .airborne
        source.airJumpsRemaining = i < 4 ? 1 : 0
        source.airDashAvailable = i < 5
        source.isAlive = i != 6
        let input = ReplayInputSample(moveAxis: i % 2 == 0 ? 1 : -1, jumpHeld: i == 1 || i == 2, jumpPressedThisTick: i == 1, dashPressedThisTick: i == 3, wallJumpPressedThisTick: false)
        expect(system.captureTick(tick: 100 + UInt64(i), state: source, input: input), "capture failed at \(i)")
        if i == 2 { expect(system.recordMarker(tick: 102, kind: .checkpointReached("cp-1")), "checkpoint marker") }
        if i == 6 { expect(system.recordMarker(tick: 106, kind: .playerDied(.hazard)), "death marker") }
    }
    guard let recording = system.stopRecording() else { fatalError("recording missing") }
    return recording
}

func testRecordingCapturesAuthoritativeStateAndInput() {
    let r = makeRecording()
    expect(r.frameCount == 8, "frame count")
    expect(r.frames[3].position == Vector2(x: 0.75, y: 0), "position capture")
    expect(r.frames[3].input.dashPressedThisTick, "dash input capture")
    expect(r.frames[3].locomotionState == .dashing, "state capture")
    expect(!r.frames[6].isAlive, "death state capture")
    expect(r.markers.count == 2, "marker capture")
}

func testMonotonicTickGuard() {
    let source = StateStub(); let recorder = ReplayRecorder()
    recorder.start(context: ReplayContext(courseID: "x", startedAtTick: 0))
    expect(recorder.capture(tick: 10, state: source, input: ReplayInputSample()), "first capture")
    expect(!recorder.capture(tick: 10, state: source, input: ReplayInputSample()), "duplicate tick must reject")
    expect(!recorder.capture(tick: 9, state: source, input: ReplayInputSample()), "reverse tick must reject")
}

func testRecordingCompletedSignal() {
    let sink = SignalRecorder(); let source = StateStub(); let system = ReplaySystem(signalSink: sink)
    system.startRecording(context: ReplayContext(courseID: "x", startedAtTick: 1)); _ = system.captureTick(tick: 1, state: source); _ = system.stopRecording()
    expect(sink.signals == [.recordingCompleted(RecordingEvent(frameCount: 1))], "recording signal")
}

func testBestRecordingKeepsShorterRun() {
    let system = ReplaySystem(); let source = StateStub()
    system.startRecording(context: ReplayContext(courseID: "best", startedAtTick: 0)); for i in 0..<10 { _ = system.captureTick(tick: UInt64(i), state: source) }; _ = system.stopRecording()
    system.startRecording(context: ReplayContext(courseID: "best", startedAtTick: 20)); for i in 0..<6 { _ = system.captureTick(tick: 20 + UInt64(i), state: source) }; _ = system.stopRecording()
    expect(system.bestRecording(for: "best")?.frameCount == 6, "shorter recording should become best")
    system.startRecording(context: ReplayContext(courseID: "best", startedAtTick: 40)); for i in 0..<8 { _ = system.captureTick(tick: 40 + UInt64(i), state: source) }; _ = system.stopRecording()
    expect(system.bestRecording(for: "best")?.frameCount == 6, "slower run must not replace best")
}

func testClearRecordingScopedAndAll() {
    let system = ReplaySystem(); let source = StateStub()
    for course in ["a", "b"] { system.startRecording(context: ReplayContext(courseID: course, startedAtTick: 0)); _ = system.captureTick(tick: 1, state: source); _ = system.stopRecording() }
    system.clearRecording(for: "a")
    expect(system.bestRecording(for: "a") == nil && system.bestRecording(for: "b") != nil, "scoped clear")
    system.clearRecording(for: nil); expect(system.bestRecording(for: "b") == nil, "global clear")
}

func testCloneExactFramePlayback() {
    let r = makeRecording(); let system = ReplaySystem(); let id = system.spawnClone(recording: r)
    for expectedIndex in 0..<r.frames.count {
        let s = system.stepClones()[0]; let f = r.frames[expectedIndex]
        expect(s.id == id && s.frameIndex == expectedIndex, "clone frame index")
        expect(s.position == f.position && s.velocity == f.velocity, "authoritative transform mismatch")
        expect(s.input == f.input && s.locomotionState == f.locomotionState, "authoritative state mismatch")
        expect(s.resources == f.resources && s.isAlive == f.isAlive, "resource/life mismatch")
    }
}

func testCloneLoopExactReset() {
    let r = makeRecording(frameCount: 4); let system = ReplaySystem(); _ = system.spawnClone(recording: r)
    var observed: [Int] = []; for _ in 0..<10 { observed.append(system.stepClones()[0].frameIndex) }
    expect(observed == [0,1,2,3,0,1,2,3,0,1], "loop sequence")
    expect(system.stepClones()[0].loopIndex >= 2, "loop counter")
}

func testNonLoopCloneFinishesAndHoldsLastFrame() {
    let r = makeRecording(frameCount: 3); let system = ReplaySystem(); let id = system.spawnClone(recording: r, options: CloneSpawnOptions(loops: false))
    _ = system.stepClones(); _ = system.stepClones(); _ = system.stepClones(); let held = system.stepClones()[0]
    expect(held.frameIndex == 2 && held.isFinished, "non-loop clone must hold last frame")
    expect(system.cloneSnapshot(id)?.position == r.frames[2].position, "finished clone snapshot")
}

func testMultipleClonesIndependentPhase() {
    let r = makeRecording(frameCount: 5); let system = ReplaySystem()
    let a = system.spawnClone(recording: r); let b = system.spawnClone(recording: r, options: CloneSpawnOptions(loops: true, startFrame: 2, phaseOffsetTicks: 2))
    let first = system.stepClones(); let sa = first.first { $0.id == a }!; let sb = first.first { $0.id == b }!
    expect(sa.frameIndex == 0 && sb.frameIndex == 2, "independent start frames")
    _ = system.stepClones(); let third = system.stepClones(); expect(third.first { $0.id == b }!.frameIndex == 2, "phase offset should delay advancement")
}

func testMarkersReplayEachLoop() {
    let r = makeRecording(); let system = ReplaySystem(); _ = system.spawnClone(recording: r)
    var cpCount = 0; var deathCount = 0
    for _ in 0..<(r.frameCount * 3) { let s = system.stepClones()[0]; if s.markers.contains(.checkpointReached("cp-1")) { cpCount += 1 }; if s.markers.contains(.playerDied(.hazard)) { deathCount += 1 } }
    expect(cpCount == 3 && deathCount == 3, "markers must replay once per loop")
}

func testDeathFrameDoesNotStopCloneLoop() {
    let r = makeRecording(); let system = ReplaySystem(); _ = system.spawnClone(recording: r)
    var sawDead = false; var sawAliveAfter = false
    for _ in 0..<(r.frameCount + 2) { let s = system.stepClones()[0]; if !s.isAlive { sawDead = true }; if sawDead && s.loopIndex > 0 && s.isAlive { sawAliveAfter = true } }
    expect(sawDead && sawAliveAfter, "clone death frame must reproduce then recover on loop")
}

func testCheckpointMarkerAlignedToFrame() {
    let r = makeRecording(); let m = r.markers.first { $0.kind == .checkpointReached("cp-1") }!
    expect(m.frameIndex == 2 && r.frames[m.frameIndex].tick == 102, "checkpoint marker alignment")
}

func testLongDurationLoopHasZeroDrift() {
    let r = makeRecording(frameCount: 7); let system = ReplaySystem(); _ = system.spawnClone(recording: r)
    let ticks = 200_000; var final: CloneSnapshot!; for _ in 0..<ticks { final = system.stepClones()[0] }
    let expected = (ticks - 1) % r.frameCount
    expect(final.frameIndex == expected, "long-run frame phase drift")
    expect(final.position == r.frames[expected].position && final.velocity == r.frames[expected].velocity, "long-run state drift")
}

func testCloneRemoval() {
    let r = makeRecording(); let system = ReplaySystem(); let a = system.spawnClone(recording: r); _ = system.spawnClone(recording: r)
    system.removeClone(a); expect(system.activeCloneCount == 1, "single remove")
    system.removeAllClones(); expect(system.activeCloneCount == 0 && system.stepClones().isEmpty, "remove all")
}

func testStartRecordingResetsPriorPartialRun() {
    let source = StateStub(); let system = ReplaySystem()
    system.startRecording(context: ReplayContext(courseID: "a", startedAtTick: 0)); _ = system.captureTick(tick: 1, state: source)
    system.startRecording(context: ReplayContext(courseID: "b", startedAtTick: 10)); _ = system.captureTick(tick: 10, state: source)
    let r = system.stopRecording()!; expect(r.context.courseID == "b" && r.frameCount == 1 && r.frames[0].tick == 10, "restart recording must discard partial prior run")
}

func testEmptyRecordingStopsSafely() {
    let system = ReplaySystem(); system.startRecording(context: ReplayContext(courseID: "empty", startedAtTick: 0)); expect(system.stopRecording() == nil, "empty recording should not produce playable replay")
}

func testUnsupportedVersionRejected() {
    let valid = makeRecording(frameCount: 2)
    do { _ = try ReplayRecording(version: 999, context: valid.context, frames: valid.frames); expect(false, "future version must reject") }
    catch let error as ReplayValidationError { expect(error == .unsupportedVersion(999), "wrong version error") }
    catch { expect(false, "unexpected error") }
}

func testMalformedTicksRejected() {
    let valid = makeRecording(frameCount: 2); let bad = [valid.frames[1], valid.frames[0]]
    do { _ = try ReplayRecording(context: valid.context, frames: bad); expect(false, "non-monotonic ticks must reject") }
    catch let error as ReplayValidationError { expect(error == .nonMonotonicTicks, "wrong monotonic error") }
    catch { expect(false, "unexpected error") }
}

func testStartFrameClampsSafely() {
    let r = makeRecording(frameCount: 3); let system = ReplaySystem(); _ = system.spawnClone(recording: r, options: CloneSpawnOptions(startFrame: 999)); expect(system.stepClones()[0].frameIndex == 2, "start frame must clamp")
}

func testInputAxisClamps() {
    expect(ReplayInputSample(moveAxis: 5).moveAxis == 1, "positive input clamp"); expect(ReplayInputSample(moveAxis: -5).moveAxis == -1, "negative input clamp")
}

func testMarkerBeforeCaptureAlignsSameTick() {
    let source = StateStub(); let system = ReplaySystem(); system.startRecording(context: ReplayContext(courseID: "ordering", startedAtTick: 40))
    expect(system.recordMarker(tick: 40, kind: .checkpointReached("early")), "early marker should buffer"); _ = system.captureTick(tick: 40, state: source)
    let r = system.stopRecording()!; expect(r.markers.count == 1 && r.markers[0].frameIndex == 0 && r.markers[0].tick == 40, "early marker alignment")
}

func testFinishedCloneDoesNotRepeatLastMarker() {
    let source = StateStub(); let system = ReplaySystem(); system.startRecording(context: ReplayContext(courseID: "finish-marker", startedAtTick: 1))
    _ = system.captureTick(tick: 1, state: source); _ = system.recordMarker(tick: 1, kind: .lapCompleted("finish-marker")); let r = system.stopRecording()!
    _ = system.spawnClone(recording: r, options: CloneSpawnOptions(loops: false)); let first = system.stepClones()[0]; let second = system.stepClones()[0]
    expect(first.markers == [.lapCompleted("finish-marker")], "terminal marker should emit once"); expect(second.markers.isEmpty && second.isFinished, "finished clone repeats marker")
}

func testManyClonesLongRunRemainPhaseCorrect() {
    let r = makeRecording(frameCount: 11); let system = ReplaySystem()
    for i in 0..<32 { _ = system.spawnClone(recording: r, options: CloneSpawnOptions(loops: true, startFrame: i % 11, phaseOffsetTicks: i % 4)) }
    for _ in 0..<20_000 { _ = system.stepClones() }
    expect(system.activeCloneCount == 32, "all long-running clones should remain active")
    let snapshots = system.stepClones(); expect(snapshots.count == 32, "all snapshots")
    for s in snapshots { expect(s.position == r.frames[s.frameIndex].position && s.velocity == r.frames[s.frameIndex].velocity, "multi-clone drift") }
}

func testFutureMarkerWithoutFrameIsDroppedSafely() {
    let source = StateStub(); let system = ReplaySystem(); system.startRecording(context: ReplayContext(courseID: "future-marker", startedAtTick: 1))
    _ = system.captureTick(tick: 1, state: source); _ = system.recordMarker(tick: 2, kind: .checkpointReached("never-captured")); let r = system.stopRecording()!
    expect(r.markers.isEmpty, "future marker must not attach to stale frame")
}

@main
struct TestMain {
    static func main() {
        testRecordingCapturesAuthoritativeStateAndInput(); testMonotonicTickGuard(); testRecordingCompletedSignal(); testBestRecordingKeepsShorterRun(); testClearRecordingScopedAndAll(); testCloneExactFramePlayback(); testCloneLoopExactReset(); testNonLoopCloneFinishesAndHoldsLastFrame(); testMultipleClonesIndependentPhase(); testMarkersReplayEachLoop(); testDeathFrameDoesNotStopCloneLoop(); testCheckpointMarkerAlignedToFrame(); testLongDurationLoopHasZeroDrift(); testCloneRemoval(); testStartRecordingResetsPriorPartialRun(); testEmptyRecordingStopsSafely(); testUnsupportedVersionRejected(); testMalformedTicksRejected(); testStartFrameClampsSafely(); testInputAxisClamps(); testMarkerBeforeCaptureAlignsSameTick(); testFinishedCloneDoesNotRepeatLastMarker(); testManyClonesLongRunRemainPhaseCorrect(); testFutureMarkerWithoutFrameIsDroppedSafely()
        print("PASS: 24 Next4 Replay/Clone test groups")
    }
}
