import Foundation

@main
struct L3AW06OfflineExecutionSelfTest {
    static func main() throws {
        try deterministicPreflightAndNegativeCases()
        try streamingPCMStatisticsAndDigest()
        try stressValidation(iterations: 100_000)
        print("L3-AW06 offline execution preflight self-test PASS")
    }

    static func fixture() throws -> (
        Lane3ReferenceRenderRequest,
        Lane3ReferenceRenderPlan,
        [Lane3OfflineStemFileMetadata],
        Lane3OfflinePCMFormatDescriptor
    ) {
        let request = Lane3ReferenceRenderRequest(
            fixtureID: "aw06-portable-fixture",
            stems: [
                Lane3ReferenceStemDescriptor(
                    id: "vocals",
                    startSeconds: 0,
                    frameCount: 96_000,
                    sampleRate: 48_000,
                    gain: 0.8
                ),
                Lane3ReferenceStemDescriptor(
                    id: "drums",
                    startSeconds: 0,
                    frameCount: 96_000,
                    sampleRate: 48_000,
                    gain: 1.0
                )
            ],
            projectStartSeconds: 0,
            projectEndSeconds: 2,
            outputSampleRate: 48_000,
            practice: Lane3ReferencePracticeSettings(
                tempoRatio: 1,
                pitchSemitones: 2,
                metronomeEnabled: true,
                countInClicks: 2,
                downbeatStride: 4
            ),
            beatTimesSeconds: [0, 0.5, 1, 1.5],
            countInBeatIntervalSeconds: 0.5
        )
        let plan = try Lane3OfflineReferencePlanner.makePlan(request)
        let metadata = [
            Lane3OfflineStemFileMetadata(
                stemID: "vocals",
                sampleRate: 48_000,
                frameCount: 96_000,
                channels: 2
            ),
            Lane3OfflineStemFileMetadata(
                stemID: "drums",
                sampleRate: 48_000,
                frameCount: 96_000,
                channels: 2
            )
        ]
        return (
            request,
            plan,
            metadata,
            Lane3OfflinePCMFormatDescriptor(sampleRate: 48_000, channels: 1)
        )
    }

    static func deterministicPreflightAndNegativeCases() throws {
        let (request, plan, metadata, clickFormat) = try fixture()
        let manifest = try Lane3OfflineExecutionValidator.makeManifest(
            request: request,
            plan: plan,
            stemMetadata: metadata,
            clickPCMFormat: clickFormat
        )
        precondition(manifest.expectedStemIDs == ["drums", "vocals"])
        precondition(manifest.renderWindowCount == 2)
        precondition(manifest.clickEventCount == 6)
        precondition(manifest.requiresClickPCM)
        precondition(!manifest.parityPromotionAllowed)

        do {
            _ = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: Array(metadata.dropLast()),
                clickPCMFormat: clickFormat
            )
            preconditionFailure("missing stem metadata must fail")
        } catch Lane3OfflineExecutionError.missingStemMetadata("drums") {
        }

        do {
            _ = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: metadata + [
                    Lane3OfflineStemFileMetadata(
                        stemID: "other",
                        sampleRate: 48_000,
                        frameCount: 96_000,
                        channels: 2
                    )
                ],
                clickPCMFormat: clickFormat
            )
            preconditionFailure("unexpected stem metadata must fail")
        } catch Lane3OfflineExecutionError.unexpectedStemMetadata("other") {
        }

        do {
            _ = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: metadata,
                clickPCMFormat: nil
            )
            preconditionFailure("click PCM is required when click events exist")
        } catch Lane3OfflineExecutionError.clickPCMRequired {
        }

        var shortMetadata = metadata
        shortMetadata[0] = Lane3OfflineStemFileMetadata(
            stemID: "vocals",
            sampleRate: 48_000,
            frameCount: 95_999,
            channels: 2
        )
        do {
            _ = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: shortMetadata,
                clickPCMFormat: clickFormat
            )
            preconditionFailure("source render window may not exceed actual file length")
        } catch Lane3OfflineExecutionError.sourceWindowOutOfBounds("vocals") {
        }

        do {
            _ = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: metadata,
                clickPCMFormat: Lane3OfflinePCMFormatDescriptor(
                    sampleRate: 44_100,
                    channels: 1
                )
            )
            preconditionFailure("click sample-rate mismatch must fail")
        } catch Lane3OfflineExecutionError.invalidClickPCMFormat {
        }
    }

    static func streamingPCMStatisticsAndDigest() throws {
        var accumulator = try Lane3StreamingPCMAccumulator(
            channels: 2,
            sampleRate: 48_000
        )
        try accumulator.consume(
            interleavedSamples: [
                1, -1,
                0.5, -0.5,
                Float.nan, 0
            ]
        )
        let summary = accumulator.summary()
        let digest = accumulator.digest()
        precondition(summary.frameCount == 3)
        precondition(summary.nonFiniteSampleCount == 1)
        precondition(abs(summary.peakAbsolute - 1) < 1e-12)
        precondition(digest.frameCount == 3)
        precondition(digest.firstNonSilentFrame == 0)
        precondition(digest.lastNonSilentFrame == 1)
        precondition(digest.clippedSampleCount == 0)
        precondition(digest.sampleFingerprintFNV1A64.count == 16)

        do {
            try accumulator.consume(interleavedSamples: [0])
            preconditionFailure("partial interleaved frame must fail")
        } catch Lane3OfflineExecutionError.invalidPCMChunk {
        }
    }

    static func stressValidation(iterations: Int) throws {
        let (request, plan, metadata, clickFormat) = try fixture()
        for _ in 0..<iterations {
            let manifest = try Lane3OfflineExecutionValidator.makeManifest(
                request: request,
                plan: plan,
                stemMetadata: metadata,
                clickPCMFormat: clickFormat
            )
            precondition(manifest.controlSignatureFNV1A64 == plan.controlSignatureFNV1A64)
        }
    }
}
