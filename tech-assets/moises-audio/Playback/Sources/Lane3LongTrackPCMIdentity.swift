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
        guard !bytes.isEmpty else { return }
        totalBytes &+= UInt64(bytes.count)
        var index = 0
        if !partial.isEmpty {
            let needed = 64 - partial.count
            let take = min(needed, bytes.count)
            partial.append(contentsOf: bytes[0..<take])
            index += take
            if partial.count == 64 {
                compress(partial)
                partial.removeAll(keepingCapacity: true)
            }
        }
        while index + 64 <= bytes.count {
            compress(Array(bytes[index..<(index + 64)]))
            index += 64
        }
        if index < bytes.count {
            partial.append(contentsOf: bytes[index..<bytes.count])
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
        var w = [UInt32](repeating: 0, count: 64)
        for index in 0..<16 {
            let offset = index * 4
            w[index] = (UInt32(block[offset]) << 24)
                | (UInt32(block[offset + 1]) << 16)
                | (UInt32(block[offset + 2]) << 8)
                | UInt32(block[offset + 3])
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

public enum Lane3LongTrackPCMIdentityHasher {
    public static func makeReceipt(
        reference: any Lane3PCMChunkReadable,
        observed: any Lane3PCMChunkReadable,
        chunkFrames: Int = 16_384
    ) throws -> Lane3PCMIdentityReceipt {
        _ = try Lane3LongTrackPCMAccess.validatePair(reference: reference, observed: observed, chunkFrames: chunkFrames)
        return Lane3PCMIdentityReceipt(
            algorithm: "SHA256_FLOAT32_LE_V1",
            referenceDigestSHA256: try digest(reference, chunkFrames: chunkFrames),
            observedDigestSHA256: try digest(observed, chunkFrames: chunkFrames),
            channels: reference.channels,
            sampleRate: reference.sampleRate,
            referenceFrameCount: reference.frameCount,
            observedFrameCount: observed.frameCount
        )
    }

    static func digestFields(_ fields: [String]) -> String {
        var sha = Lane3IncrementalSHA256()
        sha.updateStringField("LANE3_UNIFIED_RUN_BINDING_V2")
        for field in fields { sha.updateStringField(field) }
        return sha.finalizeHex()
    }

    private static func digest(_ source: any Lane3PCMChunkReadable, chunkFrames: Int) throws -> String {
        guard source.channels > 0, source.sampleRate.isFinite, source.sampleRate > 0, source.frameCount > 0 else {
            throw Lane3LongTrackEvidenceError.invalidFormat
        }
        var sha = Lane3IncrementalSHA256()
        sha.updateStringField("LANE3_PCM_IDENTITY_V1")
        sha.updateLittleEndian(UInt64(source.channels), byteCount: 8)
        sha.updateLittleEndian(source.sampleRate.bitPattern, byteCount: 8)
        sha.updateLittleEndian(UInt64(source.frameCount), byteCount: 8)
        let totalSamples = source.frameCount.multipliedReportingOverflow(by: Int64(source.channels))
        guard !totalSamples.overflow, totalSamples.partialValue >= 0 else {
            throw Lane3LongTrackEvidenceError.integerOverflow
        }
        sha.updateLittleEndian(UInt64(totalSamples.partialValue), byteCount: 8)

        var frame: Int64 = 0
        while frame < source.frameCount {
            let count = min(chunkFrames, Int(source.frameCount - frame))
            let samples = try Lane3LongTrackPCMAccess.readInterleaved(source, start: frame, count: count)
            var bytes: [UInt8] = []
            bytes.reserveCapacity(samples.count * 4)
            for sample in samples {
                let bits = sample.bitPattern
                bytes.append(UInt8(truncatingIfNeeded: bits))
                bytes.append(UInt8(truncatingIfNeeded: bits >> 8))
                bytes.append(UInt8(truncatingIfNeeded: bits >> 16))
                bytes.append(UInt8(truncatingIfNeeded: bits >> 24))
            }
            sha.update(bytes)
            frame += Int64(count)
        }
        return sha.finalizeHex()
    }
}
