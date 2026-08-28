import Foundation

public enum Lane3PhysicalEvidenceHandoffPackageValidationError: Error, Equatable, Sendable {
    case missingArtifact(String)
    case duplicateRole(String)
    case unexpectedRole(String)
    case malformedArtifact(String)
    case rolePayloadMismatch(String)
    case evidenceRejected
}

/// One exact serialized handoff artifact. The role is part of the package binding, so swapping
/// otherwise valid payloads between artifact slots is detectable and fails closed.
public struct Lane3PhysicalEvidenceHandoffSerializedArtifact: Equatable, Sendable {
    public let role: String
    public let payload: Data

    public init(role: String, payload: Data) {
        self.role = role
        self.payload = payload
    }
}

/// Host-side receipt for the exact serialized artifact package that was decoded and semantically
/// accepted by `Lane3PhysicalEvidenceHandoffHostValidator`.
///
/// This is tamper-evident binding only. It is not a digital signature, trusted provenance proof,
/// proof of physical-device execution, or PARITY promotion authority.
public struct Lane3PhysicalEvidenceHandoffPackageReceipt: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let artifactCount: Int
    public let packageBindingSHA256: String
    public let hostReceiptBindingSHA256: String
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let receiptBindingSHA256: String

    init(
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        artifactCount: Int,
        packageBindingSHA256: String,
        hostReceiptBindingSHA256: String
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_RECEIPT_V1_NON_PARITY"
        self.sessionIdentifier = sessionIdentifier
        self.appBuildCommitSHA = appBuildCommitSHA
        self.artifactCount = artifactCount
        self.packageBindingSHA256 = packageBindingSHA256
        self.hostReceiptBindingSHA256 = hostReceiptBindingSHA256
        self.acceptedForHQReview = true
        self.parityPromotionAllowed = false
        self.receiptBindingSHA256 = Self.computeReceiptBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            artifactCount: artifactCount,
            packageBindingSHA256: packageBindingSHA256,
            hostReceiptBindingSHA256: hostReceiptBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    public func verifyIntegrity() -> Bool {
        schemaVersion == 1
            && evidenceScope == "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_RECEIPT_V1_NON_PARITY"
            && acceptedForHQReview
            && !parityPromotionAllowed
            && receiptBindingSHA256 == Self.computeReceiptBinding(
                schemaVersion: schemaVersion,
                evidenceScope: evidenceScope,
                sessionIdentifier: sessionIdentifier,
                appBuildCommitSHA: appBuildCommitSHA,
                artifactCount: artifactCount,
                packageBindingSHA256: packageBindingSHA256,
                hostReceiptBindingSHA256: hostReceiptBindingSHA256,
                acceptedForHQReview: acceptedForHQReview,
                parityPromotionAllowed: parityPromotionAllowed
            )
    }

    private static func computeReceiptBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        artifactCount: Int,
        packageBindingSHA256: String,
        hostReceiptBindingSHA256: String,
        acceptedForHQReview: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            String(artifactCount),
            packageBindingSHA256,
            hostReceiptBindingSHA256,
            String(acceptedForHQReview),
            String(parityPromotionAllowed)
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffPackageValidator {
    public static let manifestRole = "manifest"
    public static let sessionPlanRole = "session-plan"
    public static let deviceBundleRole = "device-bundle"
    public static let resourceTraceRolePrefix = "resource-trace:"

    public static func resourceTraceRole(
        subject: Lane3PhysicalEvidenceResourceSubject,
        scenario: Lane3DeviceEvidenceScenario
    ) -> String {
        "\(resourceTraceRolePrefix)\(subject.rawValue):\(scenario.rawValue)"
    }

    /// Decode the exact serialized payloads and pass those decoded values directly to the existing
    /// semantic host validator. A successful receipt therefore binds the same bytes that supplied
    /// the semantic objects under review; callers cannot validate reconstructed objects while
    /// handing HQ different serialized artifacts.
    public static func validate(
        artifacts: [Lane3PhysicalEvidenceHandoffSerializedArtifact]
    ) throws -> Lane3PhysicalEvidenceHandoffPackageReceipt {
        var seenRoles = Set<String>()
        var byRole: [String: Lane3PhysicalEvidenceHandoffSerializedArtifact] = [:]
        var traceArtifacts: [Lane3PhysicalEvidenceHandoffSerializedArtifact] = []

        for artifact in artifacts {
            guard seenRoles.insert(artifact.role).inserted else {
                throw Lane3PhysicalEvidenceHandoffPackageValidationError.duplicateRole(artifact.role)
            }
            switch artifact.role {
            case manifestRole, sessionPlanRole, deviceBundleRole:
                byRole[artifact.role] = artifact
            default:
                guard artifact.role.hasPrefix(resourceTraceRolePrefix) else {
                    throw Lane3PhysicalEvidenceHandoffPackageValidationError.unexpectedRole(artifact.role)
                }
                traceArtifacts.append(artifact)
            }
        }

        guard let manifestArtifact = byRole[manifestRole] else {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.missingArtifact(manifestRole)
        }
        guard let planArtifact = byRole[sessionPlanRole] else {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.missingArtifact(sessionPlanRole)
        }
        guard let bundleArtifact = byRole[deviceBundleRole] else {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.missingArtifact(deviceBundleRole)
        }

        let decoder = JSONDecoder()
        let plan: Lane3PhysicalEvidenceSessionPlan
        let bundle: Lane3DeviceEvidenceBundle
        do {
            plan = try decoder.decode(Lane3PhysicalEvidenceSessionPlan.self, from: planArtifact.payload)
        } catch {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.malformedArtifact(sessionPlanRole)
        }
        do {
            bundle = try decoder.decode(Lane3DeviceEvidenceBundle.self, from: bundleArtifact.payload)
        } catch {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.malformedArtifact(deviceBundleRole)
        }

        var traces: [Lane3PhysicalEvidenceResourceTraceReceipt] = []
        traces.reserveCapacity(traceArtifacts.count)
        for artifact in traceArtifacts {
            let trace: Lane3PhysicalEvidenceResourceTraceReceipt
            do {
                trace = try decoder.decode(Lane3PhysicalEvidenceResourceTraceReceipt.self, from: artifact.payload)
            } catch {
                throw Lane3PhysicalEvidenceHandoffPackageValidationError.malformedArtifact(artifact.role)
            }
            let expectedRole = resourceTraceRole(subject: trace.subject, scenario: trace.scenario)
            guard artifact.role == expectedRole else {
                throw Lane3PhysicalEvidenceHandoffPackageValidationError.rolePayloadMismatch(artifact.role)
            }
            traces.append(trace)
        }

        let hostReceipt: Lane3PhysicalEvidenceHandoffHostReceipt
        do {
            hostReceipt = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: manifestArtifact.payload,
                plan: plan,
                deviceBundle: bundle,
                resourceTraces: traces
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffPackageValidationError.evidenceRejected
        }

        let packageBinding = computePackageBinding(artifacts: artifacts)
        return Lane3PhysicalEvidenceHandoffPackageReceipt(
            sessionIdentifier: hostReceipt.sessionIdentifier,
            appBuildCommitSHA: hostReceipt.appBuildCommitSHA,
            artifactCount: artifacts.count,
            packageBindingSHA256: packageBinding,
            hostReceiptBindingSHA256: hostReceipt.receiptBindingSHA256
        )
    }

    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffPackageReceipt,
        artifacts: [Lane3PhysicalEvidenceHandoffSerializedArtifact]
    ) -> Bool {
        guard receipt.verifyIntegrity() else { return false }
        do {
            return try validate(artifacts: artifacts) == receipt
        } catch {
            return false
        }
    }

    private static func computePackageBinding(
        artifacts: [Lane3PhysicalEvidenceHandoffSerializedArtifact]
    ) -> String {
        let artifactBindings = artifacts.map { artifact in
            (
                role: artifact.role,
                binding: Lane3LongTrackPCMIdentityHasher.digestFields([
                    "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_ARTIFACT_V1",
                    artifact.role,
                    String(artifact.payload.count),
                    artifact.payload.base64EncodedString()
                ])
            )
        }
        .sorted { lhs, rhs in
            if lhs.role != rhs.role { return lhs.role < rhs.role }
            return lhs.binding < rhs.binding
        }

        var fields = [
            "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_PACKAGE_V1",
            String(artifactBindings.count)
        ]
        for artifact in artifactBindings {
            fields.append(artifact.role)
            fields.append(artifact.binding)
        }
        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }
}
