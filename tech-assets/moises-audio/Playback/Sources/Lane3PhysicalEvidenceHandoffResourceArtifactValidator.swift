import Foundation

public enum Lane3PhysicalEvidenceHandoffResourceArtifactValidationError: Error, Equatable, Sendable {
    case committedPlanReceiptRejected
    case duplicateResourceTraceIdentity
    case duplicateArtifactIdentity
    case missingArtifact
    case unexpectedArtifact
    case emptyArtifact
    case invalidTraceDigest
    case artifactDigestMismatch
}

/// Exact bytes supplied at the HQ/archive handoff boundary for one AW51 resource trace.
///
/// The bytes remain external evidence and are not embedded in the final receipt. The validator hashes
/// them and requires the digest to match the trace receipt already bound by the committed-plan handoff.
public struct Lane3PhysicalEvidenceHandoffResourceArtifact: Equatable, Sendable {
    public let sessionIdentifier: String
    public let subject: Lane3PhysicalEvidenceResourceSubject
    public let scenario: Lane3DeviceEvidenceScenario
    public let data: Data

    public init(
        sessionIdentifier: String,
        subject: Lane3PhysicalEvidenceResourceSubject,
        scenario: Lane3DeviceEvidenceScenario,
        data: Data
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.subject = subject
        self.scenario = scenario
        self.data = data
    }
}

/// Final NON_PARITY host receipt after both the persisted committed-plan receipt and every supplied
/// resource-trace artifact byte sequence have been rebound to the exact source tuple.
///
/// SHA-256 is tamper-evident only. This does not prove who captured the artifact, physical-device
/// execution, current-Moises provenance, perceptual parity, or product PARITY.
public struct Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let committedPlanReceiptBindingSHA256: String
    public let resourceArtifactSetBindingSHA256: String
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    fileprivate static let receiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_ARTIFACT_BOUND_HANDOFF_RECEIPT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.receiptScope,
              acceptedForHQReview,
              !parityPromotionAllowed,
              Self.isLowercaseHex(committedPlanReceiptBindingSHA256, length: 64),
              Self.isLowercaseHex(resourceArtifactSetBindingSHA256, length: 64),
              Self.isLowercaseHex(receiptBindingSHA256, length: 64) else {
            return false
        }
        return receiptBindingSHA256 == Self.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            committedPlanReceiptBindingSHA256: committedPlanReceiptBindingSHA256,
            resourceArtifactSetBindingSHA256: resourceArtifactSetBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func make(
        committedReceipt: Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt,
        artifactSetBindingSHA256: String
    ) -> Self {
        let schemaVersion = 1
        let evidenceScope = receiptScope
        let accepted = true
        let parity = false
        let binding = computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: committedReceipt.sessionIdentifier,
            appBuildCommitSHA: committedReceipt.appBuildCommitSHA,
            committedPlanReceiptBindingSHA256: committedReceipt.receiptBindingSHA256,
            resourceArtifactSetBindingSHA256: artifactSetBindingSHA256,
            acceptedForHQReview: accepted,
            parityPromotionAllowed: parity
        )
        return Self(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: committedReceipt.sessionIdentifier,
            appBuildCommitSHA: committedReceipt.appBuildCommitSHA,
            committedPlanReceiptBindingSHA256: committedReceipt.receiptBindingSHA256,
            resourceArtifactSetBindingSHA256: artifactSetBindingSHA256,
            acceptedForHQReview: accepted,
            parityPromotionAllowed: parity,
            receiptBindingSHA256: binding
        )
    }

    fileprivate static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        committedPlanReceiptBindingSHA256: String,
        resourceArtifactSetBindingSHA256: String,
        acceptedForHQReview: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_ARTIFACT_BOUND_HANDOFF_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            committedPlanReceiptBindingSHA256,
            resourceArtifactSetBindingSHA256,
            acceptedForHQReview ? "1" : "0",
            parityPromotionAllowed ? "1" : "0"
        ])
    }

    private static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

