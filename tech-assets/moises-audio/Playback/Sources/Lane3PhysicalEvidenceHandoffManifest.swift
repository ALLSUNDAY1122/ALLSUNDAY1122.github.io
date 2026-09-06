import Foundation

public enum Lane3PhysicalEvidenceHandoffManifestError: Error, Equatable, Sendable {
    case completionGateRejected
    case manifestMismatch
}

/// Tamper-evident, deterministic binding for a completed physical-evidence session.
///
/// This manifest is intentionally NON_PARITY. It binds the already-validated AW24/AW51 evidence
/// artifacts so a downstream HQ/archive step cannot accidentally associate a resource trace with a
/// different build, fixture, device context, or current-Moises reference snapshot. The SHA-256
/// binding detects mutation/substitution of bound fields, but it is not a digital signature and does
/// not establish artifact authenticity or provenance by itself.
public struct Lane3PhysicalEvidenceHandoffManifest: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let sessionIdentifier: String
    public let appBuildCommitSHA: String
    public let deviceModel: String
    public let osVersion: String
    public let audioRoute: Lane3DeviceEvidenceAudioRoute
    public let fixtureID: String
    public let currentMoisesReferenceSnapshotID: String
    public let currentMoisesVersion: String
    public let planBindingSHA256: String
    public let deviceBundleBindingSHA256: String
    public let resourceTraceSetBindingSHA256: String
    public let manifestBindingSHA256: String
    public let parityPromotionAllowed: Bool

    public func verifyIntegrity() -> Bool {
        manifestBindingSHA256 == Self.computeManifestBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: deviceModel,
            osVersion: osVersion,
            audioRoute: audioRoute,
            fixtureID: fixtureID,
            currentMoisesReferenceSnapshotID: currentMoisesReferenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
            planBindingSHA256: planBindingSHA256,
            deviceBundleBindingSHA256: deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256: resourceTraceSetBindingSHA256,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func computeManifestBinding(
        schemaVersion: Int,
        evidenceScope: String,
        sessionIdentifier: String,
        appBuildCommitSHA: String,
        deviceModel: String,
        osVersion: String,
        audioRoute: Lane3DeviceEvidenceAudioRoute,
        fixtureID: String,
        currentMoisesReferenceSnapshotID: String,
        currentMoisesVersion: String,
        planBindingSHA256: String,
        deviceBundleBindingSHA256: String,
        resourceTraceSetBindingSHA256: String,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_MANIFEST_V1",
            String(schemaVersion),
            evidenceScope,
            sessionIdentifier,
            appBuildCommitSHA,
            deviceModel,
            osVersion,
            audioRoute.rawValue,
            fixtureID,
            currentMoisesReferenceSnapshotID,
            currentMoisesVersion,
            planBindingSHA256,
            deviceBundleBindingSHA256,
            resourceTraceSetBindingSHA256,
            canonicalBool(parityPromotionAllowed)
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffManifestBuilder {
    private static let manifestScope = "LANE3_HQ_PHYSICAL_EVIDENCE_HANDOFF_MANIFEST_V1_NON_PARITY"

    public static func make(
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Lane3PhysicalEvidenceHandoffManifest {
        let completion = Lane3PhysicalEvidenceSessionCompletionGate.evaluate(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )
        guard completion.readyForHQReview else {
            throw Lane3PhysicalEvidenceHandoffManifestError.completionGateRejected
        }

        let planBinding = computePlanBinding(plan)
        let bundleBinding = computeDeviceBundleBinding(deviceBundle)
        let traceSetBinding = computeResourceTraceSetBinding(resourceTraces)
        let schemaVersion = 1
        let parityPromotionAllowed = false
        let overallBinding = Lane3PhysicalEvidenceHandoffManifest.computeManifestBinding(
            schemaVersion: schemaVersion,
            evidenceScope: manifestScope,
            sessionIdentifier: plan.sessionIdentifier,
            appBuildCommitSHA: plan.appBuildCommitSHA,
            deviceModel: plan.deviceModel,
            osVersion: plan.osVersion,
            audioRoute: plan.audioRoute,
            fixtureID: plan.fixtureID,
            currentMoisesReferenceSnapshotID: plan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: plan.currentMoisesVersion,
            planBindingSHA256: planBinding,
            deviceBundleBindingSHA256: bundleBinding,
            resourceTraceSetBindingSHA256: traceSetBinding,
            parityPromotionAllowed: parityPromotionAllowed
        )

        return Lane3PhysicalEvidenceHandoffManifest(
            schemaVersion: schemaVersion,
            evidenceScope: manifestScope,
            sessionIdentifier: plan.sessionIdentifier,
            appBuildCommitSHA: plan.appBuildCommitSHA,
            deviceModel: plan.deviceModel,
            osVersion: plan.osVersion,
            audioRoute: plan.audioRoute,
            fixtureID: plan.fixtureID,
            currentMoisesReferenceSnapshotID: plan.currentMoisesReferenceSnapshotID,
            currentMoisesVersion: plan.currentMoisesVersion,
            planBindingSHA256: planBinding,
            deviceBundleBindingSHA256: bundleBinding,
            resourceTraceSetBindingSHA256: traceSetBinding,
            manifestBindingSHA256: overallBinding,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    public static func verify(
        _ manifest: Lane3PhysicalEvidenceHandoffManifest,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Bool {
        guard manifest.verifyIntegrity() else { return false }
        return try make(
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        ) == manifest
    }

    private static func computePlanBinding(_ plan: Lane3PhysicalEvidenceSessionPlan) -> String {
        var fields = [
            "LANE3_HQ_PHYSICAL_EVIDENCE_PLAN_BINDING_V1",
            String(plan.schemaVersion),
            plan.evidenceScope,
            plan.sessionIdentifier,
            plan.appBuildCommitSHA,
            plan.deviceModel,
            plan.osVersion,
            plan.audioRoute.rawValue,
            plan.currentMoisesReferenceSnapshotID,
            plan.currentMoisesVersion,
            plan.fixtureID,
            canonicalBool(plan.sessionStartAllowed),
            canonicalBool(plan.parityPromotionAllowed)
        ]

        appendStringArray(plan.targetedParityRows.sorted(), label: "targetedParityRows", to: &fields)

        let issues = plan.preflightIssues.sorted {
            let lhs = $0.kind.rawValue + "|" + ($0.scenario?.rawValue ?? "") + "|" + $0.detail
            let rhs = $1.kind.rawValue + "|" + ($1.scenario?.rawValue ?? "") + "|" + $1.detail
            return lhs < rhs
        }
        fields.append("preflightIssues.count=\(issues.count)")
        for issue in issues {
            fields.append(issue.kind.rawValue)
            fields.append(issue.scenario?.rawValue ?? "")
            fields.append(issue.detail)
        }

        let steps = plan.steps.sorted { $0.ordinal < $1.ordinal }
        fields.append("steps.count=\(steps.count)")
        for step in steps {
            fields.append(String(step.ordinal))
            fields.append(step.kind.rawValue)
            fields.append(step.scenario?.rawValue ?? "")
            fields.append(String(step.minimumRepetitions))
            fields.append(String(step.minimumDurationSeconds.bitPattern))
            appendStringArray(step.targetedParityRows.sorted(), label: "stepTargetedRows", to: &fields)
            appendStringArray(step.requiredArtifactRoles.sorted(), label: "requiredArtifactRoles", to: &fields)
        }

        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }

    private static func computeDeviceBundleBinding(_ bundle: Lane3DeviceEvidenceBundle) -> String {
        var fields = [
            "LANE3_HQ_PHYSICAL_EVIDENCE_DEVICE_BUNDLE_BINDING_V1",
            String(bundle.schemaVersion),
            bundle.evidenceScope,
            bundle.appBuildCommitSHA,
            bundle.deviceModel,
            bundle.osVersion,
            bundle.audioRoute.rawValue,
            canonicalBool(bundle.physicalDevice),
            canonicalBool(bundle.selectedXcodeBuild),
            bundle.currentMoisesReferenceSnapshotID,
            bundle.currentMoisesVersion,
            canonicalBool(bundle.privacy.rawAudioEmbeddedInManifest),
            canonicalBool(bundle.privacy.rawPCMEmbeddedInManifest),
            canonicalBool(bundle.privacy.filePathCaptured),
            canonicalBool(bundle.privacy.projectIdentifierCaptured),
            canonicalBool(bundle.privacy.deviceIdentifierCaptured),
            canonicalBool(bundle.privacy.individualGenerationOrTicketCaptured),
            canonicalBool(bundle.parityPromotionAllowed)
        ]

        let cases = bundle.cases.sorted { $0.scenario.rawValue < $1.scenario.rawValue }
        fields.append("cases.count=\(cases.count)")
        for receipt in cases {
            fields.append(receipt.scenario.rawValue)
            fields.append(receipt.caseBindingSHA256)
        }

        let reviews = bundle.listeningReviews.sorted { $0.scenario.rawValue < $1.scenario.rawValue }
        fields.append("listeningReviews.count=\(reviews.count)")
        for review in reviews {
            fields.append(review.scenario.rawValue)
            fields.append(review.caseBindingSHA256)
            fields.append(String(review.listeningPasses))
            fields.append(canonicalBool(review.obviousInferiorityObserved))
            fields.append(canonicalBool(review.clickPopObserved))
            fields.append(canonicalBool(review.warbleInferiorityObserved))
            fields.append(canonicalBool(review.phasinessInferiorityObserved))
            fields.append(canonicalBool(review.formantDamageInferiorityObserved))
            fields.append(canonicalBool(review.parityPromotionAllowed))
        }

        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }

    private static func computeResourceTraceSetBinding(
        _ resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> String {
        var fields = ["LANE3_HQ_PHYSICAL_EVIDENCE_RESOURCE_TRACE_SET_BINDING_V1"]
        let traces = resourceTraces.sorted {
            if $0.subject.rawValue == $1.subject.rawValue {
                return $0.scenario.rawValue < $1.scenario.rawValue
            }
            return $0.subject.rawValue < $1.subject.rawValue
        }
        fields.append("resourceTraces.count=\(traces.count)")
        for trace in traces {
            fields.append(String(trace.schemaVersion))
            fields.append(trace.evidenceScope)
            fields.append(trace.sessionIdentifier)
            fields.append(trace.subject.rawValue)
            fields.append(trace.scenario.rawValue)
            fields.append(String(trace.observedDurationSeconds.bitPattern))
            fields.append(String(trace.sampleCount))
            fields.append(String(trace.maximumSampleIntervalSeconds.bitPattern))
            fields.append(String(trace.peakRSSBytes))
            fields.append(String(trace.thermalNominalSamples))
            fields.append(String(trace.thermalFairSamples))
            fields.append(String(trace.thermalSeriousSamples))
            fields.append(String(trace.thermalCriticalSamples))
            fields.append(String(trace.batteryStartLevel.bitPattern))
            fields.append(String(trace.batteryEndLevel.bitPattern))
            fields.append(canonicalBool(trace.externalPowerConnectedDuringBatteryWindow))
            fields.append(trace.traceArtifactSHA256)
            fields.append(canonicalBool(trace.parityPromotionAllowed))
        }
        return Lane3LongTrackPCMIdentityHasher.digestFields(fields)
    }

    private static func appendStringArray(
        _ values: [String],
        label: String,
        to fields: inout [String]
    ) {
        fields.append("\(label).count=\(values.count)")
        fields.append(contentsOf: values)
    }
}

private func canonicalBool(_ value: Bool) -> String {
    value ? "1" : "0"
}
