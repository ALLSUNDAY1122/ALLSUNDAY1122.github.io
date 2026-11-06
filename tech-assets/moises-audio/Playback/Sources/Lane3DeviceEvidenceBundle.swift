import Foundation

public enum Lane3DeviceEvidenceScenario: String, Codable, Sendable, CaseIterable, Hashable {
    case mixerGainRamp
    case seekLoop
    case tempo
    case pitch
    case metronome
    case countIn
    case interruptionRecovery
    case longTrackStability
}

public enum Lane3DeviceEvidenceAudioRoute: String, Codable, Sendable {
    case builtInSpeaker
    case wiredHeadphones
    case usbAudio
    case bluetoothA2DP

    var supportsTimingEvidence: Bool {
        switch self {
        case .builtInSpeaker, .wiredHeadphones, .usbAudio: return true
        case .bluetoothA2DP: return false
        }
    }
}

public struct Lane3DeviceEvidencePrivacySnapshot: Codable, Equatable, Sendable {
    public let rawAudioEmbeddedInManifest: Bool
    public let rawPCMEmbeddedInManifest: Bool
    public let filePathCaptured: Bool
    public let projectIdentifierCaptured: Bool
    public let deviceIdentifierCaptured: Bool
    public let individualGenerationOrTicketCaptured: Bool

    public init(
        rawAudioEmbeddedInManifest: Bool = false,
        rawPCMEmbeddedInManifest: Bool = false,
        filePathCaptured: Bool = false,
        projectIdentifierCaptured: Bool = false,
        deviceIdentifierCaptured: Bool = false,
        individualGenerationOrTicketCaptured: Bool = false
    ) {
        self.rawAudioEmbeddedInManifest = rawAudioEmbeddedInManifest
        self.rawPCMEmbeddedInManifest = rawPCMEmbeddedInManifest
        self.filePathCaptured = filePathCaptured
        self.projectIdentifierCaptured = projectIdentifierCaptured
        self.deviceIdentifierCaptured = deviceIdentifierCaptured
        self.individualGenerationOrTicketCaptured = individualGenerationOrTicketCaptured
    }

    var isSafe: Bool {
        !rawAudioEmbeddedInManifest && !rawPCMEmbeddedInManifest && !filePathCaptured
            && !projectIdentifierCaptured && !deviceIdentifierCaptured
            && !individualGenerationOrTicketCaptured
    }
}

public struct Lane3DeviceEvidenceTimingSummary: Codable, Equatable, Sendable {
    public let samples: Int
    public let p50Milliseconds: Double
    public let p95Milliseconds: Double
    public let maxMilliseconds: Double

    public init(samples: Int, p50Milliseconds: Double, p95Milliseconds: Double, maxMilliseconds: Double) {
        self.samples = samples
        self.p50Milliseconds = p50Milliseconds
        self.p95Milliseconds = p95Milliseconds
        self.maxMilliseconds = maxMilliseconds
    }

    var isValid: Bool {
        samples > 0
            && p50Milliseconds.isFinite && p50Milliseconds >= 0
            && p95Milliseconds.isFinite && p95Milliseconds >= p50Milliseconds
            && maxMilliseconds.isFinite && maxMilliseconds >= p95Milliseconds
    }
}

public struct Lane3DeviceEvidenceRuntimeHealth: Codable, Equatable, Sendable {
    public let unscopedBackendApplyCalls: UInt64
    public let unscopedClickInvalidationCalls: UInt64
    public let telemetryCounterOverflowed: Bool
    public let clickPopEvents: Int
    public let desyncEvents: Int
    public let underrunEvents: Int
    public let nonFiniteSampleEvents: Int

    public init(
        unscopedBackendApplyCalls: UInt64,
        unscopedClickInvalidationCalls: UInt64,
        telemetryCounterOverflowed: Bool,
        clickPopEvents: Int,
        desyncEvents: Int,
        underrunEvents: Int,
        nonFiniteSampleEvents: Int
    ) {
        self.unscopedBackendApplyCalls = unscopedBackendApplyCalls
        self.unscopedClickInvalidationCalls = unscopedClickInvalidationCalls
        self.telemetryCounterOverflowed = telemetryCounterOverflowed
        self.clickPopEvents = clickPopEvents
        self.desyncEvents = desyncEvents
        self.underrunEvents = underrunEvents
        self.nonFiniteSampleEvents = nonFiniteSampleEvents
    }

