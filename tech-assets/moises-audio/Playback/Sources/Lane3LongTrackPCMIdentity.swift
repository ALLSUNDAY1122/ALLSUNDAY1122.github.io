import Foundation

// MARK: - Incremental SHA-256 compatible with AW13 SHA256_FLOAT32_LE_V1

private struct Lane3IncrementalSHA256 {
    private static let initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private static let constants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]

    private var state = initial
    private var partial: [UInt8] = []
    private var totalBytes: UInt64 = 0

    mutating func update(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { raw in
            updateRaw(raw)
        }
    }

    private mutating func updateRaw(_ bytes: UnsafeRawBufferPointer) {
        guard !bytes.isEmpty else { return }
        totalBytes &+= UInt64(bytes.count)
        var index = 0
        if !partial.isEmpty {
            let needed = 64 - partial.count
            let take = min(needed, bytes.count)
            if take > 0 {
                for offset in 0..<take {
                    partial.append(bytes[offset])
                }
                index += take
            }
            if partial.count == 64 {
                compress(partial)
                partial.removeAll(keepingCapacity: true)
            }
        }
        while index + 64 <= bytes.count {
            compressRaw(bytes, offset: index)
            index += 64
        }
        if index < bytes.count {
            for offset in index..<bytes.count {
                partial.append(bytes[offset])
            }
        }
    }

    mutating func updateStringField(_ string: String) {
        update(Array(string.utf8))
        update([0xff])
    }

    mutating func updateLittleEndian(_ value: UInt64, byteCount: Int) {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(byteCount)
        for offset in 0..<byteCount {
            bytes.append(UInt8(truncatingIfNeeded: value >> UInt64(offset * 8)))
        }
        update(bytes)
    }

    /// AW47: on all selected Apple/Linux little-endian targets, consume the existing Float array
    /// storage directly as canonical Float32 little-endian bytes. This removes the former per-PCM-chunk
    /// 4-bytes-per-Float conversion array while preserving SHA256_FLOAT32_LE_V1 byte-for-byte.
    mutating func updateFloat32LittleEndian(_ samples: [Float]) {
        #if _endian(little)
        samples.withUnsafeBufferPointer { buffer in
            updateRaw(UnsafeRawBufferPointer(buffer))
        }
        #else
        for sample in samples {
            updateLittleEndian(UInt64(sample.bitPattern), byteCount: 4)
        }
        #endif
    }

    mutating func finalizeHex() -> String {
        var tail = partial
        let bitLength = totalBytes &* 8
        tail.append(0x80)
        while tail.count % 64 != 56 { tail.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            tail.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }
        var index = 0
        while index < tail.count {
            compress(Array(tail[index..<(index + 64)]))
            index += 64
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32)
        for word in state {
            bytes.append(UInt8(truncatingIfNeeded: word >> 24))
            bytes.append(UInt8(truncatingIfNeeded: word >> 16))
            bytes.append(UInt8(truncatingIfNeeded: word >> 8))
            bytes.append(UInt8(truncatingIfNeeded: word))
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private mutating func compress(_ block: [UInt8]) {
        precondition(block.count == 64)
        block.withUnsafeBytes { raw in
            compressRaw(raw, offset: 0)
        }
    }

    private mutating func compressRaw(_ block: UnsafeRawBufferPointer, offset: Int) {
        precondition(offset >= 0 && offset + 64 <= block.count)
        var w = [UInt32](repeating: 0, count: 64)
        for index in 0..<16 {
            let blockOffset = offset + index * 4
            w[index] = (UInt32(block[blockOffset]) << 24)
                | (UInt32(block[blockOffset + 1]) << 16)
                | (UInt32(block[blockOffset + 2]) << 8)
                | UInt32(block[blockOffset + 3])
        }
        for index in 16..<64 {
            let s0 = rotateRight(w[index - 15], 7) ^ rotateRight(w[index - 15], 18) ^ (w[index - 15] >> 3)
            let s1 = rotateRight(w[index - 2], 17) ^ rotateRight(w[index - 2], 19) ^ (w[index - 2] >> 10)
            w[index] = w[index - 16] &+ s0 &+ w[index - 7] &+ s1
        }
        var a = state[0], b = state[1], c = state[2], d = state[3]
        var e = state[4], f = state[5], g = state[6], h = state[7]
        for index in 0..<64 {
            let s1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = h &+ s1 &+ ch &+ Self.constants[index] &+ w[index]
            let s0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 &+ maj
            h = g; g = f; f = e; e = d &+ temp1
            d = c; c = b; b = a; a = temp1 &+ temp2
        }
        state[0] &+= a; state[1] &+= b; state[2] &+= c; state[3] &+= d
        state[4] &+= e; state[5] &+= f; state[6] &+= g; state[7] &+= h
    }

    private func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
    }
}