public enum Lane3PhysicalEvidenceHandoffResourceArtifactHostValidator {
    public static func validate(
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        resourceArtifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) throws -> Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt {
        let committedReceipt: Lane3PhysicalEvidenceHandoffCommittedPlanHostReceipt
        do {
            committedReceipt = try Lane3PhysicalEvidenceHandoffCommittedPlanReceiptHostValidator.validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.committedPlanReceiptRejected
        }

        let artifactSetBinding = try validateResourceArtifacts(
            resourceTraces: resourceTraces,
            resourceArtifacts: resourceArtifacts
        )
        let result = Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt.make(
            committedReceipt: committedReceipt,
            artifactSetBindingSHA256: artifactSetBinding
        )
        guard result.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.artifactDigestMismatch
        }
        return result
    }

    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffArtifactBoundHostReceipt,
        receiptJSON: Data,
        commitmentJSON: Data,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        resourceArtifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) -> Bool {
        guard receipt.verifyIntegrity() else { return false }
        do {
            return try validate(
                receiptJSON: receiptJSON,
                commitmentJSON: commitmentJSON,
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces,
                resourceArtifacts: resourceArtifacts
            ) == receipt
        } catch {
            return false
        }
    }

    private static func validateResourceArtifacts(
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt],
        resourceArtifacts: [Lane3PhysicalEvidenceHandoffResourceArtifact]
    ) throws -> String {
        for index in resourceTraces.indices {
            for other in resourceTraces.indices where other > index {
                if sameIdentity(resourceTraces[index], resourceTraces[other]) {
                    throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.duplicateResourceTraceIdentity
                }
            }
        }
        for index in resourceArtifacts.indices {
            for other in resourceArtifacts.indices where other > index {
                if sameIdentity(resourceArtifacts[index], resourceArtifacts[other]) {
                    throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.duplicateArtifactIdentity
                }
            }
        }

        var rows: [(session: String, subject: String, scenario: String, byteCount: Int, digest: String)] = []
        rows.reserveCapacity(resourceTraces.count)

        for trace in resourceTraces {
            guard isLowercaseHex(trace.traceArtifactSHA256, length: 64) else {
                throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.invalidTraceDigest
            }
            guard let artifact = resourceArtifacts.first(where: { sameIdentity(trace, $0) }) else {
                throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.missingArtifact
            }
            guard !artifact.data.isEmpty else {
                throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.emptyArtifact
            }
            let digest = Lane3HandoffRawSHA256.hash(artifact.data)
            guard digest == trace.traceArtifactSHA256 else {
                throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.artifactDigestMismatch
            }
            rows.append((
                session: trace.sessionIdentifier,
                subject: trace.subject.rawValue,
                scenario: trace.scenario.rawValue,
                byteCount: artifact.data.count,
                digest: digest
            ))
        }

        guard resourceArtifacts.allSatisfy({ artifact in
            resourceTraces.contains(where: { sameIdentity($0, artifact) })
        }) else {
            throw Lane3PhysicalEvidenceHandoffResourceArtifactValidationError.unexpectedArtifact
        }

        rows.sort {
            if $0.session != $1.session { return $0.session < $1.session }
            if $0.subject != $1.subject { return $0.subject < $1.subject }
            return $0.scenario < $1.scenario
        }
        var fields = ["LANE3_HQ_PHYSICAL_EVIDENCE_RESOURCE_ARTIFACT_SET_BINDING_V1", "count=\(rows.count)"]
        for row in rows {
            fields.append(row.session)
            fields.append(row.subject)
            fields.append(row.scenario)
            fields.append(String(row.byteCount))
            fields.append(row.digest)
        }
        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }

    private static func sameIdentity(
        _ lhs: Lane3PhysicalEvidenceResourceTraceReceipt,
        _ rhs: Lane3PhysicalEvidenceResourceTraceReceipt
    ) -> Bool {
        lhs.sessionIdentifier == rhs.sessionIdentifier
            && lhs.subject == rhs.subject
            && lhs.scenario == rhs.scenario
    }

    private static func sameIdentity(
        _ lhs: Lane3PhysicalEvidenceHandoffResourceArtifact,
        _ rhs: Lane3PhysicalEvidenceHandoffResourceArtifact
    ) -> Bool {
        lhs.sessionIdentifier == rhs.sessionIdentifier
            && lhs.subject == rhs.subject
            && lhs.scenario == rhs.scenario
    }

    private static func sameIdentity(
        _ lhs: Lane3PhysicalEvidenceResourceTraceReceipt,
        _ rhs: Lane3PhysicalEvidenceHandoffResourceArtifact
    ) -> Bool {
        lhs.sessionIdentifier == rhs.sessionIdentifier
            && lhs.subject == rhs.subject
            && lhs.scenario == rhs.scenario
    }

    private static func isLowercaseHex(_ value: String, length: Int) -> Bool {
        guard value.count == length else { return false }
        return value.utf8.allSatisfy { byte in
            (48...57).contains(byte) || (97...102).contains(byte)
        }
    }
}

/// Small one-shot SHA-256 used only to re-hash opaque handoff artifact bytes on portable hosts.
/// Keeping it Foundation-only lets the existing Linux Swift 6 handoff gate execute the same code as
/// Apple hosts without adding CryptoKit/Crypto package availability as a second trust boundary.
private enum Lane3HandoffRawSHA256 {
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

    static func hash(_ data: Data) -> String {
        var message = Array(data)
        let bitLength = UInt64(message.count) &* 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var state = initial
        var offset = 0
        while offset < message.count {
            var words = Array(repeating: UInt32(0), count: 64)
            for index in 0..<16 {
                let base = offset + index * 4
                words[index] = (UInt32(message[base]) << 24)
                    | (UInt32(message[base + 1]) << 16)
                    | (UInt32(message[base + 2]) << 8)
                    | UInt32(message[base + 3])
            }
            for index in 16..<64 {
                let s0 = rotateRight(words[index - 15], 7)
                    ^ rotateRight(words[index - 15], 18)
                    ^ (words[index - 15] >> 3)
                let s1 = rotateRight(words[index - 2], 17)
                    ^ rotateRight(words[index - 2], 19)
                    ^ (words[index - 2] >> 10)
                words[index] = words[index - 16] &+ s0 &+ words[index - 7] &+ s1
            }

            var a = state[0], b = state[1], c = state[2], d = state[3]
            var e = state[4], f = state[5], g = state[6], h = state[7]
            for index in 0..<64 {
                let s1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
                let ch = (e & f) ^ ((~e) & g)
                let temp1 = h &+ s1 &+ ch &+ constants[index] &+ words[index]
                let s0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                h = g; g = f; f = e; e = d &+ temp1
                d = c; c = b; b = a; a = temp1 &+ temp2
            }
            state[0] &+= a; state[1] &+= b; state[2] &+= c; state[3] &+= d
            state[4] &+= e; state[5] &+= f; state[6] &+= g; state[7] &+= h
            offset += 64
        }

        var output = ""
        output.reserveCapacity(64)
        for word in state {
            output += String(format: "%08x", word)
        }
        return output
    }

    private static func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
    }
}