    var isValidForReview: Bool {
        unscopedBackendApplyCalls == 0 && unscopedClickInvalidationCalls == 0
            && !telemetryCounterOverflowed
            && clickPopEvents == 0 && desyncEvents == 0 && underrunEvents == 0
            && nonFiniteSampleEvents == 0
    }
}

public struct Lane3DeviceEvidenceCaseReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let scenario: Lane3DeviceEvidenceScenario
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let aw13RunBindingSHA256: String
    public let candidateCaptureSHA256: String
    public let currentMoisesCaptureSHA256: String
    public let repetitionsCompleted: Int
    public let successfulRepetitions: Int
    public let observedDurationSeconds: Double
    public let realAudio: Bool
    public let rightsClearedFixture: Bool
    public let currentMoisesCompared: Bool
    public let timing: Lane3DeviceEvidenceTimingSummary
    public let health: Lane3DeviceEvidenceRuntimeHealth
    public let caseBindingSHA256: String
    public let parityPromotionAllowed: Bool

    public init(
        scenario: Lane3DeviceEvidenceScenario,
        fixtureID: String,
        controlSignatureFNV1A64: String,
        aw13RunBindingSHA256: String,
        candidateCaptureSHA256: String,
        currentMoisesCaptureSHA256: String,
        repetitionsCompleted: Int,
        successfulRepetitions: Int,
        observedDurationSeconds: Double,
        realAudio: Bool,
        rightsClearedFixture: Bool,
        currentMoisesCompared: Bool,
        timing: Lane3DeviceEvidenceTimingSummary,
        health: Lane3DeviceEvidenceRuntimeHealth
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW24_DEVICE_CASE_NON_PARITY"
        self.scenario = scenario
        self.fixtureID = fixtureID
        self.controlSignatureFNV1A64 = controlSignatureFNV1A64
        self.aw13RunBindingSHA256 = aw13RunBindingSHA256
        self.candidateCaptureSHA256 = candidateCaptureSHA256
        self.currentMoisesCaptureSHA256 = currentMoisesCaptureSHA256
        self.repetitionsCompleted = repetitionsCompleted
        self.successfulRepetitions = successfulRepetitions
        self.observedDurationSeconds = observedDurationSeconds
        self.realAudio = realAudio
        self.rightsClearedFixture = rightsClearedFixture
        self.currentMoisesCompared = currentMoisesCompared
        self.timing = timing
        self.health = health
        self.caseBindingSHA256 = Self.computeBinding(
            scenario: scenario,
            fixtureID: fixtureID,
            controlSignatureFNV1A64: controlSignatureFNV1A64,
            aw13RunBindingSHA256: aw13RunBindingSHA256,
            candidateCaptureSHA256: candidateCaptureSHA256,
            currentMoisesCaptureSHA256: currentMoisesCaptureSHA256,
            repetitionsCompleted: repetitionsCompleted,
            successfulRepetitions: successfulRepetitions,
            observedDurationSeconds: observedDurationSeconds,
            realAudio: realAudio,
            rightsClearedFixture: rightsClearedFixture,
            currentMoisesCompared: currentMoisesCompared,
            timing: timing,
            health: health
        )
        self.parityPromotionAllowed = false
    }

    public func recomputedBindingSHA256() -> String {
        Self.computeBinding(
            scenario: scenario,
            fixtureID: fixtureID,
            controlSignatureFNV1A64: controlSignatureFNV1A64,
            aw13RunBindingSHA256: aw13RunBindingSHA256,
            candidateCaptureSHA256: candidateCaptureSHA256,
            currentMoisesCaptureSHA256: currentMoisesCaptureSHA256,
            repetitionsCompleted: repetitionsCompleted,
            successfulRepetitions: successfulRepetitions,
            observedDurationSeconds: observedDurationSeconds,
            realAudio: realAudio,
            rightsClearedFixture: rightsClearedFixture,
            currentMoisesCompared: currentMoisesCompared,
            timing: timing,
            health: health
        )
    }

    private static func computeBinding(
        scenario: Lane3DeviceEvidenceScenario,
        fixtureID: String,
        controlSignatureFNV1A64: String,
        aw13RunBindingSHA256: String,
        candidateCaptureSHA256: String,
        currentMoisesCaptureSHA256: String,
        repetitionsCompleted: Int,
        successfulRepetitions: Int,
        observedDurationSeconds: Double,
        realAudio: Bool,
        rightsClearedFixture: Bool,
        currentMoisesCompared: Bool,
        timing: Lane3DeviceEvidenceTimingSummary,
        health: Lane3DeviceEvidenceRuntimeHealth
    ) -> String {
        Lane3AW24SHA256.digest(fields: [
            "LANE3_AW24_DEVICE_CASE_V1",
            scenario.rawValue,
            fixtureID,
            controlSignatureFNV1A64,
            aw13RunBindingSHA256,
            candidateCaptureSHA256,
            currentMoisesCaptureSHA256,
            String(repetitionsCompleted),
            String(successfulRepetitions),
            String(observedDurationSeconds.bitPattern),
            String(realAudio),
            String(rightsClearedFixture),
            String(currentMoisesCompared),
            String(timing.samples),
            String(timing.p50Milliseconds.bitPattern),
            String(timing.p95Milliseconds.bitPattern),
            String(timing.maxMilliseconds.bitPattern),
            String(health.unscopedBackendApplyCalls),
            String(health.unscopedClickInvalidationCalls),
            String(health.telemetryCounterOverflowed),
            String(health.clickPopEvents),
            String(health.desyncEvents),
            String(health.underrunEvents),
            String(health.nonFiniteSampleEvents)
        ])
    }
}

