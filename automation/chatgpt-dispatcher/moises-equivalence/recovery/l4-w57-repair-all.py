from pathlib import Path

ROOT = Path('tech-assets/moises-audio')


def replace_exact(relative_path: str, old: str, new: str, expected: int | None = None) -> None:
    path = ROOT / relative_path
    text = path.read_text()
    count = text.count(old)
    if count == 0:
        if new in text:
            print(f'already repaired: {relative_path}')
            return
        raise SystemExit(f'repair anchor missing: {relative_path}')
    if expected is not None and count != expected:
        raise SystemExit(f'unexpected anchor count {count} in {relative_path}; expected {expected}')
    path.write_text(text.replace(old, new))
    print(f'repaired {relative_path}: {count} replacement(s)')


# Epoch45 Swift 6.0.3 parser/type-check blockers.
replace_exact(
    'Analysis/AnalysisPhysicalEvidencePublishedBatchReopen.swift',
    '''        let runIDs = control.runs.map(\\.runID)
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
''',
    '''        let runIDs = control.runs.map(\\.runID)
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
''',
    1,
)

replace_exact(
    'Analysis/AnalysisRealAudioParityAdjudication.swift',
    '''    static func issueOrder(
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
''',
    '''    static func issueOrder(
        _ lhs: AnalysisAnalysisParityAdjudicationIssue,
        _ rhs: AnalysisAnalysisParityAdjudicationIssue
    ) -> Bool {
        if lhs.code.rawValue != rhs.code.rawValue {
            return lhs.code.rawValue < rhs.code.rawValue
        }
        let lhsParityRowID = lhs.parityRowID ?? ""
        let rhsParityRowID = rhs.parityRowID ?? ""
        if lhsParityRowID != rhsParityRowID { return lhsParityRowID < rhsParityRowID }
        let lhsFixtureID = lhs.fixtureID ?? ""
        let rhsFixtureID = rhs.fixtureID ?? ""
        if lhsFixtureID != rhsFixtureID { return lhsFixtureID < rhsFixtureID }
        let lhsDomain = lhs.domain ?? ""
        let rhsDomain = rhs.domain ?? ""
        if lhsDomain != rhsDomain { return lhsDomain < rhsDomain }
        let lhsMetric = lhs.metric ?? ""
        let rhsMetric = rhs.metric ?? ""
        if lhsMetric != rhsMetric { return lhsMetric < rhsMetric }
        return lhs.detail < rhs.detail
    }
''',
    1,
)

replace_exact(
    'Analysis/AnalysisRealAudioParityAdjudicationValidation.swift',
    '                  row.worstRegression.map { $0.isFinite && $0 >= 0 } ?? true else {\n',
    '                  row.worstRegression.map({ $0.isFinite && $0 >= 0 }) ?? true else {\n',
    1,
)

# Swift 6 test-source compatibility uncovered by subsequent W57 runs.
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisRealAudioParityAdjudicationTests.swift',
    'expectedCaptureSetSHA256: overrideCaptureRoot ?? (try AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet))',
    'expectedCaptureSetSHA256: try (overrideCaptureRoot ?? AnalysisAnalysisParityAdjudicationRoot.stableSHA256(captureSet))',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisChunkedInputPipelineTests.swift',
    'result.inputDiagnostics',
    'result.diagnostics',
)
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisChunkedInputPipelineTests.swift',
    'chunked.inputDiagnostics',
    'chunked.diagnostics',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisP021PhysicalEvidenceAdjudicationTests.swift',
    'w44CheckpointCertificateRootSHA256: checkpointRoot ?? checkpointCertificate.declaredCertificateRootSHA256',
    'w44CheckpointCertificateRootSHA256: try (checkpointRoot ?? checkpointCertificate.declaredCertificateRootSHA256)',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisP021PhysicalEvidenceAdjudicationTests.swift',
    'w42AnchorReceiptRootSHA256: anchorRoot ?? anchorReceipt.declaredAnchorReceiptRootSHA256',
    'w42AnchorReceiptRootSHA256: try (anchorRoot ?? anchorReceipt.declaredAnchorReceiptRootSHA256)',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/AnalysisP021PhysicalEvidenceAdjudicationTests.swift',
    'w41TransferRootSHA256: transferRoot ?? transfer.declaredTransferRootSHA256',
    'w41TransferRootSHA256: try (transferRoot ?? transfer.declaredTransferRootSHA256)',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/ChordVocabularyHardeningTests.swift',
    'events.first?.startSeconds',
    'events.first?.startSeconds ?? .nan',
    1,
)
replace_exact(
    'Tests/MoisesAudioCoreTests/ChordVocabularyHardeningTests.swift',
    'events.last?.endSeconds',
    'events.last?.endSeconds ?? .nan',
    1,
)

