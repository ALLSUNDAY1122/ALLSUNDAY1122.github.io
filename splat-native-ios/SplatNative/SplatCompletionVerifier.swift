import Foundation

/// Verifies that a `.splat` is the atomically committed result of a finished local project.
///
/// Structural record alignment alone is not completion evidence: a process can be interrupted
/// after writing any whole number of 32-byte records. Export/share/view entry points must pass
/// through this verifier before treating a local result as user-owned completed data.
enum SplatCompletionVerifier {
    private static let maximumCompletionEvidenceByteCount: Int64 = 64 * 1024

    struct Verification: Equatable, Sendable {
        let url: URL
        let sha256: String
    }

    enum VerificationError: LocalizedError {
        case unexpectedSource
        case projectNotFinished
        case completionEvidenceMissing
        case completionEvidenceMismatch

        var errorDescription: String? {
            switch self {
            case .unexpectedSource:
                return "保存済みプロジェクトの完成Splatではありません。"
            case .projectNotFinished:
                return "3D生成が完了したプロジェクトとして確認できません。"
            case .completionEvidenceMissing:
                return "3D生成の完了記録が見つかりません。"
            case .completionEvidenceMismatch:
                return "3Dデータと完了記録が一致しません。再生成してください。"
            }
        }
    }

    static func verify(
        sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try verifyWithDigest(sourceURL: sourceURL, fileManager: fileManager).url
    }

    static func verifyWithDigest(
        sourceURL: URL,
        fileManager: FileManager = .default
    ) throws -> Verification {
        guard sourceURL.isFileURL else {
            throw VerificationError.unexpectedSource
        }

        let projectURL = sourceURL.deletingLastPathComponent()
        let expectedURL = projectURL.appendingPathComponent(ScanProjectStore.splatResultFileName)
        guard normalized(sourceURL) == normalized(expectedURL),
              !isSymbolicLink(expectedURL) else {
            throw VerificationError.unexpectedSource
        }

        let store = ScanProjectStore(
            rootURL: projectURL.deletingLastPathComponent(),
            fileManager: fileManager
        )
        guard let loadedManifest = try? store.loadManifest(projectURL: projectURL) else {
            throw VerificationError.projectNotFinished
        }

        // The broad previous-result recovery path is for an interrupted reprocess. Once a manifest
        // says a generation finished, never let that path silently replace it with an older backup;
        // finished generations are handled below by strong integrity verification and bounded
        // same-size trusted recovery only.
        let manifest: ScanProjectManifest
        if loadedManifest.stage == .finished {
            manifest = loadedManifest
        } else {
            manifest = SplatPreviousResultEvidence.recoverTrustedPreviousIfNeeded(
                projectURL: projectURL,
                manifest: loadedManifest,
                fileManager: fileManager
            )
        }
        guard manifest.stage == .finished,
              manifest.splatFileName == ScanProjectStore.splatResultFileName else {
            throw VerificationError.projectNotFinished
        }

        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard let evidence = loadValidEvidence(at: evidenceURL, fileManager: fileManager) else {
            throw VerificationError.completionEvidenceMissing
        }

        // A missing result is recoverable only through the same independently SHA-verified previous
        // asset used for late integrity failures. If no same-size trusted backup exists this helper
        // fails closed and the missing/corrupt generation is never fabricated from weaker evidence.
        guard fileManager.fileExists(atPath: expectedURL.path) else {
            let recoveredDigest = try recoverTrustedPreviousAndVerify(
                projectURL: projectURL,
                expectedURL: expectedURL,
                evidenceURL: evidenceURL,
                failedEvidence: evidence,
                fileManager: fileManager
            )
            SplatPreviousResultEvidence.discardBackup(projectURL: projectURL, fileManager: fileManager)
            return Verification(url: expectedURL, sha256: recoveredDigest)
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: expectedURL.path),
              let size = attributes[.size] as? NSNumber else {
            throw VerificationError.completionEvidenceMismatch
        }

        // A byte-count mismatch is normally a hard completion failure. The only exception is when
        // this failed generation still has a separately SHA-verified same-size previous result.
        // Without that bounded fallback this still fails closed immediately.
        if size.int64Value != evidence.byteCount {
            let recoveredDigest = try recoverTrustedPreviousAndVerify(
                projectURL: projectURL,
                expectedURL: expectedURL,
                evidenceURL: evidenceURL,
                failedEvidence: evidence,
                fileManager: fileManager
            )
            SplatPreviousResultEvidence.discardBackup(projectURL: projectURL, fileManager: fileManager)
            return Verification(url: expectedURL, sha256: recoveredDigest)
        }

        let verifiedDigest: String
        do {
            verifiedDigest = try SplatStrongCompletionEvidence.verifyOrSeal(
                sourceURL: expectedURL,
                evidence: evidence,
                fileManager: fileManager
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            verifiedDigest = try recoverTrustedPreviousAndVerify(
                projectURL: projectURL,
                expectedURL: expectedURL,
                evidenceURL: evidenceURL,
                failedEvidence: evidence,
                fileManager: fileManager
            )
        }

        SplatPreviousResultEvidence.discardBackup(projectURL: projectURL, fileManager: fileManager)
        return Verification(url: expectedURL, sha256: verifiedDigest)
    }

    private static func recoverTrustedPreviousAndVerify(
        projectURL: URL,
        expectedURL: URL,
        evidenceURL: URL,
        failedEvidence: SplatCommitEvidence,
        fileManager: FileManager
    ) throws -> String {
        do {
            guard try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
                projectURL: projectURL,
                evidence: failedEvidence,
                fileManager: fileManager
            ), let restoredEvidence = loadValidEvidence(at: evidenceURL, fileManager: fileManager) else {
                throw VerificationError.completionEvidenceMismatch
            }
            return try SplatStrongCompletionEvidence.verifyOrSeal(
                sourceURL: expectedURL,
                evidence: restoredEvidence,
                fileManager: fileManager
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VerificationError.completionEvidenceMismatch
        }
    }

    private static func loadValidEvidence(
        at url: URL,
        fileManager: FileManager
    ) -> SplatCommitEvidence? {
        guard let data = readCompletionEvidenceIfSafe(at: url, fileManager: fileManager),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: data),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName,
              evidence.byteCount > 0,
              evidence.byteCount % 32 == 0 else {
            return nil
        }
        return evidence
    }

    private static func readCompletionEvidenceIfSafe(
        at url: URL,
        fileManager: FileManager
    ) -> Data? {
        guard isIndependentRegularFile(url),
              let evidenceByteCount = try? fileByteCount(url, fileManager: fileManager),
              evidenceByteCount >= 0,
              evidenceByteCount <= maximumCompletionEvidenceByteCount,
              let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        // The pre-read stat is only an early rejection. Keep the actual read bounded as well so a
        // corrupt or concurrently replaced completion record cannot become an unbounded allocation.
        guard let data = try? handle.read(upToCount: Int(maximumCompletionEvidenceByteCount) + 1),
              data.count <= Int(maximumCompletionEvidenceByteCount) else {
            return nil
        }
        return data
    }

    private static func isIndependentRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func isSymbolicLink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private static func fileByteCount(_ url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }
        return size.int64Value
    }

    private static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
