import Foundation

public enum AnalysisDeviceWorkloadReceiptValidator {
    public static func validate(
        _ receipt: AnalysisDeviceWorkloadReceipt,
        performanceEvidence: AnalysisDevicePerformanceEvidence,
        policy: AnalysisDeviceWorkloadPolicy
    ) -> AnalysisDeviceWorkloadValidationReport {
        var issues = validatePolicy(policy)
        let runID = receipt.runID
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if receipt.schemaVersion != 1 || trim(runID).isEmpty || trim(receipt.performanceEvidenceRunID).isEmpty || trim(receipt.executionID).isEmpty || !isSHA256(receipt.executionBindingSHA256) {
            issues.append(.init(code: .invalidReceipt, runID: runID, detail: "receipt requires schema 1, nonempty run/execution identifiers and a valid execution binding SHA-256"))
        }
        if receipt.performanceEvidenceRunID != performanceEvidence.provenance.runID || runID != performanceEvidence.provenance.runID || receipt.runKind != performanceEvidence.provenance.runKind {
            issues.append(.init(code: .performanceBindingMismatch, runID: runID, detail: "receipt run ID/kind must exactly match the W23 performance evidence"))
        }
        if receipt.manifestID != policy.manifestID || receipt.manifestID != performanceEvidence.provenance.manifestID || receipt.manifestSHA256.lowercased() != policy.manifestSHA256.lowercased() || receipt.manifestSHA256.lowercased() != performanceEvidence.provenance.manifestSHA256.lowercased() {
            issues.append(.init(code: .manifestBindingMismatch, runID: runID, detail: "receipt, W23 evidence and HQ policy must bind the same manifest ID/SHA"))
        }
        guard let expectedSource = policy.fixtures[receipt.source.fixtureID] else {
            issues.append(.init(code: .sourceBindingMismatch, runID: runID, detail: "fixture is not present in the HQ workload policy"))
            return report(receipt, issues)
        }
        if receipt.source.fixtureID != performanceEvidence.provenance.fixtureID || expectedSource != receipt.source || !validSource(receipt.source) || abs(receipt.source.sourceDurationSeconds - performanceEvidence.provenance.fixtureDurationSeconds) > 0.001 {
            issues.append(.init(code: .sourceBindingMismatch, runID: runID, detail: "fixture ID, source SHA, duration, sample rate or channel count differs from the approved binding"))
        }
        if receipt.identity != policy.identity || [receipt.identity.analyzerID, receipt.identity.analyzerVersion, receipt.identity.analysisConfigurationID, receipt.identity.buildIdentity].contains(where: { trim($0).isEmpty }) {
            issues.append(.init(code: .analyzerBindingMismatch, runID: runID, detail: "analyzer/build/configuration identity differs from the HQ workload policy"))
        }
        validateStages(receipt, performanceEvidence, &issues)
        validateSnapshot(receipt, &issues)

        let expectedExecutionBinding = executionBindingSHA256(
            runID: receipt.runID,
            performanceEvidenceRunID: receipt.performanceEvidenceRunID,
            runKind: receipt.runKind,
            manifestID: receipt.manifestID,
            manifestSHA256: receipt.manifestSHA256,
            source: receipt.source,
            identity: receipt.identity,
            executionID: receipt.executionID,
            workloadStartedAt: receipt.workloadStartedAt,
            stages: receipt.stages,
            snapshotSHA256: receipt.snapshotSHA256,
            outputSummary: receipt.outputSummary
        )
        if receipt.executionBindingSHA256.lowercased() != expectedExecutionBinding {
            issues.append(.init(code: .executionBindingMismatch, runID: runID, detail: "run-specific execution binding does not match receipt contents"))
        }
        return report(receipt, issues)
    }

