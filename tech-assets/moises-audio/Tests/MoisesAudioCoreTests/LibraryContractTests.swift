import Foundation
import XCTest
@testable import MoisesAudioCore

final class LibraryContractTests: XCTestCase {
    func testProjectUserEditsCodableRoundTripPreservesPracticeAndMixerState() throws {
        let stemID = StemID(rawValue: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!)
        let edits = ProjectUserEdits(
            schemaVersion: 1,
            tempoRatio: 0.85,
            pitchSemitones: -2,
            metronomeEnabled: true,
            countInClicks: 4,
            loopStartSeconds: 12.5,
            loopEndSeconds: 24.25,
            stemMix: [
                StemMixEdit(stemID: stemID, gain: 0.49, isMuted: false, isSoloed: true)
            ]
        )

        let data = try JSONEncoder().encode(edits)
        let decoded = try JSONDecoder().decode(ProjectUserEdits.self, from: data)

        XCTAssertEqual(decoded, edits)
    }

    func testPersistedProjectSnapshotCodableRoundTripPreservesProcessingAndArtifacts() throws {
        let projectID = ProjectID(rawValue: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!)
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!)
        let source = LocalAudioAsset(
            id: AssetID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!),
            relativePath: "imports/song.m4a",
            mediaKind: .audio,
            durationSeconds: 180
        )
        let processing = ProcessingSnapshot(
            jobID: jobID,
            phase: .separating,
            fractionComplete: 0.6,
            retryable: true,
            stableErrorCode: nil
        )
        let stems = [
            StemArtifact(
                id: StemID(rawValue: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!),
                projectID: projectID,
                role: .vocals,
                relativePath: "stems/vocals.m4a",
                sampleRate: 44_100,
                channels: 2,
                frameCount: 7_938_000
            )
        ]
        let snapshot = PersistedProjectSnapshot(
            projectID: projectID,
            source: source,
            processing: processing,
            stems: stems,
            edits: nil
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(PersistedProjectSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testSetlistSnapshotSortsEntriesByPosition() {
        let setlistID = SetlistID(rawValue: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!)
        let firstProject = ProjectID(rawValue: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!)
        let secondProject = ProjectID(rawValue: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!)
        let entries = [
            SetlistEntry(
                id: SetlistEntryID(rawValue: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!),
                projectID: secondProject,
                position: 1
            ),
            SetlistEntry(
                id: SetlistEntryID(rawValue: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!),
                projectID: firstProject,
                position: 0
            )
        ]

        let snapshot = SetlistSnapshot(id: setlistID, name: "Practice", entries: entries)

        XCTAssertEqual(snapshot.entries.map(\.projectID), [firstProject, secondProject])
        XCTAssertEqual(snapshot.entries.map(\.position), [0, 1])
    }

    func testProcessingRecoveryPlanCodableRoundTripPreservesAssociatedValues() throws {
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!)
        let plans: [ProcessingRecoveryPlan] = [
            .none,
            .resume(jobID: jobID),
            .retryRequired(stableErrorCode: "SEPARATION_BACKEND_TIMEOUT")
        ]

        for plan in plans {
            let data = try JSONEncoder().encode(plan)
            let decoded = try JSONDecoder().decode(ProcessingRecoveryPlan.self, from: data)
            XCTAssertEqual(decoded, plan)
        }
    }
}
