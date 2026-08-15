import Foundation

/// Verifies that a `.splat` is the atomically committed result of a finished local project.
///
/// Structural record alignment alone is not completion evidence: a process can be interrupted
/// after writing any whole number of 32-byte records. Export/share entry points must pass through
/// this verifier before treating a local result as user-owned completed data.
enum SplatCompletionVerifier {
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
        guard let manifest = try? store.loadManifest(projectURL: projectURL),
              manifest.stage == .finished,
              manifest.splatFileName == ScanProjectStore.splatResultFileName else {
            throw VerificationError.projectNotFinished
        }

        let evidenceURL = projectURL.appendingPathComponent(ScanProjectStore.splatCommitEvidenceFileName)
        guard let evidenceData = try? Data(contentsOf: evidenceURL),
              let evidence = try? JSONDecoder().decode(SplatCommitEvidence.self, from: evidenceData),
              evidence.schemaVersion == SplatCommitEvidence.currentSchemaVersion,
              evidence.fileName == ScanProjectStore.splatResultFileName,
              evidence.byteCount > 0,
              evidence.byteCount % 32 == 0 else {
            throw VerificationError.completionEvidenceMissing
        }

        guard fileManager.fileExists(atPath: expectedURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: expectedURL.path),
              let size = attributes[.size] as? NSNumber,
              size.int64Value == evidence.byteCount else {
            throw VerificationError.completionEvidenceMismatch
        }

        return expectedURL
    }

    private static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
