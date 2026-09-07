import Foundation

extension AnalysisPhysicalRealAudioCorpusAssembler {
    static func validateSnapshot(
        _ workload: AnalysisDeviceWorkloadReceipt,
        fixtureID: String,
        issues: inout [AnalysisPhysicalRealAudioCorpusIssue]
    ) {
        guard let data = workload.snapshotCanonicalJSON,
              let claimed = workload.snapshotSHA256,
              isSHA256(claimed),
              let snapshot = try? JSONDecoder().decode(AnalysisSnapshot.self, from: data),
              let canonical = try? AnalysisSnapshotRobustness.canonicalJSON(snapshot),
              canonical == data,
              AnalysisDeviceWorkloadSHA256.hexDigest(data) == claimed,
              let summary = workload.outputSummary,
              summary == AnalysisDeviceWorkloadOutputSummary(snapshot: snapshot) else {
            issues.append(.init(code: .invalidSnapshot, fixtureID: fixtureID, detail: "complete fixture receipt requires canonical snapshot bytes/hash/output summary"))
            return
        }
    }

    static func timelineIsValid(_ stages: [AnalysisDeviceWorkloadStageEvent]) -> Bool {
        var previous = 0.0
        for stage in stages {
            if !stage.startedOffsetSeconds.isFinite
                || !stage.endedOffsetSeconds.isFinite
                || stage.startedOffsetSeconds < 0
                || stage.endedOffsetSeconds < stage.startedOffsetSeconds
                || stage.startedOffsetSeconds + 1e-9 < previous {
                return false
            }
            previous = stage.endedOffsetSeconds
        }
        return true
    }

    static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    static func isSHA256(_ value: String) -> Bool {
        AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(value)
    }

    static func issueOrder(_ lhs: AnalysisPhysicalRealAudioCorpusIssue, _ rhs: AnalysisPhysicalRealAudioCorpusIssue) -> Bool {
        (lhs.code.rawValue, lhs.fixtureID ?? "", lhs.detail) < (rhs.code.rawValue, rhs.fixtureID ?? "", rhs.detail)
    }
}