    public static func validateBatch(
        receipts: [AnalysisDeviceWorkloadReceipt],
        performanceRuns: [AnalysisDevicePerformanceEvidence],
        policy: AnalysisDeviceWorkloadPolicy
    ) -> [AnalysisDeviceWorkloadValidationReport] {
        let performanceByRun = Dictionary(grouping: performanceRuns, by: { $0.provenance.runID })
        var reports: [AnalysisDeviceWorkloadValidationReport] = []
        var executionOwners: [String: String] = [:]
        var bindingOwners: [String: String] = [:]

        for receipt in receipts.sorted(by: { $0.runID < $1.runID }) {
            guard let evidence = performanceByRun[receipt.runID]?.first, performanceByRun[receipt.runID]?.count == 1 else {
                reports.append(.init(runID: receipt.runID, status: .invalid, issues: [
                    .init(code: .performanceBindingMismatch, runID: receipt.runID, detail: "exactly one W23 evidence record is required for each workload receipt")
                ]))
                continue
            }
            var report = validate(receipt, performanceEvidence: evidence, policy: policy)
            var extra = report.issues
            if let owner = executionOwners[receipt.executionID], owner != receipt.runID {
                extra.append(.init(code: .reusedExecution, runID: receipt.runID, detail: "execution ID was already used by run \(owner)"))
            } else { executionOwners[receipt.executionID] = receipt.runID }
            if let owner = bindingOwners[receipt.executionBindingSHA256], owner != receipt.runID {
                extra.append(.init(code: .reusedExecution, runID: receipt.runID, detail: "complete execution receipt was reused from run \(owner)"))
            } else { bindingOwners[receipt.executionBindingSHA256] = receipt.runID }
            if extra.count != report.issues.count {
                report = .init(runID: receipt.runID, status: .invalid, issues: extra.sorted(by: issueSort))
            }
            reports.append(report)
        }
        return reports
    }

    public static func executionBindingSHA256(
        runID: String,
        performanceEvidenceRunID: String,
        runKind: AnalysisDevicePerformanceRunKind,
        manifestID: String,
        manifestSHA256: String,
        source: AnalysisDeviceWorkloadSourceBinding,
        identity: AnalysisDeviceWorkloadIdentity,
        executionID: String,
        workloadStartedAt: Date,
        stages: [AnalysisDeviceWorkloadStageEvent],
        snapshotSHA256: String?,
        outputSummary: AnalysisDeviceWorkloadOutputSummary?
    ) -> String {
        let stageString = stages.map {
            "\($0.stage.rawValue):\(canonicalDouble($0.startedOffsetSeconds)):\(canonicalDouble($0.endedOffsetSeconds)):\($0.status.rawValue)"
        }.joined(separator: "|")
        let summaryString: String
        if let outputSummary {
            summaryString = "\(outputSummary.tempoPresent ? 1 : 0),\(outputSummary.beatCount),\(outputSummary.keyPresent ? 1 : 0),\(outputSummary.chordCount),\(outputSummary.sectionCount)"
        } else { summaryString = "nil" }
        let text = [
            "schema=1", "run=\(runID)", "performance=\(performanceEvidenceRunID)", "kind=\(runKind.rawValue)",
            "manifest=\(manifestID)", "manifest_sha=\(manifestSHA256.lowercased())", "fixture=\(source.fixtureID)",
            "source_sha=\(source.sourceSHA256.lowercased())", "duration=\(canonicalDouble(source.sourceDurationSeconds))",
            "sample_rate=\(canonicalDouble(source.sourceSampleRate))", "channels=\(source.sourceChannelCount)",
            "analyzer=\(identity.analyzerID)", "analyzer_version=\(identity.analyzerVersion)",
            "config=\(identity.analysisConfigurationID)", "build=\(identity.buildIdentity)", "execution=\(executionID)",
            "workload_started=\(canonicalDate(workloadStartedAt))", "stages=\(stageString)",
            "snapshot_sha=\(snapshotSHA256?.lowercased() ?? "nil")", "summary=\(summaryString)"
        ].joined(separator: "\n")
        return AnalysisDeviceWorkloadSHA256.hexDigest(Data(text.utf8))
    }

