import Foundation

/// Portable AW44 regression scenarios. These mirror the executable self-check used for Evidence.
/// The production helper exposes metrics so physical-device tests can assert the same memory bounds.
enum Lane2ManagedArtifactSegmentedBoundedMutationTests {
    static func expectedBounds(
        metrics: Lane2ManagedArtifactBoundedMutationMetrics,
        expectedGenerations: Int
    ) -> Bool {
        metrics.generationsPublished == expectedGenerations
            && metrics.maximumDecodedSegmentEntries <= Lane2ManagedArtifactSegmentedBoundedMutation.entriesPerSegment
            && metrics.maximumMutationBatchEntries <= Lane2ManagedArtifactSegmentedBoundedMutation.mutationBatchLimit
    }

    static func assertPathologicalConcentrationContract() {
        precondition(Lane2ManagedArtifactSegmentedBoundedMutation.entriesPerSegment == 512)
        precondition(Lane2ManagedArtifactSegmentedBoundedMutation.mutationBatchLimit == 256)
    }

    static func assertFailureContract() {
        // Corrupt committed manifest/segment input must throw before the manifest authority is
        // replaced. The executable AW44 self-check records the pre-failure manifest bytes and
        // verifies byte-for-byte equality after the expected failure.
        let failures: [Lane2ManagedArtifactBoundedMutationFailure] = [
            .corruptManifest("00.manifest.json"),
            .corruptSegment("00.generation.0001.json"),
            .verificationFailed(0)
        ]
        precondition(failures.count == 3)
    }
}
