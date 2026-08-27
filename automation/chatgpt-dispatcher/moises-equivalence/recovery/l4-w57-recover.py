from pathlib import Path

reopen = Path('tech-assets/moises-audio/Analysis/AnalysisPhysicalEvidencePublishedBatchReopen.swift')
text = reopen.read_text()
old = '''        let runIDs = control.runs.map(\\.runID)
        let executionIDs = control.runs.map(\\.workloadExecutionID)
        guard control.schemaVersion == 1,
              control.state == .readyToPublish,
              control.publicationID == publicationID,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.batchRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w27RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w38RootSHA256),
              !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count,
              control.runs.allSatisfy {
                  AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.runID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent($0.workloadExecutionID)
                      && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256($0.w39BundleRootSHA256)
              } else {
'''
new = '''        let runIDs = control.runs.map(\\.runID)
        let executionIDs = control.runs.map(\\.workloadExecutionID)
        let runsAreSafe = control.runs.allSatisfy { run in
            AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.runID)
                && AnalysisPhysicalEvidenceW39BatchLoader.safeComponent(run.workloadExecutionID)
                && AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(run.w39BundleRootSHA256)
        }
        guard control.schemaVersion == 1,
              control.state == .readyToPublish,
              control.publicationID == publicationID,
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.batchRootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w27RootSHA256),
              AnalysisPhysicalEvidenceW39BatchLoader.isSHA256(control.w38RootSHA256),
              !runIDs.isEmpty,
              Set(runIDs).count == runIDs.count,
              Set(executionIDs).count == executionIDs.count,
              runsAreSafe else {
'''
if old not in text:
    raise SystemExit('expected PublishedBatchReopen snippet not found')
reopen.write_text(text.replace(old, new, 1))

adjudication = Path('tech-assets/moises-audio/Analysis/AnalysisRealAudioParityAdjudication.swift')
text = adjudication.read_text()
old = '''    static func issueOrder(
        _ lhs: AnalysisAnalysisParityAdjudicationIssue,
        _ rhs: AnalysisAnalysisParityAdjudicationIssue
    ) -> Bool {
        (
            lhs.code.rawValue,
            lhs.parityRowID ?? "",
            lhs.fixtureID ?? "",
            lhs.domain ?? "",
            lhs.metric ?? "",
            lhs.detail
        ) < (
            rhs.code.rawValue,
            rhs.parityRowID ?? "",
            rhs.fixtureID ?? "",
            rhs.domain ?? "",
            rhs.metric ?? "",
            rhs.detail
        )
    }
'''
new = '''    static func issueOrder(
        _ lhs: AnalysisAnalysisParityAdjudicationIssue,
        _ rhs: AnalysisAnalysisParityAdjudicationIssue
    ) -> Bool {
        if lhs.code.rawValue != rhs.code.rawValue {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        let lhsParityRowID = lhs.parityRowID ?? ""
        let rhsParityRowID = rhs.parityRowID ?? ""
        if lhsParityRowID != rhsParityRowID {
            return lhsParityRowID < rhsParityRowID
        }
        let lhsFixtureID = lhs.fixtureID ?? ""
        let rhsFixtureID = rhs.fixtureID ?? ""
        if lhsFixtureID != rhsFixtureID {
            return lhsFixtureID < rhsFixtureID
        }
        let lhsDomain = lhs.domain ?? ""
        let rhsDomain = rhs.domain ?? ""
        if lhsDomain != rhsDomain {
            return lhsDomain < rhsDomain
        }
        let lhsMetric = lhs.metric ?? ""
        let rhsMetric = rhs.metric ?? ""
        if lhsMetric != rhsMetric {
            return lhsMetric < rhsMetric
        }
        return lhs.detail < rhs.detail
    }
'''
if old not in text:
    raise SystemExit('expected issueOrder snippet not found')
adjudication.write_text(text.replace(old, new, 1))

validation = Path('tech-assets/moises-audio/Analysis/AnalysisRealAudioParityAdjudicationValidation.swift')
text = validation.read_text()
old = '                  row.worstRegression.map { $0.isFinite && $0 >= 0 } ?? true else {\n'
new = '                  row.worstRegression.map({ $0.isFinite && $0 >= 0 }) ?? true else {\n'
if old not in text:
    raise SystemExit('expected validation map snippet not found')
validation.write_text(text.replace(old, new, 1))

evidence = Path('tech-assets/moises-audio/Analysis/benchmarks/L4-W57_EPOCH45_SWIFT6_RECOVERY.md')
evidence.write_text('''# L4-W57 Epoch45 Swift 6 recovery

- Source: HQ integration Run 33036684010 / portable SwiftPM job 98400765279.
- Exact blocker 1: `AnalysisPhysicalEvidencePublishedBatchReopen.swift` guard/trailing-closure parser ambiguity under Swift 6.0.3.
- Exact blocker 2: `AnalysisRealAudioParityAdjudication.swift` six-field tuple comparison exceeded the type-checker reasonable-time budget.
- Warning hardened: parenthesized `Optional.map` closure in `AnalysisRealAudioParityAdjudicationValidation.swift`.
- Repair preserves validation semantics and lexicographic issue ordering.
- PARITY status is unchanged; this is compile restoration only.
''')
