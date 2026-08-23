import Foundation
import XCTest

#if canImport(MoisesAudioCore)
import MoisesAudioCore
#endif

final class LibraryPersistencePolicyTests: XCTestCase {
    func testRelativePathPolicyRejectsTraversalAbsoluteEmptyAndEmptyComponents() throws {
        let invalid = ["", "/tmp/song.wav", "../song.wav", "Imports/../song.wav", "Imports//song.wav", "./song.wav"]
        for path in invalid {
            XCTAssertThrowsError(try LibraryPathPolicy.validate(relativePath: path), "expected rejection: \(path)")
        }
        XCTAssertNoThrow(try LibraryPathPolicy.validate(relativePath: "Imports/asset-1/song.wav"))
        XCTAssertNoThrow(try LibraryPathPolicy.validate(relativePath: "Stems/project-1/vocals.m4a"))
    }

    func testStemValidationRejectsCrossProjectAndDuplicateIDs() throws {
        let project = ProjectID()
        let other = ProjectID()
        let stemID = StemID()
        let good = StemArtifact(
            id: stemID,
            projectID: project,
            role: .vocals,
            relativePath: "Stems/p/vocals.m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 44_100,
            startTimeSeconds: 0
        )
        XCTAssertNoThrow(try LibrarySnapshotPolicy.validate(stems: [good], projectID: project))
        XCTAssertThrowsError(try LibrarySnapshotPolicy.validate(stems: [good, good], projectID: project))

        let foreign = StemArtifact(
            id: StemID(),
            projectID: other,
            role: .drums,
            relativePath: "Stems/other/drums.m4a",
            sampleRate: 44_100,
            channels: 2,
            frameCount: 44_100,
            startTimeSeconds: 0
        )
        XCTAssertThrowsError(try LibrarySnapshotPolicy.validate(stems: [foreign], projectID: project))
    }

    func testEditValidationRejectsDuplicateMixIdentity() throws {
        let stemID = StemID()
        let edits = ProjectUserEdits(
            schemaVersion: 1,
            tempoRatio: 1,
            pitchSemitones: 0,
            metronomeEnabled: false,
            countInClicks: 0,
            loopStartSeconds: nil,
            loopEndSeconds: nil,
            stemMix: [
                StemMixEdit(stemID: stemID, gain: 1, isMuted: false, isSoloed: false),
                StemMixEdit(stemID: stemID, gain: 0.5, isMuted: true, isSoloed: false)
            ]
        )
        XCTAssertThrowsError(try LibrarySnapshotPolicy.validate(edits: edits))
    }

    func testRecoveryPolicySeparatesResumeReadyCancelledAndFailed() throws {
        let job = ProcessingJobID()
        XCTAssertEqual(
            LibraryRecoveryPolicy.plan(for: ProcessingSnapshot(jobID: job, phase: .separating, fractionComplete: 0.4)),
            .resume(jobID: job)
        )
        XCTAssertEqual(
            LibraryRecoveryPolicy.plan(for: ProcessingSnapshot(jobID: job, phase: .ready, fractionComplete: 1)),
            .none
        )
        XCTAssertEqual(
            LibraryRecoveryPolicy.plan(for: ProcessingSnapshot(jobID: job, phase: .cancelled, fractionComplete: nil)),
            .retryRequired(stableErrorCode: "CANCELLED")
        )
        XCTAssertEqual(
            LibraryRecoveryPolicy.plan(for: ProcessingSnapshot(jobID: job, phase: .failed, fractionComplete: 0.7, retryable: true, stableErrorCode: "NETWORK_TIMEOUT")),
            .retryRequired(stableErrorCode: "NETWORK_TIMEOUT")
        )
    }

    func testSetlistNameNormalizationRejectsBlankAndTrimsWhitespace() throws {
        XCTAssertThrowsError(try LibraryNamePolicy.normalizedSetlistName("   \n"))
        XCTAssertEqual(try LibraryNamePolicy.normalizedSetlistName("  Practice  "), "Practice")
    }
}
