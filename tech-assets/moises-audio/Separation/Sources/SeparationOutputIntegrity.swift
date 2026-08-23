import Foundation

struct WAVInspection: Sendable {
    let sampleRate: Int
    let channels: Int
    let frameCount: Int64
    let durationSeconds: Double

    static func read(url: URL) throws -> WAVInspection {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_UNREADABLE", retryable: true) }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 12), header.count == 12,
              String(data: header[0..<4], encoding: .ascii) == "RIFF",
              String(data: header[8..<12], encoding: .ascii) == "WAVE" else {
            throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_INVALID", retryable: false)
        }
        var channels: Int?
        var sampleRate: Int?
        var blockAlign: Int?
        var dataBytes: Int64?
        while true {
            guard let raw = try? handle.read(upToCount: 8), !raw.isEmpty else { break }
            guard raw.count == 8 else { throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_TRUNCATED", retryable: false) }
            let id = String(data: raw[0..<4], encoding: .ascii) ?? ""
            let size = Int(raw.littleEndianUInt32(at: 4))
            if id == "fmt " {
                guard size >= 16, let fmt = try? handle.read(upToCount: size), fmt.count == size else { throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_TRUNCATED", retryable: false) }
                let audioFormat = fmt.littleEndianUInt16(at: 0)
                guard audioFormat == 1 || audioFormat == 3 else { throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_CODEC_UNSUPPORTED", retryable: false) }
                channels = Int(fmt.littleEndianUInt16(at: 2))
                sampleRate = Int(fmt.littleEndianUInt32(at: 4))
                blockAlign = Int(fmt.littleEndianUInt16(at: 12))
                if size % 2 == 1 { try? handle.seek(toOffset: handle.offsetInFile + 1) }
            } else if id == "data" {
                dataBytes = Int64(size)
                try? handle.seek(toOffset: handle.offsetInFile + UInt64(size + (size % 2)))
            } else {
                try? handle.seek(toOffset: handle.offsetInFile + UInt64(size + (size % 2)))
            }
            if channels != nil, sampleRate != nil, blockAlign != nil, dataBytes != nil { break }
        }
        guard let channels, let sampleRate, let blockAlign, let dataBytes,
              channels > 0, sampleRate > 0, blockAlign > 0, dataBytes > 0,
              dataBytes % Int64(blockAlign) == 0 else {
            throw DomainFailure.processingFailed(code: "SEP_OUTPUT_WAV_METADATA_INVALID", retryable: false)
        }
        let frames = dataBytes / Int64(blockAlign)
        return WAVInspection(sampleRate: sampleRate, channels: channels, frameCount: frames, durationSeconds: Double(frames) / Double(sampleRate))
    }
}

extension Data {
    func littleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[index(startIndex, offsetBy: offset)]) | (UInt16(self[index(startIndex, offsetBy: offset + 1)]) << 8)
    }
    func littleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(self[index(startIndex, offsetBy: offset)]) |
        (UInt32(self[index(startIndex, offsetBy: offset + 1)]) << 8) |
        (UInt32(self[index(startIndex, offsetBy: offset + 2)]) << 16) |
        (UInt32(self[index(startIndex, offsetBy: offset + 3)]) << 24)
    }
}

enum SHA256FileHasher {
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

    static func hash(url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw DomainFailure.processingFailed(code: "SEP_OUTPUT_HASH_READ_FAILED", retryable: true) }
        defer { try? handle.close() }
        var state = initial
        var buffer = Data()
        var totalBytes: UInt64 = 0
        while true {
            let data: Data
            do {
                guard let chunk = try handle.read(upToCount: 1024 * 1024) else { break }
                data = chunk
            } catch {
                throw DomainFailure.processingFailed(code: "SEP_OUTPUT_HASH_READ_FAILED", retryable: true)
            }
            if data.isEmpty { break }
            totalBytes += UInt64(data.count)
            buffer.append(data)
            while buffer.count >= 64 {
                compress(block: Data(buffer.prefix(64)), state: &state)
                buffer.removeFirst(64)
            }
        }
        let bitLength = totalBytes * 8
        buffer.append(0x80)
        while buffer.count % 64 != 56 { buffer.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) { buffer.append(UInt8((bitLength >> UInt64(shift)) & 0xff)) }
        while !buffer.isEmpty {
            compress(block: Data(buffer.prefix(64)), state: &state)
            buffer.removeFirst(64)
        }
        return state.map { String(format: "%08x", $0) }.joined()
    }

    private static func compress(block: Data, state: inout [UInt32]) {
        var w = Array(repeating: UInt32(0), count: 64)
        for i in 0..<16 {
            let o = i * 4
            w[i] = (UInt32(block[o]) << 24) | (UInt32(block[o+1]) << 16) | (UInt32(block[o+2]) << 8) | UInt32(block[o+3])
        }
        for i in 16..<64 {
            let s0 = rotateRight(w[i-15], 7) ^ rotateRight(w[i-15], 18) ^ (w[i-15] >> 3)
            let s1 = rotateRight(w[i-2], 17) ^ rotateRight(w[i-2], 19) ^ (w[i-2] >> 10)
            w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
        }
        var a=state[0], b=state[1], c=state[2], d=state[3], e=state[4], f=state[5], g=state[6], h=state[7]
        for i in 0..<64 {
            let s1 = rotateRight(e,6) ^ rotateRight(e,11) ^ rotateRight(e,25)
            let ch = (e & f) ^ ((~e) & g)
            let temp1 = h &+ s1 &+ ch &+ constants[i] &+ w[i]
            let s0 = rotateRight(a,2) ^ rotateRight(a,13) ^ rotateRight(a,22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = s0 &+ maj
            h=g; g=f; f=e; e=d &+ temp1; d=c; c=b; b=a; a=temp1 &+ temp2
        }
        state[0] = state[0] &+ a; state[1] = state[1] &+ b; state[2] = state[2] &+ c; state[3] = state[3] &+ d
        state[4] = state[4] &+ e; state[5] = state[5] &+ f; state[6] = state[6] &+ g; state[7] = state[7] &+ h
    }
    private static func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32 { (value >> amount) | (value << (32 - amount)) }
}