    private static func validatePolicy(_ policy: AnalysisDeviceWorkloadPolicy) -> [AnalysisDeviceWorkloadIssue] {
        let trim: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var issues: [AnalysisDeviceWorkloadIssue] = []
        if policy.schemaVersion != 1 || policy.authority != "HQ_LATE_INTEGRATION" || trim(policy.approvalReference).isEmpty || trim(policy.manifestID).isEmpty || !isSHA256(policy.manifestSHA256) || policy.fixtures.isEmpty {
            issues.append(.init(code: .invalidPolicy, detail: "policy requires schema 1, HQ authority, approval reference, manifest binding and at least one fixture"))
        }
        if [policy.identity.analyzerID, policy.identity.analyzerVersion, policy.identity.analysisConfigurationID, policy.identity.buildIdentity].contains(where: { trim($0).isEmpty }) {
            issues.append(.init(code: .invalidPolicy, detail: "policy analyzer/build/configuration identity must be complete"))
        }
        for (key, binding) in policy.fixtures where key != binding.fixtureID || !validSource(binding) {
            issues.append(.init(code: .invalidPolicy, detail: "fixture dictionary keys must equal valid fixture bindings"))
        }
        return issues.sorted(by: issueSort)
    }

    private static func validateStages(_ receipt: AnalysisDeviceWorkloadReceipt, _ evidence: AnalysisDevicePerformanceEvidence, _ issues: inout [AnalysisDeviceWorkloadIssue]) {
        let events = receipt.stages
        var seen = Set<AnalysisDeviceWorkloadStage>()
        var previousEnd = 0.0
        for event in events {
            if !seen.insert(event.stage).inserted {
                issues.append(.init(code: .duplicateStage, runID: receipt.runID, stage: event.stage, detail: "stage occurs more than once"))
            }
            if !event.startedOffsetSeconds.isFinite || !event.endedOffsetSeconds.isFinite || event.startedOffsetSeconds < 0 || event.endedOffsetSeconds < event.startedOffsetSeconds || event.startedOffsetSeconds + 1e-9 < previousEnd {
                issues.append(.init(code: .invalidStageTimeline, runID: receipt.runID, stage: event.stage, detail: "stage offsets must be finite, monotonic and non-overlapping"))
            }
            previousEnd = max(previousEnd, event.endedOffsetSeconds)
        }
        let expected = AnalysisDeviceWorkloadStage.requiredCompleteOrder
        let actualStages = events.map(\.stage)
        if actualStages != Array(expected.prefix(actualStages.count)) {
            issues.append(.init(code: .stageOrderViolation, runID: receipt.runID, detail: "stages must form the canonical Analysis prefix in exact order"))
        }

        switch receipt.runKind {
        case .completeAnalysis:
            if actualStages != expected {
                for stage in expected where !seen.contains(stage) {
                    issues.append(.init(code: .missingRequiredStage, runID: receipt.runID, stage: stage, detail: "complete Analysis requires every canonical stage"))
                }
            }
            if events.contains(where: { $0.status != .completed }) || !evidence.completedNormally {
                issues.append(.init(code: .semanticMismatch, runID: receipt.runID, detail: "complete run requires all stages COMPLETED and W23 completedNormally=true"))
            }
        case .cancellationProbe:
            let cancelled = events.last?.status == .cancelled && events.dropLast().allSatisfy { $0.status == .completed }
            if events.isEmpty || !cancelled || evidence.completedNormally || receipt.snapshotCanonicalJSON != nil || receipt.snapshotSHA256 != nil || receipt.outputSummary != nil {
                issues.append(.init(code: .semanticMismatch, runID: receipt.runID, detail: "cancellation probe requires a completed-prefix plus one terminal CANCELLED stage, no final snapshot, and W23 completedNormally=false"))
            }
            guard let requested = evidence.cancellation.requestedOffsetSeconds, requested.isFinite, requested >= 0,
                  let observed = evidence.cancellation.observedTerminationOffsetSeconds, observed.isFinite, observed >= requested else {
                issues.append(.init(code: .noRealWorkBeforeCancellation, runID: receipt.runID, detail: "W23 cancellation request/observation offsets are required"))
                return
            }
            let base = receipt.workloadStartedAt.timeIntervalSince(evidence.provenance.startedAt)
            guard base.isFinite, base >= -0.250 else {
                issues.append(.init(code: .invalidStageTimeline, runID: receipt.runID, detail: "workload start must not materially predate W23 provenance start"))
                return
            }
            let normalizedBase = max(0, base)
            let workBeforeRequest = events.contains { normalizedBase + $0.startedOffsetSeconds < requested - 1e-9 }
            let terminalObservedAfterRequest = events.last.map { normalizedBase + $0.endedOffsetSeconds >= requested - 1e-9 && normalizedBase + $0.endedOffsetSeconds <= observed + 0.500 } ?? false
            if !workBeforeRequest || !terminalObservedAfterRequest {
                issues.append(.init(code: .noRealWorkBeforeCancellation, runID: receipt.runID, detail: "real canonical Analysis work must begin before cancellation and terminate consistently with W23 cancellation telemetry"))
            }
        }
    }

