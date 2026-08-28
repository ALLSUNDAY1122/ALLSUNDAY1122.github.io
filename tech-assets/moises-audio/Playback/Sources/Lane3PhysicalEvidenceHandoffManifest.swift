import Foundation

public enum Lane3PhysicalEvidenceHandoffManifestError: Error, Equatable, Sendable {
    case completionNotReady
    case completionReportMismatch
    case invalidAW24Bundle
    case invalidCurrentMoisesSnapshotDigest
    case missingCandidateResourceTrace
    case duplicateCandidateResourceTrace
    case missingCurrentMoisesResourceTrace
    case duplicateCurrentMoisesResourceTrace
    case invalidCandidateResourceArtifactBinding
    case invalidCurrentMoisesResourceArtifactBinding
    case manifestMismatch
}

/// HQ-facing, NON_PARITY export envelope for a completed Lane-3 physical evidence session.
///
/// The manifest does not create physical evidence and is not an authenticity signature. It only
/// gives downstream HQ review one deterministic SHA-256 binding across the already-validated AW24
/// device/listening bundle, AW51 session identity/completion result, AW52/AW53 resource artifacts,
/// build/fixture identity, and the externally hashed current-Moises reference snapshot.
public struct Lane3PhysicalEvidenceHandoffManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let fixtureID: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let currentMoisesSnapshotSHA256: String
    public let aw24BundleBindingSHA256: String
    public let aw51CompletionBindingSHA256: String
    public let candidateResourceArtifactSHA256: String
    public let currentMoisesResourceArtifactSHA256: String
    public let handoffBindingSHA256: String
    public let parityPromotionAllowed: Bool

    private init(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        fixtureID: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        currentMoisesSnapshotSHA256: String,
        aw24BundleBindingSHA256: String,
        aw51CompletionBindingSHA256: String,
        candidateResourceArtifactSHA256: String,
        currentMoisesResourceArtifactSHA256: String,
        handoffBindingSHA256: String
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_NON_PARITY"
        self.sessionIdentifier = sessionIdentifier
        self.appBuildCommitSHA = appBuildCommitSHA
        self.fixtureID = fixtureID
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.audioRoute = audioRoute
        self.currentMoisesReferenceSnapshotID = currentMoisesReferenceSnapshotID
        self.currentMoisesVersion = currentMoisesVersion
        self.currentMoisesSnapshotSHA256 = currentMoisesSnapshotSHA256
        self.aw24BundleBindingSHA256 = aw24BundleBindingSHA256
        self.aw51CompletionBindingSHA256 = aw51CompletionBindingSHA256
        self.candidateResourceArtifactSHA256 = candidateResourceArtifactSHA256
        self.currentMoisesResourceArtifactSHA256 = currentMoisesResourceArtifactSHA256
        self.handoffBindingSHA256 = handoffBindingSHA256
        self.parityPromotionAllowed = false
    }

    public static func make(
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        completionReport: Lane3PhysicalEvidenceSessionCompletionGateReport,
        candidateResourceArtifactSHA256: String,
        currentMoisesResourceArtifactSHA256: String,
        currentMoisesSnapshotSHA256: String
    ) throws -> Lane3PhysicalEvidenceHandoffManifest {
        let evaluated = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )
        guard completionReport.readyForHQReview else {
            throw Lane3PhysicalEvidenceHandoffManifestError.completionNotReady
        }
        guard evaluated == completionReport else {
            throw Lane3PhysicalEvidenceHandoffManifestError.completionReportMismatch
        }
        guard Lane3DeviceEvidenceValidator.validate(deviceBundle).readyForHQParityReview else {
            throw Lane3PhysicalEvidenceHandoffManifestError.invalidAW24Bundle
        }
        guard isLowercaseHex(currentMoisesSnapshotSHA256, length: 64) else {
            throw Lane3PhysicalEvidenceHandoffManifestError.invalidCurrentMoisesSnapshotDigest
        }

        let candidateMatches = resourceTraces.filter {
            $0.sessionIdentifier == plan.sessionIdentifier && $0.subject == .candidate
        }
        guard !candidateMatches.isEmpty else {
            throw Lane3PhysicalEvidenceHandoffManifestError.missingCandidateResourceTrace
        }
        guard candidateMatches.count == 1 else {
            throw Lane3PhysicalEvidenceHandoffManifestError.duplicateCandidateResourceTrace
        }

        let referenceMatches = resourceTraces.filter {
            $0.sessionIdentifier == plan.sessionIdentifier && $0.subject == .currentMoisesReference
        }
        guard !referenceMatches.isEmpty else {
            throw Lane3PhysicalEvidenceHandoffManifestError.missingCurrentMoisesResourceTrace
        }
        guard referenceMatches.count == 1 else {
            throw Lane3PhysicalEvidenceHandoffManifestError.duplicateCurrentMoisesResourceTrace
        }

        let candidate = candidateMatches[0]
        let reference = referenceMatches[0]
        guard isLowercaseHex(candidateResourceArtifactSHA256, length: 64),
              candidateResourceArtifactSHA256 == candidate.traceArtifactSHA256 else {
            throw Lane3PhysicalEvidenceHandoffManifestError.invalidCandidateResourceArtifactBinding
        }
        guard isLowercaseHex(currentMoisesResourceArtifactSHA256, length: 64),
              currentMoisesResourceArtifactSHA256 == reference.traceArtifactSHA256 else {
            throw Lane3PhysicalEvidenceHandoffManifestError.invalidCurrentMoisesResourceArtifactBinding
        }

        let aw24Binding = computeAW24BundleBinding(deviceBundle)
        let aw51Binding = computeAW51CompletionBinding(plan: plan, report: completionReport)
        let digest = computeHandoffBinding(
            sessionIdentifier: plan.sessionIdentifier,
            appBuildCommitSHA: plan.appBuildCommitSHA,
            fixtureID: plan.fixtureID,
            deviceModel: plan.deviceModel,
            osVersion: plan.osVersion,
            audioRoute: plan.audioRoute,
            currentMoisesReferenceSnapshotID: plan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: plan.currentMoisesVersion,
            currentMoisesSnapshotSHA256: currentMoisesSnapshotSHA256,
            aw24BundleBindingSHA256: aw24Binding,
            aw51CompletionBindingSHA256: aw51Binding,
            candidateResourceArtifactSHA256: candidateResourceArtifactSHA256,
            currentMoisesResourceArtifactSHA256: currentMoisesResourceArtifactSHA256
        )

        return Lane3PhysicalEvidenceHandoffManifest(
            sessionIdentifier: plan.sessionIdentifier,
            appBuildCommitSHA: plan.appBuildCommitSHA,
            fixtureID: plan.fixtureID,
            deviceModel: plan.deviceModel,
            osVersion: plan.osVersion,
            audioRoute: plan.audioRoute,
            currentMoisesReferenceSnapshotID: plan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: plan.currentMoisesVersion,
            currentMoisesSnapshotSHA256: currentMoisesSnapshotSHA256,
            aw24BundleBindingSHA256: aw24Binding,
            aw51CompletionBindingSHA256: aw51Binding,
            candidateResourceArtifactSHA256: candidateResourceArtifactSHA256,
            currentMoisesResourceArtifactSHA256: currentMoisesResourceArtifactSHA256,
            handoffBindingSHA256: digest
        )
    }

    public func verify(
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        completionReport: Lane3PhysicalEvidenceSessionCompletionGateReport,
        candidateResourceArtifactSHA256: String,
        currentMoisesResourceArtifactSHA256: String,
        currentMoisesSnapshotSHA256: String
    ) throws {
        let expected = try Self.make(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces,
            completionReport: completionReport,
            candidateResourceArtifactSHA256: candidateResourceArtifactSHA256,
            currentMoisesResourceArtifactSHA256: currentMoisesResourceArtifactSHA256,
            currentMoisesSnapshotSHA256: currentMoisesSnapshotSHA256
        )
        guard self == expected, handoffBindingSHA256 == recomputedHandoffBindingSHA256() else {
            throw Lane3PhysicalEvidenceHandoffManifestError.manifestMismatch
        }
    }

    public func recomputedHandoffBindingSHA256() -> String {
        Self.computeHandoffBinding(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            fixtureID: fixtureID,
            deviceModel: deviceModel,
            osVersion: osVersion,
            audioRoute: audioRoute,
            currentMoisesReferenceSnapshotID: currentMoisesReferenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
            currentMoisesSnapshotSHA256: currentMoisesSnapshotSHA256,
            aw24BundleBindingSHA256: aw24BundleBindingSHA256,
            aw51CompletionBindingSHA256: aw51CompletionBindingSHA256,
            candidateResourceArtifactSHA256: candidateResourceArtifactSHA256,
            currentMoisesResourceArtifactSHA256: currentMoisesResourceArtifactSHA256
        )
    }

    private static func computeAW24BundleBinding(_ bundle: Lane3DeviceEvidenceBundle) -> String {
        var fields = [
            "LANE3_HQ_AW24_BUNDLE_BINDING_V1",
            String(bundle.schemaVersion),
            bundle.evidenceScope,
            bundle.appBuildCommitSHA,
            bundle.deviceModel,
            bundle.osVersion,
            bundle.audioRoute.rawValue,
            String(bundle.physicalDevice),
            String(bundle.selectedXcodeBuild),
            bundle.currentMoisesReferenceSnapshotID,
            bundle.currentMoisesVersion,
            String(bundle.privacy.rawAudioEmbeddedInManifest),
            String(bundle.privacy.rawPCMEmbeddedInManifest),
            String(bundle.privacy.filePathCaptured),
            String(bundle.privacy.projectIdentifierCaptured),
            String(bundle.privacy.deviceIdentifierCaptured),
            String(bundle.privacy.individualGenerationOrTicketCaptured)
        ]
        for receipt in bundle.cases.sorted(by: { $0.scenario.rawValue < $1.scenario.rawValue }) {
            fields.append(contentsOf: [
                "case", receipt.scenario.rawValue, receipt.fixtureID,
                receipt.controlSignatureFNV1A64, receipt.aw13RunBindingSHA256,
                receipt.candidateCaptureSHA256, receipt.currentMoisesCaptureSHA256,
                receipt.caseBindingSHA256
            ])
        }
        for review in bundle.listeningReviews.sorted(by: { $0.scenario.rawValue < $1.scenario.rawValue }) {
            fields.append(contentsOf: [
                "review", review.scenario.rawValue, review.caseBindingSHA256,
                String(review.listeningPasses), String(review.obviousInferiorityObserved),
                String(review.clickPopObserved), String(review.warbleInferiorityObserved),
                String(review.phasinessInferiorityObserved), String(review.formantDamageInferiorityObserved)
            ])
        }
        return Lane3HQHandoffSHA256.digest(fields: fields)
    }

    private static func computeAW51CompletionBinding(
        plan: Lane3PhysicalEvidenceSessionPlan,
        report: Lane3PhysicalEvidenceSessionCompletionGateReport
    ) -> String {
        Lane3HQHandoffSHA256.digest(fields: [
            "LANE3_HQ_AW51_COMPLETION_BINDING_V1",
            plan.sessionIdentifier,
            plan.appBuildCommitSHA,
            plan.fixtureID,
            plan.deviceModel,
            plan.osVersion,
            plan.audioRoute.rawValue,
            plan.currentMoisesReferenceSnapshotID,
            plan.currentMoisesVersion,
            report.evidenceScope,
            report.baseline.evidenceScope,
            String(report.baseline.aw24DeviceBundleReadyForHQReview),
            String(report.baseline.candidateResourceTraceValid),
            String(report.baseline.currentMoisesResourceTraceValid),
            String(report.baseline.readyForHQReview),
            String(report.strictIssues.count),
            String(report.readyForHQReview),
            String(report.parityPromotionAllowed)
        ])
    }

    private static func computeHandoffBinding(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        fixtureID: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        currentMoisesSnapshotSHA256: String,
        aw24BundleBindingSHA256: String,
        aw51CompletionBindingSHA256: String,
        candidateResourceArtifactSHA256: String,
        currentMoisesResourceArtifactSHA256: String
    ) -> String {
        Lane3HQHandoffSHA256.digest(fields: [
            "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_V1",
            sessionIdentifier,
            appBuildCommitSHA,
            fixtureID,
            deviceModel,
            osVersion,
            audioRoute.rawValue,
            currentMoisesReferenceSnapshotID,
            currentMoisesVersion,
            currentMoisesSnapshotSHA256,
            aw24BundleBindingSHA256,
            aw51CompletionBindingSHA256,
            candidateResourceArtifactSHA256,
            currentMoisesResourceArtifactSHA256,
            "NON_PARITY"
        ])
    }

    private static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

private enum Lane3HQHandoffSHA256 {
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
