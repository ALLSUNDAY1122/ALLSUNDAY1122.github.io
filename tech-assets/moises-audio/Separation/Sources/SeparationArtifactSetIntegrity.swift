import Foundation

enum SeparationArtifactSetIntegrity {
    static func validate(
        _ manifest: SeparationProviderRunManifest,
        durationToleranceSeconds: Double = 0.020
    ) throws {
        guard durationToleranceSeconds.isFinite, durationToleranceSeconds >= 0 else {
            throw failure("SEP_OUTPUT_TIMING_TOLERANCE_INVALID", false)
        }
        guard !manifest.outputs.isEmpty else {
            throw failure("SEP_OUTPUT_COUNT_MISMATCH", false)
        }

        var sampleRates: [Double] = []
        var frameCounts: [Int64] = []
        var durations: [Double] = []
        sampleRates.reserveCapacity(manifest.outputs.count)
        frameCounts.reserveCapacity(manifest.outputs.count)
        durations.reserveCapacity(manifest.outputs.count)

        for output in manifest.outputs {
            let declaredContainer = output.container.lowercased()
            guard declaredContainer == "wav" || declaredContainer == "wave" else {
                throw failure("SEP_OUTPUT_CONTAINER_UNSUPPORTED", false)
            }
            let extensionValue = output.downloadURL.pathExtension.lowercased()
            if !extensionValue.isEmpty && extensionValue != "wav" && extensionValue != "wave" {
                throw failure("SEP_OUTPUT_EXTENSION_CONTAINER_MISMATCH", false)
            }
            guard output.sampleRate.isFinite, output.sampleRate >= 8_000, output.sampleRate <= 384_000,
                  output.frameCount > 0,
                  output.durationSeconds.isFinite, output.durationSeconds > 0 else {
                throw failure("SEP_OUTPUT_TIMING_METADATA_INVALID", false)
            }
            let derived = Double(output.frameCount) / output.sampleRate
            guard abs(derived - output.durationSeconds) <= durationToleranceSeconds else {
                throw failure("SEP_OUTPUT_DECLARED_DURATION_INCONSISTENT", false)
            }
            sampleRates.append(output.sampleRate)
            frameCounts.append(output.frameCount)
            durations.append(output.durationSeconds)
        }

        guard let baselineRate = sampleRates.first,
              let baselineFrames = frameCounts.first,
              let baselineDuration = durations.first else { return }

        for index in manifest.outputs.indices.dropFirst() {
            guard abs(sampleRates[index] - baselineRate) < 0.5 else {
                throw failure("SEP_OUTPUT_SET_SAMPLE_RATE_MISMATCH", false)
            }
            let allowedFrameDelta = max(
                Int64(1),
                Int64(ceil(max(sampleRates[index], baselineRate) * durationToleranceSeconds))
            )
            guard abs(frameCounts[index] - baselineFrames) <= allowedFrameDelta else {
                throw failure("SEP_OUTPUT_SET_FRAME_ALIGNMENT_MISMATCH", false)
            }
            guard abs(durations[index] - baselineDuration) <= durationToleranceSeconds else {
                throw failure("SEP_OUTPUT_SET_DURATION_MISMATCH", false)
            }
        }
    }

    /// A cached prepared/committed ledger is trusted only for the same logical artifact identity.
    /// Signed URLs/expiry/cost telemetry may legitimately rotate, but provider/model/profile,
    /// requested roles and each role-to-stem identity must remain stable for the same job.
    static func validateCachedManifestIdentity(
        _ current: SeparationProviderRunManifest,
        trusted: SeparationProviderRunManifest
    ) throws {
        guard current.projectID == trusted.projectID, current.jobID == trusted.jobID else {
            throw failure("SEP_OUTPUT_CACHED_MANIFEST_JOB_IDENTITY_MISMATCH", false)
        }
        guard current.providerID == trusted.providerID,
              current.providerKind == trusted.providerKind,
              current.modelName == trusted.modelName,
              current.modelVersion == trusted.modelVersion,
              current.qualityProfile == trusted.qualityProfile else {
            throw failure("SEP_OUTPUT_CACHED_MANIFEST_PROVIDER_IDENTITY_MISMATCH", false)
        }
        guard current.requestedRoles == trusted.requestedRoles else {
            throw failure("SEP_OUTPUT_CACHED_MANIFEST_ROLE_SET_MISMATCH", false)
        }
        guard current.outputs.count == trusted.outputs.count else {
            throw failure("SEP_OUTPUT_CACHED_MANIFEST_STEM_IDENTITY_MISMATCH", false)
        }
        for output in current.outputs {
            guard trusted.outputs.contains(where: { $0.role == output.role && $0.stemID == output.stemID }) else {
                throw failure("SEP_OUTPUT_CACHED_MANIFEST_STEM_IDENTITY_MISMATCH", false)
            }
        }
    }

    private static func failure(_ code: String, _ retryable: Bool) -> DomainFailure {
        .processingFailed(code: code, retryable: retryable)
    }
}