public struct Lane3DeviceListeningReview: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let scenario: Lane3DeviceEvidenceScenario
    public let caseBindingSHA256: String
    public let listeningPasses: Int
    public let obviousInferiorityObserved: Bool
    public let clickPopObserved: Bool
    public let warbleInferiorityObserved: Bool
    public let phasinessInferiorityObserved: Bool
    public let formantDamageInferiorityObserved: Bool
    public let parityPromotionAllowed: Bool

    public init(
        scenario: Lane3DeviceEvidenceScenario,
        caseBindingSHA256: String,
        listeningPasses: Int,
        obviousInferiorityObserved: Bool,
        clickPopObserved: Bool,
        warbleInferiorityObserved: Bool,
        phasinessInferiorityObserved: Bool,
        formantDamageInferiorityObserved: Bool
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW24_LISTENING_REVIEW_NON_PARITY"
        self.scenario = scenario
        self.caseBindingSHA256 = caseBindingSHA256
        self.listeningPasses = listeningPasses
        self.obviousInferiorityObserved = obviousInferiorityObserved
        self.clickPopObserved = clickPopObserved
        self.warbleInferiorityObserved = warbleInferiorityObserved
        self.phasinessInferiorityObserved = phasinessInferiorityObserved
        self.formantDamageInferiorityObserved = formantDamageInferiorityObserved
        self.parityPromotionAllowed = false
    }

    var isCompleteAndNonInferior: Bool {
        listeningPasses >= 3
            && !obviousInferiorityObserved
            && !clickPopObserved
            && !warbleInferiorityObserved
            && !phasinessInferiorityObserved
            && !formantDamageInferiorityObserved
            && !parityPromotionAllowed
    }
}

public struct Lane3DeviceEvidenceBundle: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let appBuildCommitSHA: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let physicalDevice: Bool
    public let selectedXcodeBuild: Bool
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let privacy: Lane3DeviceEvidencePrivacySnapshot
    public let cases: [Lane3DeviceEvidenceCaseReceipt]
    public let listeningReviews: [Lane3DeviceListeningReview]
    public let parityPromotionAllowed: Bool

    public init(
        appBuildCommitSHA: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        physicalDevice: Bool,
        selectedXcodeBuild: Bool,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        privacy: Lane3DeviceEvidencePrivacySnapshot = Lane3DeviceEvidencePrivacySnapshot(),
        cases: [Lane3DeviceEvidenceCaseReceipt],
        listeningReviews: [Lane3DeviceListeningReview]
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW24_DEVICE_EVIDENCE_BUNDLE_NON_PARITY"
        self.appBuildCommitSHA = appBuildCommitSHA
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.audioRoute = audioRoute
        self.physicalDevice = physicalDevice
        self.selectedXcodeBuild = selectedXcodeBuild
        self.currentMoisesReferenceSnapshotID = currentMoisesReferenceSnapshotID
        self.currentMoisesVersion = currentMoisesVersion
        self.privacy = privacy
        self.cases = cases
        self.listeningReviews = listeningReviews
        self.parityPromotionAllowed = false
    }
}

