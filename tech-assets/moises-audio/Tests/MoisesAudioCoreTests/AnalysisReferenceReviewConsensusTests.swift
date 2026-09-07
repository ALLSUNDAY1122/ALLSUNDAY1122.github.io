import Foundation
import XCTest
@testable import MoisesAudioCore

final class AnalysisReferenceReviewConsensusTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_787_529_200)
    let manifestSHA = String(repeating: "a", count: 64)
    let artifactSHA = String(repeating: "b", count: 64)

    func row(_ fixture: String = "fixture-1", _ domain: String = "tempo") -> AnalysisReferenceCaptureRow {
        .init(fixtureID: fixture, rightsClass: .licensedTest, genre: "rock", durationSeconds: 10, syntheticOnly: false, domain: domain, qualityMetrics: domain == "tempo" ? ["decision_emitted":1,"tempo_rel_error":0,"exact_within_4pct":1,"octave_aware_within_4pct":1] : ["exact_key_accuracy":1], evidenceArtifactIDs: ["evidence"])
    }
    func capture(_ rows: [AnalysisReferenceCaptureRow]? = nil) -> AnalysisReferenceCaptureSet {
        let env = AnalysisReferenceCaptureEnvironment(productName: "Moises: The Musician's App", appVersion: "9.9.9", buildVersion: "999", deviceModel: "iPhone16,1", osVersion: "19.0", locale: "ja_JP", accountTier: "PREMIUM")
        let run = AnalysisReferenceCaptureRun(runID: "run-1", operatorID: "capture-operator", capturedAt: now.addingTimeInterval(-60), environment: env, sourceBinding: .init(manifestID: "golden-v1", manifestSHA256: manifestSHA), observationMethod: .screenRecordingReview, artifacts: [.init(artifactID: "evidence", sha256: artifactSHA, mediaType: "video/mp4")], rows: rows ?? [row()])
        return .init(captureSetID: "capture-1", createdAt: now.addingTimeInterval(-60), runs: [run])
    }
    func policy(_ rules: [AnalysisReferenceReviewConsensusRule]? = nil) -> AnalysisReferenceReviewConsensusPolicy {
        .init(policyID: "p", authority: "HQ_LATE_INTEGRATION", approvalReference: "HQ-W21", minimumIndependentReviewers: 2, reviewersMustDifferFromCaptureOperator: true, rules: rules ?? [
            .init(spreadClass: .tempoBPM, maximumAbsoluteSpread: 0.1), .init(spreadClass: .beatTimestampSeconds, maximumAbsoluteSpread: 0.03), .init(spreadClass: .chordBoundarySeconds, maximumAbsoluteSpread: 0.05), .init(spreadClass: .sectionBoundarySeconds, maximumAbsoluteSpread: 0.1), .init(spreadClass: .anchorTimeSeconds, maximumAbsoluteSpread: 0.1), .init(spreadClass: .anchorFrameIndex, maximumAbsoluteSpread: 2), .init(spreadClass: .anchorRegionCoordinate, maximumAbsoluteSpread: 0.02)
        ])
    }
    func anchor(_ path: String, shift: Double = 0) -> AnalysisReferenceFieldEvidenceAnchor { .init(fieldPath: path, artifactID: "evidence", kind: .timeRangeSeconds, startSeconds: 1 + shift, endSeconds: 1.05 + shift) }
    func tempo(_ bpm: Double? = 120, _ status: AnalysisReferenceRawObservationStatus = .observed) -> AnalysisReferenceRawObservation { .init(runID: "run-1", fixtureID: "fixture-1", domain: "tempo", status: status, evidenceArtifactIDs: ["evidence"], observedBPM: status == .observed ? bpm : nil) }
    func sub(_ reviewer: String, _ obs: AnalysisReferenceRawObservation, _ c: Character, session: String? = nil, anchors: [AnalysisReferenceFieldEvidenceAnchor]? = nil, time: Date? = nil) -> AnalysisReferenceReviewSubmission {
        let a = anchors ?? (obs.status == .observed && obs.domain == "tempo" ? [anchor("status"), anchor("observed_bpm")] : [anchor("status")])
        return .init(submissionID: "s-\(reviewer)-\(UUID())", reviewerID: reviewer, reviewSessionID: session ?? "session-\(reviewer)", reviewRecordSHA256: String(repeating: String(c), count: 64), submittedAt: time ?? now, observation: obs, anchors: a)
    }
    func set(_ submissions: [AnalysisReferenceReviewSubmission], sha: String? = nil) -> AnalysisReferenceReviewSet { .init(reviewSetID: "rs", captureSetID: "capture-1", sourceManifestID: "golden-v1", sourceManifestSHA256: sha ?? manifestSHA, submissions: submissions) }
    func resolve(_ submissions: [AnalysisReferenceReviewSubmission], cap: AnalysisReferenceCaptureSet? = nil, pol: AnalysisReferenceReviewConsensusPolicy? = nil) -> AnalysisReferenceReviewConsensusReport { AnalysisReferenceReviewConsensusEngine.resolve(reviewSet: set(submissions), captureSet: cap ?? capture(), policy: pol ?? policy(), evaluatedAt: now) }

    func testStableIndependentTempoUsesMedian() {
        let r = resolve([sub("a", tempo(120), "c"), sub("b", tempo(120.04), "d")])
        XCTAssertTrue(r.consensusReady); XCTAssertEqual(r.status, .resolvedPendingW20); XCTAssertEqual(r.consensusRawObservationSet.observations[0].observedBPM!, 120.02, accuracy: 1e-12)
    }
    func testOneReviewerAndDuplicateReviewerFail() {
        let one = resolve([sub("a", tempo(), "c")]); XCTAssertTrue(one.issues.contains{$0.code == .insufficientIndependentReviewers})
        let dup = resolve([sub("a", tempo(), "c", session:"s1"), sub("a", tempo(), "d", session:"s2")]); XCTAssertTrue(dup.issues.contains{$0.code == .duplicateReviewer}); XCTAssertFalse(dup.consensusReady)
    }
    func testCopiedSignalsFail() {
        let session = resolve([sub("a",tempo(),"c",session:"same"), sub("b",tempo(),"d",session:"same")]); XCTAssertTrue(session.issues.contains{$0.code == .suspectedCopiedSubmission})
        let record = resolve([sub("a",tempo(),"e"), sub("b",tempo(),"e")]); XCTAssertTrue(record.issues.contains{$0.code == .suspectedCopiedSubmission})
    }
    func testMissingAndDisagreeingAnchorsFailClosed() {
        let onlyStatus = [anchor("status")]
        let missing = resolve([sub("a",tempo(),"c",anchors:onlyStatus), sub("b",tempo(),"d",anchors:onlyStatus)]); XCTAssertTrue(missing.issues.contains{$0.code == .missingAnchor && $0.fieldPath == "observed_bpm"})
        let disagree = resolve([sub("a",tempo(),"c",anchors:[anchor("status"),anchor("observed_bpm")]), sub("b",tempo(),"d",anchors:[anchor("status"),anchor("observed_bpm",shift:1)])]); XCTAssertTrue(disagree.issues.contains{$0.code == .anchorDisagreement}); XCTAssertEqual(disagree.consensusRawObservationSet.observations[0].status,.unscorable)
    }
    func testOutOfToleranceValueBecomesUnscorable() {
        let r = resolve([sub("a",tempo(120),"c"),sub("b",tempo(125),"d")]); XCTAssertTrue(r.issues.contains{$0.code == .valueDisagreement}); XCTAssertEqual(r.consensusRawObservationSet.observations[0].status,.unscorable); XCTAssertNil(r.consensusRawObservationSet.observations[0].observedBPM)
    }
    func testKeyExactAgreementRequired() {
        let cap = capture([row("fixture-key","key")]); let anchors = [anchor("status"),anchor("key.tonic_pitch_class"),anchor("key.mode")]
        let a = AnalysisReferenceRawObservation(runID:"run-1",fixtureID:"fixture-key",domain:"key",status:.observed,evidenceArtifactIDs:["evidence"],key:.init(tonicPitchClass:0,mode:"major"))
        let b = AnalysisReferenceRawObservation(runID:"run-1",fixtureID:"fixture-key",domain:"key",status:.observed,evidenceArtifactIDs:["evidence"],key:.init(tonicPitchClass:9,mode:"minor"))
        let r = AnalysisReferenceReviewConsensusEngine.resolve(reviewSet:set([sub("a",a,"c",anchors:anchors),sub("b",b,"d",anchors:anchors)]),captureSet:cap,policy:policy(),evaluatedAt:now); XCTAssertTrue(r.issues.contains{$0.code == .valueDisagreement}); XCTAssertEqual(r.consensusRawObservationSet.observations[0].status,.unscorable)
    }
    func testChordBoundaryToleranceAndExactLabel() {
        let cap = capture([row("fixture-chord","chord")]); let anchors=[anchor("status"),anchor("chords[0].start_seconds"),anchor("chords[0].end_seconds"),anchor("chords[0].normalized_label")]
        let a = AnalysisReferenceRawObservation(runID:"run-1",fixtureID:"fixture-chord",domain:"chord",status:.observed,evidenceArtifactIDs:["evidence"],chords:[.init(startSeconds:0,endSeconds:5,normalizedLabel:"C:maj")])
        let b = AnalysisReferenceRawObservation(runID:"run-1",fixtureID:"fixture-chord",domain:"chord",status:.observed,evidenceArtifactIDs:["evidence"],chords:[.init(startSeconds:0.02,endSeconds:5.02,normalizedLabel:"C:maj")])
        let ok = AnalysisReferenceReviewConsensusEngine.resolve(reviewSet:set([sub("a",a,"c",anchors:anchors),sub("b",b,"d",anchors:anchors)]),captureSet:cap,policy:policy(),evaluatedAt:now); XCTAssertTrue(ok.consensusReady); XCTAssertEqual(ok.consensusRawObservationSet.observations[0].chords![0].startSeconds,0.01,accuracy:1e-12)
    }
    func testNoDecisionPreserved() { let o=tempo(nil,.noDecision); let r=resolve([sub("a",o,"c"),sub("b",o,"d")]); XCTAssertTrue(r.consensusReady); XCTAssertEqual(r.consensusRawObservationSet.observations[0].status,.noDecision); XCTAssertNil(r.consensusRawObservationSet.observations[0].observedBPM) }
    func testFrameAndPageAnchorsWorkInsideExternalRules() {
        let a:[AnalysisReferenceFieldEvidenceAnchor]=[.init(fieldPath:"status",artifactID:"evidence",kind:.frameRange,startFrame:100,endFrame:105),.init(fieldPath:"observed_bpm",artifactID:"evidence",kind:.pageRegion,pageIndex:0,region:.init(x:0.1,y:0.1,width:0.2,height:0.1))]
        let b:[AnalysisReferenceFieldEvidenceAnchor]=[.init(fieldPath:"status",artifactID:"evidence",kind:.frameRange,startFrame:101,endFrame:106),.init(fieldPath:"observed_bpm",artifactID:"evidence",kind:.pageRegion,pageIndex:0,region:.init(x:0.11,y:0.1,width:0.2,height:0.1))]
        XCTAssertTrue(resolve([sub("a",tempo(),"c",anchors:a),sub("b",tempo(),"d",anchors:b)]).consensusReady)
    }
    func testOperatorSelfReviewAndBadTimestampsFail() {
        let selfReview=resolve([sub("capture-operator",tempo(),"c"),sub("b",tempo(),"d")]); XCTAssertTrue(selfReview.issues.contains{$0.code == .reviewerMatchesCaptureOperator})
        let time=resolve([sub("a",tempo(),"c",time:now.addingTimeInterval(-120)),sub("b",tempo(),"d",time:now.addingTimeInterval(10))]); XCTAssertEqual(time.issues.filter{$0.code == .invalidReviewTimestamp}.count,2)
    }
    func testDuplicatePolicyRulesAndSourceMismatchFailWithoutTrap() {
        let p=policy([.init(spreadClass:.tempoBPM,maximumAbsoluteSpread:0.1),.init(spreadClass:.tempoBPM,maximumAbsoluteSpread:0.2)]); XCTAssertTrue(resolve([sub("a",tempo(),"c"),sub("b",tempo(),"d")],pol:p).issues.contains{$0.code == .invalidPolicy})
        let bad=AnalysisReferenceReviewConsensusEngine.resolve(reviewSet:set([sub("a",tempo(),"c"),sub("b",tempo(),"d")],sha:String(repeating:"f",count:64)),captureSet:capture(),policy:policy(),evaluatedAt:now); XCTAssertTrue(bad.issues.contains{$0.code == .sourceBindingMismatch})
    }
    func testCodecRoundTripDeterministic() throws {
        let s=set([sub("a",tempo(),"c"),sub("b",tempo(),"d")]); let r=AnalysisReferenceReviewConsensusEngine.resolve(reviewSet:s,captureSet:capture(),policy:policy(),evaluatedAt:now)
        let d1=try AnalysisReferenceReviewConsensusCodec.encodeReviewSet(s), d2=try AnalysisReferenceReviewConsensusCodec.encodeReviewSet(s); XCTAssertEqual(d1,d2); XCTAssertEqual(try AnalysisReferenceReviewConsensusCodec.decodeReviewSet(d1),s)
        let pd=try AnalysisReferenceReviewConsensusCodec.encodePolicy(policy()); XCTAssertEqual(try AnalysisReferenceReviewConsensusCodec.decodePolicy(pd),policy()); let rd=try AnalysisReferenceReviewConsensusCodec.encodeReport(r); XCTAssertEqual(try AnalysisReferenceReviewConsensusCodec.decodeReport(rd),r)
    }
}