    private static func validateSnapshot(_ receipt: AnalysisDeviceWorkloadReceipt, _ issues: inout [AnalysisDeviceWorkloadIssue]) {
        guard receipt.runKind == .completeAnalysis else { return }
        guard let data = receipt.snapshotCanonicalJSON, let claimedHash = receipt.snapshotSHA256, let summary = receipt.outputSummary, isSHA256(claimedHash) else {
            issues.append(.init(code: .invalidSnapshotArtifact, runID: receipt.runID, detail: "complete run requires canonical snapshot JSON, SHA-256 and output summary"))
            return
        }
        guard let snapshot = try? JSONDecoder().decode(AnalysisSnapshot.self, from: data), let canonical = try? AnalysisSnapshotRobustness.canonicalJSON(snapshot), canonical == data else {
            issues.append(.init(code: .invalidSnapshotArtifact, runID: receipt.runID, detail: "snapshot artifact must decode and already be in canonical deterministic serialization"))
            return
        }
        let actualHash = AnalysisDeviceWorkloadSHA256.hexDigest(data)
        if actualHash != claimedHash.lowercased() {
            issues.append(.init(code: .snapshotHashMismatch, runID: receipt.runID, detail: "snapshot SHA-256 does not match canonical snapshot bytes"))
        }
        if AnalysisDeviceWorkloadOutputSummary(snapshot: snapshot) != summary {
            issues.append(.init(code: .outputSummaryMismatch, runID: receipt.runID, detail: "output cardinality/decision metadata does not match the canonical snapshot artifact"))
        }
    }

    private static func report(_ receipt: AnalysisDeviceWorkloadReceipt, _ issues: [AnalysisDeviceWorkloadIssue]) -> AnalysisDeviceWorkloadValidationReport {
        let sorted = issues.sorted(by: issueSort)
        let status: AnalysisDeviceWorkloadValidationStatus
        if !sorted.isEmpty { status = .invalid }
        else if receipt.runKind == .completeAnalysis { status = .fullWorkloadCompletePendingHQ }
        else { status = .realWorkCancellationPendingHQ }
        return .init(runID: receipt.runID, status: status, issues: sorted)
    }

    private static func validSource(_ source: AnalysisDeviceWorkloadSourceBinding) -> Bool {
        !source.fixtureID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isSHA256(source.sourceSHA256) && source.sourceDurationSeconds.isFinite && source.sourceDurationSeconds > 0 && source.sourceSampleRate.isFinite && source.sourceSampleRate > 0 && source.sourceChannelCount > 0
    }

    private static func isSHA256(_ text: String) -> Bool {
        text.count == 64 && text.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (65...70).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }

    private static func canonicalDate(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }

    private static func canonicalDouble(_ value: Double) -> String {
        guard value.isFinite else { return "nonfinite" }
        return String(format: "%.9f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func issueSort(_ lhs: AnalysisDeviceWorkloadIssue, _ rhs: AnalysisDeviceWorkloadIssue) -> Bool {
        (lhs.code.rawValue, lhs.runID ?? "", lhs.stage?.rawValue ?? "", lhs.detail) < (rhs.code.rawValue, rhs.runID ?? "", rhs.stage?.rawValue ?? "", rhs.detail)
    }
}
