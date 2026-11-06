import Foundation

@main
struct L3M04OfflineReferenceSelfTest {
    static func main() throws {
        let request = fixture()
        let first = try Lane3OfflineReferencePlanner.makePlan(request)
        let second = try Lane3OfflineReferencePlanner.makePlan(request)
        precondition(first == second)
        precondition(first.controlSignatureFNV1A64 == second.controlSignatureFNV1A64)
        precondition(first.evidenceScope == "LANE3_OFFLINE_CONTROL_REFERENCE_NON_PARITY")
        precondition(first.musicStartFrame == 96_000)
        precondition(first.outputFrameCount == 1_248_000)
        precondition(first.stemWindows.count == 3)
        precondition(first.events.filter { $0.kind == .countInClick }.map(\.frame) == [0, 24_000, 48_000, 72_000])
        precondition(first.events.filter { $0.kind == .metronomeClick }.map(\.frame).prefix(3) == [96_000, 120_000, 144_000])

        let expectedObservationEvents = first.events.filter { $0.kind != .practiceState }.map {
            Lane3ObservedRenderEvent(kind: $0.kind, frame: $0.frame + 1, stemID: $0.stemID)
        }
        let referenceSummary = try Lane3PCMAnalyzer.summarize(
            interleavedSamples: [0, 0.5, -0.5, 0.25, -0.25, 0],
            channels: 1,
            sampleRate: 48_000
        )
        let observation = Lane3ReferenceObservation(
            fixtureID: first.fixtureID,
            controlSignatureFNV1A64: first.controlSignatureFNV1A64,
            outputFrameCount: first.outputFrameCount + 1,
            events: expectedObservationEvents,
            audioSummary: referenceSummary,
            actualAudioCaptured: true
        )
        let pass = Lane3ReferenceComparator.compare(plan: first, observation: observation, referenceAudioSummary: referenceSummary)
        precondition(pass.passed)
        precondition(!pass.parityPromotionAllowed)

        var badEvents = expectedObservationEvents
        badEvents[0] = Lane3ObservedRenderEvent(kind: badEvents[0].kind, frame: badEvents[0].frame + 20, stemID: badEvents[0].stemID)
        let bad = Lane3ReferenceObservation(
            fixtureID: first.fixtureID,
            controlSignatureFNV1A64: "wrong",
            outputFrameCount: first.outputFrameCount + 50,
            events: badEvents,
            audioSummary: referenceSummary,
            actualAudioCaptured: true
        )
        let fail = Lane3ReferenceComparator.compare(plan: first, observation: bad, referenceAudioSummary: referenceSummary)
        precondition(!fail.passed)
        precondition(fail.blockers.contains("CONTROL_SIGNATURE_MISMATCH"))
        precondition(fail.blockers.contains("OUTPUT_DURATION_MISMATCH"))
        precondition(fail.blockers.contains("EVENT_TIMING_MISMATCH"))

        try assertThrows(.noStems) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "empty", stems: [], projectStartSeconds: 0, projectEndSeconds: 1,
                outputSampleRate: 48_000, practice: Lane3ReferencePracticeSettings()
            ))
        }
        try assertThrows(.invalidTempoRatio(0.01)) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "bad-tempo", stems: request.stems, projectStartSeconds: 0, projectEndSeconds: 1,
                outputSampleRate: 48_000, practice: Lane3ReferencePracticeSettings(tempoRatio: 0.01)
            ))
        }
        try assertThrows(.invalidPitchSemitones(25)) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "bad-pitch", stems: request.stems, projectStartSeconds: 0, projectEndSeconds: 1,
                outputSampleRate: 48_000, practice: Lane3ReferencePracticeSettings(pitchSemitones: 25)
            ))
        }
        try assertThrows(.duplicateStemID("vocals")) {
            var stems = request.stems
            stems.append(stems[0])
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: request.fixtureID,
                stems: stems,
                projectStartSeconds: request.projectStartSeconds,
                projectEndSeconds: request.projectEndSeconds,
                outputSampleRate: request.outputSampleRate,
                practice: request.practice,
                beatTimesSeconds: request.beatTimesSeconds,
                countInBeatIntervalSeconds: request.countInBeatIntervalSeconds
            ))
        }
        try assertThrows(.nonMonotonicBeatGrid) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "bad-beats",
                stems: request.stems,
                projectStartSeconds: 0,
                projectEndSeconds: 10,
                outputSampleRate: 48_000,
                practice: Lane3ReferencePracticeSettings(metronomeEnabled: true),
                beatTimesSeconds: [0, 0.5, 0.5]
            ))
        }
        try assertThrows(.duplicateRenderClickFrame(0)) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "same-frame",
                stems: request.stems,
                projectStartSeconds: 0,
                projectEndSeconds: 1,
                outputSampleRate: 8_000,
                practice: Lane3ReferencePracticeSettings(tempoRatio: 32, metronomeEnabled: true),
                beatTimesSeconds: [0, 0.00001]
            ))
        }
        try assertThrows(.missingCountInBeatInterval) {
            _ = try Lane3OfflineReferencePlanner.makePlan(Lane3ReferenceRenderRequest(
                fixtureID: "missing-countin-interval",
                stems: request.stems,
                projectStartSeconds: 0,
                projectEndSeconds: 5,
                outputSampleRate: 48_000,
                practice: Lane3ReferencePracticeSettings(countInClicks: 4)
            ))
        }
        try assertThrows(.invalidPCMConfiguration) {
            _ = try Lane3PCMAnalyzer.summarize(interleavedSamples: [0, 1, 0], channels: 2, sampleRate: 48_000)
        }

        var negativeEvents = expectedObservationEvents
        negativeEvents[0] = Lane3ObservedRenderEvent(kind: negativeEvents[0].kind, frame: Int64.min, stemID: negativeEvents[0].stemID)
        let negativeObservation = Lane3ReferenceObservation(
            fixtureID: first.fixtureID, controlSignatureFNV1A64: first.controlSignatureFNV1A64,
            outputFrameCount: Int64.min, events: negativeEvents, audioSummary: nil, actualAudioCaptured: false
        )
        let negativeResult = Lane3ReferenceComparator.compare(plan: first, observation: negativeObservation)
        precondition(!negativeResult.passed)
        precondition(negativeResult.blockers.contains("OUTPUT_DURATION_MISMATCH"))
        precondition(negativeResult.blockers.contains("EVENT_TIMING_MISMATCH"))

        let nonFinite = try Lane3PCMAnalyzer.summarize(interleavedSamples: [0, .nan, 0], channels: 1, sampleRate: 48_000)
        precondition(nonFinite.nonFiniteSampleCount == 1)
        let nonFiniteObservation = Lane3ReferenceObservation(
            fixtureID: first.fixtureID,
            controlSignatureFNV1A64: first.controlSignatureFNV1A64,
            outputFrameCount: first.outputFrameCount,
            events: first.events.filter { $0.kind != .practiceState }.map { Lane3ObservedRenderEvent(kind: $0.kind, frame: $0.frame, stemID: $0.stemID) },
            audioSummary: nonFinite,
            actualAudioCaptured: true
        )
        let nonFiniteResult = Lane3ReferenceComparator.compare(plan: first, observation: nonFiniteObservation, referenceAudioSummary: referenceSummary)
        precondition(nonFiniteResult.blockers.contains("NONFINITE_AUDIO_SAMPLES"))
        precondition(!nonFiniteResult.parityPromotionAllowed)

        let encoded = try Lane3ReferenceEvidenceEncoder.encodePlanJSON(first)
        precondition(!encoded.isEmpty)
        let template = Lane3ReferenceEvidenceEncoder.observationTemplate(for: first)
        precondition(!template.actualAudioCaptured)
        print("L3-M04 offline/reference self-test: PASS")
        print("signature=\(first.controlSignatureFNV1A64) events=\(first.events.count) windows=\(first.stemWindows.count)")
    }

    static func fixture() -> Lane3ReferenceRenderRequest {
        let stems = [
            Lane3ReferenceStemDescriptor(id: "vocals", startSeconds: 0, frameCount: 48_000 * 24, sampleRate: 48_000, gain: 1),
            Lane3ReferenceStemDescriptor(id: "drums", startSeconds: 2, frameCount: 44_100 * 20, sampleRate: 44_100, gain: 0.8),
            Lane3ReferenceStemDescriptor(id: "bass", startSeconds: 5, frameCount: 96_000 * 10, sampleRate: 96_000, gain: 0)
        ]
        return Lane3ReferenceRenderRequest(
            fixtureID: "L3-M04-SELFTEST",
            stems: stems,
            projectStartSeconds: 0,
            projectEndSeconds: 24,
            outputSampleRate: 48_000,
            practice: Lane3ReferencePracticeSettings(
                tempoRatio: 1,
                pitchSemitones: 3,
                metronomeEnabled: true,
                countInClicks: 4,
                downbeatStride: 4
            ),
            beatTimesSeconds: (0..<49).map { Double($0) * 0.5 },
            countInBeatIntervalSeconds: 0.5
        )
    }

    static func assertThrows(_ expected: Lane3OfflineRenderError, _ operation: () throws -> Void) throws {
        do {
            try operation()
            preconditionFailure("expected \(expected)")
        } catch let error as Lane3OfflineRenderError {
            precondition(error == expected, "expected \(expected), got \(error)")
        }
    }
}