# W53 hard-link publication intentionally increments link count until temp unlink.
durable = ROOT / 'Analysis/AnalysisPhysicalRealAudioBridgeConsumptionDurablePublication.swift'
text = durable.read_text()
old = '''    targetPublished=true; try injectIfRequested(injectedFault,target:target,point:.afterPublishBeforeDirectorySync,preserveTemporary:&preserveTemporary)
    try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.unlinkExpectedEntry(name:tempName,expectedIdentity:tempIdentity,in:directory); preserveTemporary=true; try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.synchronizeDirectory(directory); try injectIfRequested(injectedFault,target:target,point:.afterDirectorySync,preserveTemporary:&preserveTemporary)'''
new = '''    guard tempIdentity.linkCount < UInt64.max,
          let linkedTempIdentity=try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.entryIdentity(name:tempName,in:directory),
          linkedTempIdentity.device==tempIdentity.device,
          linkedTempIdentity.inode==tempIdentity.inode,
          linkedTempIdentity.mode==tempIdentity.mode,
          linkedTempIdentity.size==tempIdentity.size,
          linkedTempIdentity.linkCount==tempIdentity.linkCount+1,
          let linkedDestinationIdentity=try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.entryIdentity(name:destinationName,in:directory),
          linkedDestinationIdentity==linkedTempIdentity else { throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.namespaceSubstitutionDetected }
    targetPublished=true; try injectIfRequested(injectedFault,target:target,point:.afterPublishBeforeDirectorySync,preserveTemporary:&preserveTemporary)
    try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.unlinkExpectedEntry(name:tempName,expectedIdentity:linkedTempIdentity,in:directory)
    guard let publishedIdentity=try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.entryIdentity(name:destinationName,in:directory),
          publishedIdentity.device==tempIdentity.device,
          publishedIdentity.inode==tempIdentity.inode,
          publishedIdentity.mode==tempIdentity.mode,
          publishedIdentity.size==tempIdentity.size,
          publishedIdentity.linkCount==tempIdentity.linkCount else { throw AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError.namespaceSubstitutionDetected }
    preserveTemporary=true; try AnalysisPhysicalRealAudioBridgeConsumptionNamespaceHardening.synchronizeDirectory(directory); try injectIfRequested(injectedFault,target:target,point:.afterDirectorySync,preserveTemporary:&preserveTemporary)'''
if old in text:
    durable.write_text(text.replace(old, new, 1))
    print('repaired W53 hard-link identity transition')
elif new in text:
    print('already repaired: W53 hard-link identity transition')
else:
    raise SystemExit('W53 hard-link repair anchor missing')

# Preserve durable-publication error fidelity through SecureFilesystem.
secure = ROOT / 'Analysis/AnalysisPhysicalRealAudioBridgeConsumptionSecureFilesystem.swift'
text = secure.read_text()
old_catch = '''            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
                throw error
            } catch {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
            }'''
new_catch = '''            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError {
                throw error
            } catch let error as AnalysisPhysicalRealAudioBridgeConsumptionDurablePublicationError {
                switch error {
                case .pathOutsideLedgerRoot:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.pathOutsideLedgerRoot
                case .symbolicLinkRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.symbolicLinkRejected
                case .nonRegularTargetRejected:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.nonRegularFileRejected
                case .oversizedFile:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.oversizedFile
                default:
                    throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
                }
            } catch {
                throw AnalysisPhysicalRealAudioBridgeConsumptionSecureStoreError.unsafeFilesystemTopology
            }'''
count = text.count(old_catch)
if count:
    if count != 2:
        raise SystemExit(f'unexpected SecureFilesystem catch count: {count}')
    secure.write_text(text.replace(old_catch, new_catch))
    print('repaired SecureFilesystem durable-publication error fidelity')
elif new_catch in text:
    print('already repaired: SecureFilesystem durable-publication error fidelity')
else:
    raise SystemExit('SecureFilesystem catch repair anchor missing')

# Durable evidence note, not a PARITY claim.
evidence = ROOT / 'Analysis/benchmarks/L4-W57_EPOCH45_SWIFT6_RECOVERY.md'
evidence.write_text('''# L4-W57 Epoch45 Swift 6 recovery

- Source: HQ integration Run 33036684010 / portable SwiftPM job 98400765279.
- Exact blocker 1: `AnalysisPhysicalEvidencePublishedBatchReopen.swift` guard/trailing-closure parser ambiguity under Swift 6.0.3.
- Exact blocker 2: `AnalysisRealAudioParityAdjudication.swift` six-field tuple comparison exceeded the type-checker reasonable-time budget.
- Warning hardened: parenthesized `Optional.map` closure in `AnalysisRealAudioParityAdjudicationValidation.swift`.
- Subsequent W57 runs exposed Swift 6 test-source compatibility errors and W53 hard-link namespace identity/error-fidelity regressions; those repairs are included here.
- Repairs preserve validation semantics and lexicographic issue ordering.
- PARITY status is unchanged; this is compile/runtime regression restoration only.
''')