public enum Lane3DeviceEvidenceValidationIssue: Equatable, Sendable {
    case invalidBundleEnvelope
    case invalidBuildCommitSHA
    case invalidDeviceMetadata
    case timingRouteUnsupported
    case privacyBoundaryViolation
    case missingScenario(Lane3DeviceEvidenceScenario)
    case duplicateScenario(Lane3DeviceEvidenceScenario)
    case invalidCaseEnvelope(Lane3DeviceEvidenceScenario)
    case invalidFixtureBinding(Lane3DeviceEvidenceScenario)
    case invalidCaptureDigest(Lane3DeviceEvidenceScenario)
    case insufficientRepetitions(Lane3DeviceEvidenceScenario, required: Int, observed: Int)
    case unsuccessfulRepetitions(Lane3DeviceEvidenceScenario)
    case insufficientLongTrackDuration(observedSeconds: Double)
    case invalidTimingSummary(Lane3DeviceEvidenceScenario)
    case runtimeHealthRejected(Lane3DeviceEvidenceScenario)
    case missingListeningReview(Lane3DeviceEvidenceScenario)
    case duplicateListeningReview(Lane3DeviceEvidenceScenario)
    case listeningBindingMismatch(Lane3DeviceEvidenceScenario)
    case listeningReviewRejected(Lane3DeviceEvidenceScenario)
}

public struct Lane3DeviceEvidenceValidationReport: Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let issues: [Lane3DeviceEvidenceValidationIssue]
    public let readyForHQParityReview: Bool
    public let parityPromotionAllowed: Bool

    public init(issues: [Lane3DeviceEvidenceValidationIssue]) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_AW24_DEVICE_EVIDENCE_VALIDATION_NON_PARITY"
        self.issues = issues
        self.readyForHQParityReview = issues.isEmpty
        self.parityPromotionAllowed = false
    }
}

public enum Lane3DeviceEvidenceValidator {
    public static func validate(_ bundle: Lane3DeviceEvidenceBundle) -> Lane3DeviceEvidenceValidationReport {
        var issues: [Lane3DeviceEvidenceValidationIssue] = []

        if bundle.schemaVersion != 1
            || bundle.evidenceScope != "LANE3_AW24_DEVICE_EVIDENCE_BUNDLE_NON_PARITY"
            || bundle.parityPromotionAllowed {
            issues.append(.invalidBundleEnvelope)
        }
        if !isHex(bundle.appBuildCommitSHA, length: 40) { issues.append(.invalidBuildCommitSHA) }
        if bundle.deviceModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || bundle.osVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || bundle.currentMoisesReferenceSnapshotID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || bundle.currentMoisesVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bundle.physicalDevice || !bundle.selectedXcodeBuild {
            issues.append(.invalidDeviceMetadata)
        }
        if !bundle.audioRoute.supportsTimingEvidence { issues.append(.timingRouteUnsupported) }
        if !bundle.privacy.isSafe { issues.append(.privacyBoundaryViolation) }

        let caseGroups = Dictionary(grouping: bundle.cases, by: \.scenario)
        for scenario in Lane3DeviceEvidenceScenario.allCases {
            guard let group = caseGroups[scenario], !group.isEmpty else {
                issues.append(.missingScenario(scenario)); continue
            }
            if group.count != 1 {
                issues.append(.duplicateScenario(scenario)); continue
            }
            validateCase(group[0], issues: &issues)
        }

        let reviewGroups = Dictionary(grouping: bundle.listeningReviews, by: \.scenario)
        for scenario in Lane3DeviceEvidenceScenario.allCases {
            guard let group = reviewGroups[scenario], !group.isEmpty else {
                issues.append(.missingListeningReview(scenario)); continue
            }
            if group.count != 1 {
                issues.append(.duplicateListeningReview(scenario)); continue
            }
            guard let evidenceCase = caseGroups[scenario]?.first else { continue }
            let review = group[0]
            if review.schemaVersion != 1
                || review.evidenceScope != "LANE3_AW24_LISTENING_REVIEW_NON_PARITY"
                || review.parityPromotionAllowed {
                issues.append(.listeningReviewRejected(scenario)); continue
            }
            if review.caseBindingSHA256 != evidenceCase.caseBindingSHA256 {
                issues.append(.listeningBindingMismatch(scenario))
            }
            if !review.isCompleteAndNonInferior {
                issues.append(.listeningReviewRejected(scenario))
            }
        }
        return Lane3DeviceEvidenceValidationReport(issues: issues)
    }