public enum Lane3PCMIdentityStabilityError: Error, Equatable, Sendable {
    case sourceMetadataChanged
}

private struct Lane3PCMIdentityMetadataSnapshot: Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

    func exactlyMatches(_ other: Lane3PCMIdentityMetadataSnapshot) -> Bool {
        channels == other.channels
            && sampleRate.bitPattern == other.sampleRate.bitPattern
            && frameCount == other.frameCount
    }
}

public enum Lane3LongTrackPCMIdentityHasher {
    public static func makeReceipt(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        chunkFrames: Int = 16_384
    ) throws -> Lane3PCMIdentityReceipt {
        guard chunkFrames > 0 else {
            throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames)
        }
        let referenceMetadata = try captureStableMetadata(reference)
        let observedMetadata = try captureStableMetadata(observed)
        guard referenceMetadata.channels == observedMetadata.channels else {
            throw Lane3LongTrackEvidenceError.channelMismatch(
                expected: referenceMetadata.channels,
                actual: observedMetadata.channels
            )
        }
        guard abs(referenceMetadata.sampleRate - observedMetadata.sampleRate) <= 0.5 else {
            throw Lane3LongTrackEvidenceError.sampleRateMismatch(
                expected: referenceMetadata.sampleRate,
                actual: observedMetadata.sampleRate
            )
        }

        let referenceDigest = try digest(
            reference,
            chunkFrames: chunkFrames,
            expectedMetadata: referenceMetadata
        )
        let observedDigest = try digest(
            observed,
            chunkFrames: chunkFrames,
            expectedMetadata: observedMetadata
        )
        try requireMetadataStable(reference, expected: referenceMetadata)
        try requireMetadataStable(observed, expected: observedMetadata)

