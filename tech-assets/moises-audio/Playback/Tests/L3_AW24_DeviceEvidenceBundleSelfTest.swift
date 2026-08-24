import Foundation

private let aw24HashA = String(repeating: "a", count: 64)
private let aw24HashB = String(repeating: "b", count: 64)
private let aw24BuildSHA = String(repeating: "c", count: 40)

private func aw24Case(
    _ scenario: Lane3DeviceEvidenceScenario,
    healthy: Bool = true,
    duration: Double? = nil,
    repetitions: Int? = nil
) -> Lane3DeviceEvidenceCaseReceipt {
    let reps = repetitions ?? (scenario == .longTrackStability ? 1 : (scenario == .interruptionRecovery ? 5 : 10))
    return Lane3DeviceEvidenceCaseReceipt(
        scenario: scenario,
        fixtureID: "fixture-\(scenario.rawValue)",
        controlSignatureFNV1A64: "1234abcd1234abcd",
        aw13RunBindingSHA256: aw24HashA,
        candidateCaptureSHA256: aw24HashA,
        currentMoisesCaptureSHA256: aw24HashB,
        repetitionsCompleted: reps,
        successfulRepetitions: reps,
        observedDurationSeconds: duration ?? (scenario == .longTrackStability ? 1_900 : 30),
        realAudio: true,
        rightsClearedFixture: true,
        currentMoisesCompared: true,
        timing: Lane3DeviceEvidenceTimingSummary(
            samples: max(1, reps),
            p50Milliseconds: 4,
            p95Milliseconds: 8,
            maxMilliseconds: 10
        ),
        health: Lane3DeviceEvidenceRuntimeHealth(
            unscopedBackendApplyCalls: healthy ? 0 : 1,
            unscopedClickInvalidationCalls: 0,
            telemetryCounterOverflowed: false,
            clickPopEvents: 0,
            desyncEvents: 0,
            underrunEvents: 0,
            nonFiniteSampleEvents: 0
        )
    )
}

private func aw24Reviews(
    for cases: [Lane3DeviceEvidenceCaseReceipt]
) -> [Lane3DeviceListeningReview] {
    cases.map {
        Lane3DeviceListeningReview(
            scenario: $0.scenario,
            caseBindingSHA256: $0.caseBindingSHA256,
            listeningPasses: 3,
            obviousInferiorityObserved: false,
            clickPopObserved: false,
            warbleInferiorityObserved: false,
            phasinessInferiorityObserved: false,
            formantDamageInferiorityObserved: false
        )
    }
}

private func aw24Bundle(
    cases: [Lane3DeviceEvidenceCaseReceipt],
    reviews: [Lane3DeviceListeningReview],
    route: Lane3DeviceEvidenceAudioRoute = .wiredHeadphones,
    privacy: Lane3DeviceEvidencePrivacySnapshot = Lane3DeviceEvidencePrivacySnapshot()
) -> Lane3DeviceEvidenceBundle {
    Lane3DeviceEvidenceBundle(
        appBuildCommitSHA: aw24BuildSHA,
        deviceModel: "iPhone17,1",
        osVersion: "iOS-test",
        audioRoute: route,
        physicalDevice: true,
        selectedXcodeBuild: true,
        currentMoisesReferenceSnapshotID: "moises-current-ios-snapshot",
        currentMoisesVersion: "reference-version",
        privacy: privacy,
        cases: cases,
        listeningReviews: reviews
    )
}

@main
struct L3AW24DeviceEvidenceBundleSelfTest {
    static func main() throws {
        let validCases = Lane3DeviceEvidenceScenario.allCases.map { aw24Case($0) }
        let validReviews = aw24Reviews(for: validCases)
        let valid = aw24Bundle(cases: validCases, reviews: validReviews)
        let validReport = Lane3DeviceEvidenceValidator.validate(valid)
        precondition(validReport.readyForHQParityReview)
        precondition(validReport.issues.isEmpty)
        precondition(!validReport.parityPromotionAllowed)

        let bluetooth = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: validCases, reviews: validReviews, route: .bluetoothA2DP)
        )
        precondition(bluetooth.issues.contains(
            Lane3DeviceEvidenceValidationIssue.timingRouteUnsupported
        ))

        let missingCases = Array(validCases.dropLast())
        let missingReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: missingCases, reviews: aw24Reviews(for: missingCases))
        )
        precondition(missingReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.missingScenario(.longTrackStability)
        ))

        let duplicateCases = validCases + [validCases[0]]
        let duplicateReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: duplicateCases, reviews: validReviews)
        )
        precondition(duplicateReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.duplicateScenario(.mixerGainRamp)
        ))

        var unhealthyCases = validCases
        unhealthyCases[3] = aw24Case(.pitch, healthy: false)
        let unhealthyReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: unhealthyCases, reviews: aw24Reviews(for: unhealthyCases))
        )
        precondition(unhealthyReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.runtimeHealthRejected(.pitch)
        ))

        var shortCases = validCases
        shortCases[7] = aw24Case(.longTrackStability, duration: 1_799)
        let shortReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: shortCases, reviews: aw24Reviews(for: shortCases))
        )
        precondition(shortReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.insufficientLongTrackDuration(observedSeconds: 1_799)
        ))

        let unsafePrivacy = Lane3DeviceEvidencePrivacySnapshot(deviceIdentifierCaptured: true)
        let privacyReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: validCases, reviews: validReviews, privacy: unsafePrivacy)
        )
        precondition(privacyReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.privacyBoundaryViolation
        ))

        var badReviews = validReviews
        badReviews[5] = Lane3DeviceListeningReview(
            scenario: .countIn,
            caseBindingSHA256: aw24HashB,
            listeningPasses: 3,
            obviousInferiorityObserved: false,
            clickPopObserved: false,
            warbleInferiorityObserved: false,
            phasinessInferiorityObserved: false,
            formantDamageInferiorityObserved: false
        )
        let bindingReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: validCases, reviews: badReviews)
        )
        precondition(bindingReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.listeningBindingMismatch(.countIn)
        ))

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encodedCase = try encoder.encode(validCases[2])
        var json = try JSONSerialization.jsonObject(with: encodedCase) as! [String: Any]
        json["successfulRepetitions"] = 9
        let tamperedData = try JSONSerialization.data(withJSONObject: json)
        let tampered = try decoder.decode(Lane3DeviceEvidenceCaseReceipt.self, from: tamperedData)
        var tamperedCases = validCases
        tamperedCases[2] = tampered
        let tamperedReport = Lane3DeviceEvidenceValidator.validate(
            aw24Bundle(cases: tamperedCases, reviews: aw24Reviews(for: tamperedCases))
        )
        precondition(tamperedReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.invalidFixtureBinding(.tempo)
        ))
        precondition(tamperedReport.issues.contains(
            Lane3DeviceEvidenceValidationIssue.unsuccessfulRepetitions(.tempo)
        ))

        let roundTrip = try decoder.decode(
            Lane3DeviceEvidenceBundle.self,
            from: encoder.encode(valid)
        )
        precondition(Lane3DeviceEvidenceValidator.validate(roundTrip).readyForHQParityReview)

        print("L3-AW24 device evidence bundle self-test PASS scenarios=\(validCases.count) issues=0")
    }
}
