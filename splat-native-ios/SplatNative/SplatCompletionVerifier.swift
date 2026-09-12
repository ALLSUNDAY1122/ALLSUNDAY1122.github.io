import Foundation

/// Verifies that a `.splat` is the atomically committed result of a finished local project.
///
/// Structural record alignment alone is not completion evidence: a process can be interrupted
/// after writing any whole number of 32-byte records. Export/share/view entry points must pass
/// through this verifier before treating a local result as user-owned completed data.
enum SplatCompletionVerifier {
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
        guard normalized(sourceURL) == normalized(expectedURL) else {
            throw VerificationError.unexpectedSource
        }

        let store = ScanProjectStore(
            rootURL: projectURL.deletingLastPathComponent(),
            fileManager: fileManager
        )
        guard let loadedManifest = try? store.loadManifest(projectURL: projectURL) else {
            throw VerificationError.projectNotFinished
        }

        // A failed/repeated reprocess may have exhausted Store's legacy `result.previous.splat`.
        // C2 can restore only the separately protected exact previous bytes whose SHA-256 matches
        // the snapshot captured while that result was still strictly trusted.
        let manifest = SplatPreviousResultEvidence.recoverTrustedPreviousIfNeeded(
            projectURL: projectURL,
            manifest: loadedManifest,
            fileManager: fileManager
        )
        guard manifest.stage == .finished,
              manifest.splatFileName == ScanProjectStore.splatResultFileName else {
            throw VerificationError.projectNotFinished
        }

        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard isIndependentRegularFile(evidenceURL),
              let evidenceData = try? Data(contentsOf: evidenceURL),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: evidenceData),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName,
              evidence.byteCount > 0,
              evidence.byteCount % 32 == 0 else {
            throw VerificationError.completionEvidenceMissing
        }

        // Do not reject a non-regular result before the strong verifier. It deliberately owns that
        // classification so a trusted protected backup can repair a replaced/symlinked result in
        // the integrity-failure recovery path below.
        guard fileManager.fileExists(atPath: expectedURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: expectedURL.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value == evidence.byteCount else {
            throw VerificationError.completionEvidenceMismatch
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
            // Structural recovery intentionally avoids a second hash on every healthy library open.
            // If the strong verifier finds same-size corruption and the exact commit still has a
            // protected SHA-bound backup, recover it now and immediately re-run the strong gate.
            do {
                guard try SplatPreviousResultEvidence.recoverTrustedPreviousAfterIntegrityFailure(
                    projectURL: projectURL,
                    evidence: evidence,
                    fileManager: fileManager
                ) else {
                    throw VerificationError.completionEvidenceMismatch
                }
                verifiedDigest = try SplatStrongCompletionEvidence.verifyOrSeal(
                    sourceURL: expectedURL,
                    evidence: evidence,
                    fileManager: fileManager
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw VerificationError.completionEvidenceMismatch
            }
        }

        SplatPreviousResultEvidence.discardBackup(projectURL: projectURL, fileManager: fileManager)
        return Verification(url: expectedURL, sha256: verifiedDigest)
    }

    private static func isIndependentRegularFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