        return Lane3PCMIdentityReceipt(
            algorithm: "SHA256_FLOAT32_LE_V1",
            referenceDigestSHA256: referenceDigest,
            observedDigestSHA256: observedDigest,
            channels: referenceMetadata.channels,
            sampleRate: referenceMetadata.sampleRate,
            referenceFrameCount: referenceMetadata.frameCount,
            observedFrameCount: observedMetadata.frameCount
        )
    }

    static func digestFields(_ fields: [String]) -> String {
        var sha = Lane3IncrementalSHA256()
        sha.updateStringField("LANE3_UNIFIED_RUN_BINDING_V2")
        for field in fields { sha.updateStringField(field) }
        return sha.finalizeHex()
    }

    /// AW45-AW47 single-pass primitive. The caller observes each exact bounded PCM chunk while the
    /// canonical SHA256_FLOAT32_LE_V1 digest is updated from the same samples. AW46 freezes metadata;
    /// AW47 removes the additional PCM-to-byte chunk materialization on selected little-endian targets.
    static func digestWithChunkVisitor(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int,
        visit: (_ startFrame: Int64, _ frameCount: Int, _ samples: [Float]) throws -> Void
    ) throws -> String {
        guard chunkFrames > 0 else {
            throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames)
        }
        let metadata = try captureStableMetadata(source)
        return try digestWithChunkVisitor(
            source,
            chunkFrames: chunkFrames,
            expectedMetadata: metadata,
            visit: visit
        )
    }

    private static func digest(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int,
        expectedMetadata: Lane3PCMIdentityMetadataSnapshot
    ) throws -> String {
        try digestWithChunkVisitor(
            source,
            chunkFrames: chunkFrames,
            expectedMetadata: expectedMetadata
        ) { _, _, _ in }
    }

    private static func digestWithChunkVisitor(
        _ source: any Lane3PCMChunkReadable,
        chunkFrames: Int,
        expectedMetadata: Lane3PCMIdentityMetadataSnapshot,
        visit: (_ startFrame: Int64, _ frameCount: Int, _ samples: [Float]) throws -> Void
    ) throws -> String {
        guard chunkFrames > 0 else {
            throw Lane3LongTrackEvidenceError.invalidChunkFrames(chunkFrames)
        }
        guard expectedMetadata.channels > 0,
              expectedMetadata.sampleRate.isFinite,
              expectedMetadata.sampleRate > 0,
              expectedMetadata.frameCount > 0 else {
            throw Lane3LongTrackEvidenceError.invalidFormat
        }
        try requireMetadataStable(source, expected: expectedMetadata)

        var sha = Lane3IncrementalSHA256()
        sha.updateStringField("LANE3_PCM_IDENTITY_V1")
        sha.updateLittleEndian(UInt64(expectedMetadata.channels), byteCount: 8)
        sha.updateLittleEndian(expectedMetadata.sampleRate.bitPattern, byteCount: 8)
        sha.updateLittleEndian(UInt64(expectedMetadata.frameCount), byteCount: 8)
        let totalSamples = expectedMetadata.frameCount.multipliedReportingOverflow(
            by: Int64(expectedMetadata.channels)
        )
        guard !totalSamples.overflow, totalSamples.partialValue >= 0 else {
            throw Lane3LongTrackEvidenceError.integerOverflow
        }
        sha.updateLittleEndian(UInt64(totalSamples.partialValue), byteCount: 8)

        var frame: Int64 = 0
        while frame < expectedMetadata.frameCount {
            try requireMetadataStable(source, expected: expectedMetadata)
            let count = min(chunkFrames, Int(expectedMetadata.frameCount - frame))
            let expectedSamples64 = Int64(count).multipliedReportingOverflow(
                by: Int64(expectedMetadata.channels)
            )
            guard !expectedSamples64.overflow,
                  expectedSamples64.partialValue >= 0,
                  expectedSamples64.partialValue <= Int64(Int.max) else {
                throw Lane3LongTrackEvidenceError.integerOverflow
            }

            let samples: [Float]
            do {
                samples = try source.readInterleavedFrames(startFrame: frame, frameCount: count)
            } catch let error as Lane3LongTrackEvidenceError {
                throw error
            } catch let error as Lane3PCMIdentityStabilityError {
                throw error
            } catch {
                throw Lane3LongTrackEvidenceError.sourceReadFailed(String(describing: error))
            }
            try requireMetadataStable(source, expected: expectedMetadata)

            let expectedSamples = Int(expectedSamples64.partialValue)
            guard samples.count == expectedSamples else {
                throw Lane3LongTrackEvidenceError.shortRead(
                    expectedSamples: expectedSamples,
                    actualSamples: samples.count
                )
            }
            try visit(frame, count, samples)

            let byteCapacity = expectedSamples.multipliedReportingOverflow(by: MemoryLayout<Float>.stride)
            guard !byteCapacity.overflow, MemoryLayout<Float>.stride == 4 else {
                throw Lane3LongTrackEvidenceError.integerOverflow
            }
            sha.updateFloat32LittleEndian(samples)
            frame += Int64(count)
        }
        try requireMetadataStable(source, expected: expectedMetadata)
        return sha.finalizeHex()
    }

    private static func captureStableMetadata(
        _ source: any Lane3PCMChunkReadable
    ) throws -> Lane3PCMIdentityMetadataSnapshot {
        let first = currentMetadata(source)
        guard first.channels > 0,
              first.sampleRate.isFinite,
              first.sampleRate > 0,
              first.frameCount > 0 else {
            throw Lane3LongTrackEvidenceError.invalidFormat
        }
        let second = currentMetadata(source)
        guard first.exactlyMatches(second) else {
            throw Lane3PCMIdentityStabilityError.sourceMetadataChanged
        }
        return first
    }

    private static func requireMetadataStable(
        _ source: any Lane3PCMChunkReadable,
        expected: Lane3PCMIdentityMetadataSnapshot
    ) throws {
        guard expected.exactlyMatches(currentMetadata(source)) else {
            throw Lane3PCMIdentityStabilityError.sourceMetadataChanged
        }
    }

    private static func currentMetadata(
        _ source: any Lane3PCMChunkReadable
    ) -> Lane3PCMIdentityMetadataSnapshot {
        Lane3PCMIdentityMetadataSnapshot(
            channels: source.channels,
            sampleRate: source.sampleRate,
            frameCount: source.frameCount
        )
    }
}
