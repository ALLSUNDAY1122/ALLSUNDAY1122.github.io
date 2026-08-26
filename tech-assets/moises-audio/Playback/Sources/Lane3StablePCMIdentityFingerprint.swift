import Foundation

struct Lane3PCMIdentityFingerprint: Equatable, Sendable {
    let algorithm: String
    let digestSHA256: String
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64
}

private struct Lane3PCMIdentityExternalMetadataSnapshot: Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

    func exactlyMatches(_ other: Lane3PCMIdentityExternalMetadataSnapshot) -> Bool {
        channels == other.channels
            && sampleRate.bitPattern == other.sampleRate.bitPattern
            && frameCount == other.frameCount
    }
}

extension Lane3LongTrackPCMIdentityHasher {
    /// AW46 bridge for consumers that must build durable records from the exact metadata hashed with
    /// the PCM body. The wrapper independently freezes metadata around the AW45/AW46 traversal and
    /// rechecks the same snapshot inside the chunk visitor, preventing a caller from rereading mutable
    /// metadata after hashing and accidentally pairing it with a digest produced under another format.
    static func fingerprintWithChunkVisitor(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int,
        visit: (_ startFrame: Int64, _ frameCount: Int, _ samples: [Float]) throws -> Void
    ) throws -> Lane3PCMIdentityFingerprint {
        guard chunkFrames > 0 else {
            throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames)
        }
        let initial = try captureExternalStableMetadata(source)
        let digest = try digestWithChunkVisitor(source, chunkFrames: chunkFrames) { start, count, samples in
            try requireExternalMetadataStable(source, expected: initial)
            try visit(start, count, samples)
            try requireExternalMetadataStable(source, expected: initial)
        }
        try requireExternalMetadataStable(source, expected: initial)
        return Lane3PCMIdentityFingerprint(
            algorithm: "SHA256_FLOAT32_LE_V1",
            digestSHA256: digest,
            channels: initial.channels,
            sampleRate: initial.sampleRate,
            frameCount: initial.frameCount
        )
    }

    private static func captureExternalStableMetadata(
        _ source: any Lane3PCMChunkReadable
    ) throws -> Lane3PCMIdentityExternalMetadataSnapshot {
        let first = externalMetadata(source)
        guard first.channels > 0,
              first.sampleRate.isFinite,
              first.sampleRate > 0,
              first.frameCount > 0 else {
            throw Lane3LongTrackEvidenceError.invalidFormat
        }
        let second = externalMetadata(source)
        guard first.exactlyMatches(second) else {
            throw Lane3PCMIdentityStabilityError.sourceMetadataChanged
        }
        return first
    }

    private static func requireExternalMetadataStable(
        _ source: any Lane3PCMChunkReadable,
        expected: Lane3PCMIdentityExternalMetadataSnapshot
    ) throws {
        guard expected.exactlyMatches(externalMetadata(source)) else {
            throw Lane3PCMIdentityStabilityError.sourceMetadataChanged
        }
    }

    private static func externalMetadata(
        _ source: any Lane3PCMChunkReadable
    ) -> Lane3PCMIdentityExternalMetadataSnapshot {
        Lane3PCMIdentityExternalMetadataSnapshot(
            channels: source.channels,
            sampleRate: source.sampleRate,
            frameCount: source.frameCount
        )
    }
}