    private static func validateCase(
        _ receipt: Lane3DeviceEvidenceCaseReceipt,
        issues: inout [Lane3DeviceEvidenceValidationIssue]
    ) {
        let scenario = receipt.scenario
        if receipt.schemaVersion != 1
            || receipt.evidenceScope != "LANE3_AW24_DEVICE_CASE_NON_PARITY"
            || receipt.parityPromotionAllowed
            || !receipt.realAudio || !receipt.rightsClearedFixture || !receipt.currentMoisesCompared {
            issues.append(.invalidCaseEnvelope(scenario))
        }
        if receipt.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !isHex(receipt.controlSignatureFNV1A64, length: 16)
            || !isHex(receipt.aw13RunBindingSHA256, length: 64)
            || receipt.caseBindingSHA256 != receipt.recomputedBindingSHA256() {
            issues.append(.invalidFixtureBinding(scenario))
        }
        if !isHex(receipt.candidateCaptureSHA256, length: 64)
            || !isHex(receipt.currentMoisesCaptureSHA256, length: 64) {
            issues.append(.invalidCaptureDigest(scenario))
        }
        let required = minimumRepetitions(for: scenario)
        if receipt.repetitionsCompleted < required {
            issues.append(.insufficientRepetitions(scenario, required: required, observed: receipt.repetitionsCompleted))
        }
        if receipt.successfulRepetitions != receipt.repetitionsCompleted {
            issues.append(.unsuccessfulRepetitions(scenario))
        }
        if !receipt.observedDurationSeconds.isFinite || receipt.observedDurationSeconds <= 0 {
            issues.append(.invalidCaseEnvelope(scenario))
        }
        if scenario == .longTrackStability && receipt.observedDurationSeconds < 1_800 {
            issues.append(.insufficientLongTrackDuration(observedSeconds: receipt.observedDurationSeconds))
        }
        if !receipt.timing.isValid { issues.append(.invalidTimingSummary(scenario)) }
        if !receipt.health.isValidForReview { issues.append(.runtimeHealthRejected(scenario)) }
    }

    private static func minimumRepetitions(for scenario: Lane3DeviceEvidenceScenario) -> Int {
        switch scenario {
        case .longTrackStability: return 1
        case .interruptionRecovery: return 5
        case .mixerGainRamp, .seekLoop, .tempo, .pitch, .metronome, .countIn: return 10
        }
    }

    private static func isHex(_ string: String, length: Int) -> Bool {
        guard string.count == length else { return false }
        return string.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

private enum Lane3AW24SHA256 {
    static func digest(fields: [String]) -> String {
        var bytes: [UInt8] = []
        for field in fields {
            bytes.append(contentsOf: field.utf8)
            bytes.append(0xff)
        }
        return hash(bytes).map { String(format: "%02x", $0) }.joined()
    }

    private static let initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]

    private static func hash(_ input: [UInt8]) -> [UInt8] {
        var message = input
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var h = initial
        var w = [UInt32](repeating: 0, count: 64)
        for chunkStart in stride(from: 0, to: message.count, by: 64) {
            for index in 0..<16 {
                let offset = chunkStart + index * 4
                w[index] = (UInt32(message[offset]) << 24)
                    | (UInt32(message[offset + 1]) << 16)
                    | (UInt32(message[offset + 2]) << 8)
                    | UInt32(message[offset + 3])
            }
            for index in 16..<64 {
                let s0 = rotateRight(w[index - 15], 7) ^ rotateRight(w[index - 15], 18) ^ (w[index - 15] >> 3)
                let s1 = rotateRight(w[index - 2], 17) ^ rotateRight(w[index - 2], 19) ^ (w[index - 2] >> 10)
                w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
            }
            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for index in 0..<64 {
                let s1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = hh &+ s1 &+ ch &+ constants[index] &+ w[index]
                let s0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            h[0] &+= a; h[1] &+= b; h[2] &+= c; h[3] &+= d
            h[4] &+= e; h[5] &+= f; h[6] &+= g; h[7] &+= hh
        }
        var output: [UInt8] = []
        for word in h {
            output.append(UInt8(truncatingIfNeeded: word >> 24))
            output.append(UInt8(truncatingIfNeeded: word >> 16))
            output.append(UInt8(truncatingIfNeeded: word >> 8))
            output.append(UInt8(truncatingIfNeeded: word))
        }
        return output
    }

    private static func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
    }
}
