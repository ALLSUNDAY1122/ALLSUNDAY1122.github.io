import Foundation

public enum AnalysisPhysicalRealAudioCorpusAssembler {
    public static let requiredAuthority = "HQ_LATE_INTEGRATION"
    public static let limitations = [
        "NON_PARITY: W47 packages only bind Project Analysis rows to one claimed iphoneos/arm64 corpus execution session and are inputs to W46/HQ judgment; they do not promote any PARITY row.",
        "The genuine-Lane2 decoder kind, device model, OS, source revision and build identity remain metadata commitments unless independently attested, signed or trusted-timestamped by HQ.",
        "W47 requires exact canonical manifest inventory and one unique decoder/workload execution per fixture; partial/selective successful subsets are not exportable as a ready package.",
        "A portable/Linux process may validate or reopen package bytes but cannot create physical-iPhone evidence; only the iOS coordinator may claim the physical runtime preflight.",
        "HQ must retain the underlying rights-cleared source files and independently verify their SHA-256 values and legal grants before using the audited report in W46."
    ]

    public static func assemble(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt],
        configuration: MusicAnalysisConfiguration = .productBaseline,
        generatedAt: Date
    ) throws -> AnalysisPhysicalRealAudioCorpusExecutionPackage {
        let issues = validateInputs(
            manifest: manifest,
            manifestSHA256: manifestSHA256,
            runtime: runtime,
            receipts: receipts,
            evaluatedAt: generatedAt
        )
        guard issues.isEmpty else { throw AnalysisPhysicalRealAudioCorpusExecutionError.invalid(issues) }

        let report = try buildAuditedReport(
            manifest: manifest,
            runtime: runtime,
            receipts: receipts,
            configuration: configuration,
            generatedAt: generatedAt
        )
        let reportRoot = try AnalysisPhysicalRealAudioCorpusCanonical.stableSHA256(report)
        let runtimeRoot = try AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(runtime)
        let provisional = AnalysisPhysicalRealAudioCorpusExecutionPackage(
            manifestID: manifest.manifestID,
            manifestSHA256: manifestSHA256,
            runtime: runtime,
            runtimeBindingSHA256: runtimeRoot,
            expectedFixtureIDs: manifest.cases.map(\.fixtureID),
            receipts: receipts,
            auditedProjectReport: report,
            auditedProjectReportSHA256: reportRoot,
            limitations: limitations,
            declaredPackageRootSHA256: String(repeating: "0", count: 64)
        )
        let root = try AnalysisPhysicalRealAudioCorpusCanonical.packageSHA256(provisional)
        return AnalysisPhysicalRealAudioCorpusExecutionPackage(
            manifestID: provisional.manifestID,
            manifestSHA256: provisional.manifestSHA256,
            runtime: provisional.runtime,
            runtimeBindingSHA256: provisional.runtimeBindingSHA256,
            expectedFixtureIDs: provisional.expectedFixtureIDs,
            receipts: provisional.receipts,
            auditedProjectReport: provisional.auditedProjectReport,
            auditedProjectReportSHA256: provisional.auditedProjectReportSHA256,
            limitations: provisional.limitations,
            declaredPackageRootSHA256: root
        )
    }

    public static func reopen(
        _ package: AnalysisPhysicalRealAudioCorpusExecutionPackage,
        manifest: AnalysisRealAudioBenchmarkManifest,
        configuration: MusicAnalysisConfiguration = .productBaseline,
        evaluatedAt: Date
    ) -> [AnalysisPhysicalRealAudioCorpusIssue] {
        var issues = validateInputs(
            manifest: manifest,
            manifestSHA256: package.manifestSHA256,
            runtime: package.runtime,
            receipts: package.receipts,
            evaluatedAt: evaluatedAt
        )
        if package.schemaVersion != 1
            || package.status != .readyForW46ProjectInputPendingHQ
            || package.manifestID != manifest.manifestID
            || package.expectedFixtureIDs != manifest.cases.map(\.fixtureID).sorted()
            || package.limitations != limitations {
            issues.append(.init(code: .fixtureInventoryMismatch, detail: "package envelope or exact fixture inventory differs from W47 contract"))
        }

        let runtimeRoot = try? AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(package.runtime)
        if runtimeRoot == nil || runtimeRoot != package.runtimeBindingSHA256 {
            issues.append(.init(code: .invalidRuntimeBinding, detail: "runtime binding SHA-256 does not match canonical runtime metadata"))
        }

        if let rebuilt = try? buildAuditedReport(
            manifest: manifest,
            runtime: package.runtime,
            receipts: package.receipts,
            configuration: configuration,
            generatedAt: package.auditedProjectReport.generatedAt
        ) {
            if rebuilt != package.auditedProjectReport {
                issues.append(.init(code: .reportRebuildMismatch, detail: "audited Project report does not rebuild exactly from retained fixture execution snapshots"))
            }
            let root = try? AnalysisPhysicalRealAudioCorpusCanonical.stableSHA256(rebuilt)
            if root == nil || root != package.auditedProjectReportSHA256 {
                issues.append(.init(code: .reportRootMismatch, detail: "audited Project report SHA-256 is invalid"))
            }
        } else {
            issues.append(.init(code: .reportRebuildMismatch, detail: "retained receipts cannot rebuild the audited Project report"))
        }

        let packageRoot = try? AnalysisPhysicalRealAudioCorpusCanonical.packageSHA256(package)
        if packageRoot == nil || packageRoot != package.declaredPackageRootSHA256 {
            issues.append(.init(code: .packageRootMismatch, detail: "package root does not match canonical W47 package payload"))
        }
        return issues.sorted(by: issueOrder)
    }

    public static func validateInputs(
        manifest: AnalysisRealAudioBenchmarkManifest,
        manifestSHA256: String,
        runtime: AnalysisPhysicalRealAudioRuntimeBinding,
        receipts: [AnalysisPhysicalRealAudioFixtureExecutionReceipt],
        evaluatedAt: Date
    ) -> [AnalysisPhysicalRealAudioCorpusIssue] {
        var issues: [AnalysisPhysicalRealAudioCorpusIssue] = []
        let manifestIssues = AnalysisRealAudioManifestValidator.validate(manifest, at: evaluatedAt)
        let canonicalManifestData = try? AnalysisRealAudioBenchmarkCodec.encodeManifest(manifest)
        let canonicalManifestSHA256 = canonicalManifestData.map(AnalysisDeviceWorkloadSHA256.hexDigest)
        if !manifestIssues.isEmpty
            || !isSHA256(manifestSHA256)
            || canonicalManifestSHA256 != manifestSHA256.lowercased() {
            issues.append(.init(code: .invalidManifest, detail: "manifest must pass canonical validation and its canonical bytes must hash to the supplied SHA-256 binding"))
        }
        for item in manifest.cases where item.sourceKind != .realAudio {
            issues.append(.init(code: .nonRealFixture, fixtureID: item.fixtureID, detail: "W47 physical corpus execution requires REAL_AUDIO for every fixture"))
        }

        let runtimeStrings = [
            runtime.approvalReference, runtime.sourceRevision, runtime.buildIdentity, runtime.deviceModel,
            runtime.osVersion, runtime.physicalSessionID, runtime.analyzerID, runtime.analyzerVersion,
            runtime.analysisConfigurationID, runtime.engine, runtime.engineVersion,
            runtime.decoder.decoderID, runtime.decoder.decoderVersion, runtime.decoder.decoderSessionID
        ]
        let runtimeValid = runtime.schemaVersion == 1
            && runtime.authority == requiredAuthority
            && runtime.platform.lowercased() == "iphoneos"
            && runtime.architecture.lowercased() == "arm64"
            && runtimeStrings.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && runtime.decoder.schemaVersion == 1
        if !runtimeValid {
            issues.append(.init(code: .invalidRuntimeBinding, detail: "runtime must be one HQ-bound iphoneos/arm64 device/build/session with complete analyzer and decoder identity"))
        }
        if runtime.decoder.kind != .genuineLane2BoundedDecoder {
            issues.append(.init(code: .nonGenuineDecoder, detail: "only GENUINE_LANE2_BOUNDED_DECODER may feed W47"))
        }

        let expectedIDs = manifest.cases.map(\.fixtureID).sorted()
        let observedIDs = receipts.map(\.fixtureID).sorted()
        if expectedIDs != observedIDs || Set(observedIDs).count != observedIDs.count {
            issues.append(.init(code: .fixtureInventoryMismatch, detail: "receipts must cover every canonical manifest fixture exactly once with no selective subset"))
        }
        var manifestByID: [String: AnalysisRealAudioBenchmarkCase] = [:]
        for item in manifest.cases where manifestByID[item.fixtureID] == nil {
            manifestByID[item.fixtureID] = item
        }
        let runtimeRoot = try? AnalysisPhysicalRealAudioCorpusCanonical.runtimeSHA256(runtime)
        var runIDs = Set<String>()
        var executionIDs = Set<String>()
        var decoderExecutionIDs = Set<String>()

        for receipt in receipts.sorted(by: { $0.fixtureID < $1.fixtureID }) {
            let fixtureID = receipt.fixtureID
            guard let item = manifestByID[fixtureID] else { continue }
            if receipt.schemaVersion != 1
                || runtimeRoot == nil
                || receipt.runtimeBindingSHA256 != runtimeRoot! {
                issues.append(.init(code: .invalidRuntimeBinding, fixtureID: fixtureID, detail: "receipt runtime root must equal the one package runtime binding"))
            }
            if !runIDs.insert(receipt.workloadReceipt.runID).inserted {
                issues.append(.init(code: .duplicateRunID, fixtureID: fixtureID, detail: "workload run ID was reused inside one corpus session"))
            }
            if !executionIDs.insert(receipt.workloadReceipt.executionID).inserted {
                issues.append(.init(code: .duplicateExecutionID, fixtureID: fixtureID, detail: "W36 workload execution ID was reused across fixtures"))
            }
            if receipt.decoderExecutionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !decoderExecutionIDs.insert(receipt.decoderExecutionID).inserted {
                issues.append(.init(code: .duplicateDecoderExecutionID, fixtureID: fixtureID, detail: "decoder execution ID must be nonempty and unique per fixture"))
            }
            if receipt.sourceSHA256 != item.rights.sourceSHA256.lowercased()
                || !isSHA256(receipt.sourceSHA256)
                || receipt.sourceSampleRate <= 0
                || !receipt.sourceSampleRate.isFinite
                || receipt.sourceSampleCount <= 0
                || receipt.sourceChannelCount <= 0 {
                issues.append(.init(code: .sourceBindingMismatch, fixtureID: fixtureID, detail: "actual decoded source identity/descriptor differs from canonical manifest source"))
            }
            let observedDuration = receipt.sourceSampleRate > 0
                ? Double(receipt.sourceSampleCount) / receipt.sourceSampleRate
                : 0
            let tolerance = max(0.050, item.expectedDurationSeconds * 0.001)
            if abs(observedDuration - item.expectedDurationSeconds) > tolerance
                || receipt.observedSourceChunkCount <= 0
                || receipt.observedSourceSampleCount != receipt.sourceSampleCount {
                issues.append(.init(code: .sourceObservationMismatch, fixtureID: fixtureID, detail: "current chunked runtime did not observe the exact declared decoded sample population"))
            }

            let workload = receipt.workloadReceipt
            let expectedIdentity = AnalysisDeviceWorkloadIdentity(
                analyzerID: runtime.analyzerID,
                analyzerVersion: runtime.analyzerVersion,
                analysisConfigurationID: runtime.analysisConfigurationID,
                buildIdentity: runtime.buildIdentity
            )
            let workloadBound = workload.schemaVersion == 1
                && workload.runKind == .completeAnalysis
                && workload.manifestID == manifest.manifestID
                && workload.manifestSHA256 == manifestSHA256.lowercased()
                && workload.source.fixtureID == fixtureID
                && workload.source.sourceSHA256 == receipt.sourceSHA256
                && abs(workload.source.sourceDurationSeconds - item.expectedDurationSeconds) <= tolerance
                && abs(workload.source.sourceSampleRate - receipt.sourceSampleRate) <= 0.001
                && workload.source.sourceChannelCount == receipt.sourceChannelCount
                && workload.identity == expectedIdentity
                && workload.performanceEvidenceRunID == workload.runID
                && !workload.executionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !workloadBound {
                issues.append(.init(code: .workloadBindingMismatch, fixtureID: fixtureID, detail: "W36 receipt does not bind the same manifest/source/analyzer/build/session inputs"))
            }
            let stageValid = workload.stages.map(\.stage) == AnalysisDeviceWorkloadStage.requiredCompleteOrder
                && workload.stages.allSatisfy { $0.status == .completed }
                && timelineIsValid(workload.stages)
            if !stageValid {
                issues.append(.init(code: .invalidWorkloadStages, fixtureID: fixtureID, detail: "fixture must complete every current Analysis stage once in canonical order"))
            }
            validateSnapshot(workload, fixtureID: fixtureID, issues: &issues)
            let binding = AnalysisDeviceWorkloadReceiptValidator.executionBindingSHA256(
                runID: workload.runID,
                performanceEvidenceRunID: workload.performanceEvidenceRunID,
                runKind: workload.runKind,
                manifestID: workload.manifestID,
                manifestSHA256: workload.manifestSHA256,
                source: workload.source,
                identity: workload.identity,
                executionID: workload.executionID,
                workloadStartedAt: workload.workloadStartedAt,
                stages: workload.stages,
                snapshotSHA256: workload.snapshotSHA256,
                outputSummary: workload.outputSummary
            )
            if binding != workload.executionBindingSHA256 {
                issues.append(.init(code: .workloadBindingMismatch, fixtureID: fixtureID, detail: "W36 execution binding SHA-256 does not recompute"))
            }
        }
        return issues.sorted(by: issueOrder)
    }

}
