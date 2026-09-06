import Foundation

struct WAVInspection: Sendable {
    let sampleRate: Int
    let channels: Int
    let frameCount: Int64
    let durationSeconds: Double
    let audioFormat: UInt16
    let bitsPerSample: Int
    let dataByteCount: Int64
    let fileByteCount: Int64
    let analyzedSampleCount: Int64
    let absolutePeak: Double
    let rms: Double
    let zeroSampleFraction: Double
    let clippedSampleFraction: Double
    let samplePathologyFlags: [String]

    static func read(url: URL) throws -> WAVInspection {
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let number = attributes[.size] as? NSNumber else {
                throw failure("SEP_OUTPUT_FILE_STAT_FAILED", true)
            }
            fileSize = number.int64Value
        } catch let error as DomainFailure {
            throw error
        } catch {
            throw failure("SEP_OUTPUT_FILE_STAT_FAILED", true)
        }
        guard fileSize >= 44 else { throw failure("SEP_OUTPUT_WAV_TRUNCATED", false) }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw failure("SEP_OUTPUT_WAV_UNREADABLE", true)
        }
        defer { try? handle.close() }

        let header = try readExact(handle, count: 12, code: "SEP_OUTPUT_WAV_TRUNCATED")
        guard String(data: header[0..<4], encoding: .ascii) == "RIFF",
              String(data: header[8..<12], encoding: .ascii) == "WAVE" else {
            throw failure("SEP_OUTPUT_WAV_INVALID", false)
        }
        let riffPayloadSize = Int64(header.littleEndianUInt32(at: 4))
        let declaredFileSize = riffPayloadSize + 8
        guard declaredFileSize == fileSize else {
            throw failure("SEP_OUTPUT_RIFF_SIZE_MISMATCH", false)
        }

        var rawAudioFormat: UInt16?
        var resolvedAudioFormat: UInt16?
        var channels: Int?
        var sampleRate: Int?
        var byteRate: Int?
        var blockAlign: Int?
        var bitsPerSample: Int?
        var dataOffset: UInt64?
        var dataBytes: Int64?
        var fmtCount = 0
        var dataCount = 0

        let riffEnd = UInt64(declaredFileSize)
        while handle.offsetInFile < riffEnd {
            let remaining = riffEnd - handle.offsetInFile
            guard remaining >= 8 else { throw failure("SEP_OUTPUT_WAV_TRUNCATED", false) }
            let raw = try readExact(handle, count: 8, code: "SEP_OUTPUT_WAV_TRUNCATED")
            let id = String(data: raw[0..<4], encoding: .ascii) ?? ""
            let size = Int(raw.littleEndianUInt32(at: 4))
            let payloadStart = handle.offsetInFile
            let paddedSize = UInt64(size + (size % 2))
            guard payloadStart <= riffEnd, paddedSize <= riffEnd - payloadStart else {
                throw failure("SEP_OUTPUT_WAV_CHUNK_OVERRUN", false)
            }

            if id == "fmt " {
                fmtCount += 1
                guard fmtCount == 1 else { throw failure("SEP_OUTPUT_WAV_DUPLICATE_FMT", false) }
                guard size >= 16, size <= 1024 else { throw failure("SEP_OUTPUT_WAV_FMT_INVALID", false) }
                let fmt = try readExact(handle, count: size, code: "SEP_OUTPUT_WAV_TRUNCATED")
                let format = fmt.littleEndianUInt16(at: 0)
                rawAudioFormat = format
                channels = Int(fmt.littleEndianUInt16(at: 2))
                sampleRate = Int(fmt.littleEndianUInt32(at: 4))
                byteRate = Int(fmt.littleEndianUInt32(at: 8))
                blockAlign = Int(fmt.littleEndianUInt16(at: 12))
                bitsPerSample = Int(fmt.littleEndianUInt16(at: 14))
                if format == 0xFFFE {
                    guard size >= 40 else { throw failure("SEP_OUTPUT_WAV_EXTENSIBLE_INVALID", false) }
                    let cbSize = Int(fmt.littleEndianUInt16(at: 16))
                    guard cbSize >= 22 else { throw failure("SEP_OUTPUT_WAV_EXTENSIBLE_INVALID", false) }
                    resolvedAudioFormat = fmt.littleEndianUInt16(at: 24)
                } else {
                    resolvedAudioFormat = format
                }
            } else if id == "data" {
                dataCount += 1
                guard dataCount == 1 else { throw failure("SEP_OUTPUT_WAV_DUPLICATE_DATA", false) }
                guard size > 0 else { throw failure("SEP_OUTPUT_EMPTY", false) }
                dataOffset = payloadStart
                dataBytes = Int64(size)
                try seek(handle, to: payloadStart + UInt64(size), code: "SEP_OUTPUT_WAV_TRUNCATED")
            } else {
                try seek(handle, to: payloadStart + UInt64(size), code: "SEP_OUTPUT_WAV_TRUNCATED")
            }
            if size % 2 == 1 {
                _ = try readExact(handle, count: 1, code: "SEP_OUTPUT_WAV_TRUNCATED")
            }
        }

        guard handle.offsetInFile == riffEnd else { throw failure("SEP_OUTPUT_WAV_TRUNCATED", false) }
        guard fmtCount == 1 else { throw failure("SEP_OUTPUT_WAV_FMT_MISSING", false) }
        guard dataCount == 1 else { throw failure("SEP_OUTPUT_WAV_DATA_MISSING", false) }
        guard let rawAudioFormat, let audioFormat = resolvedAudioFormat,
              let channels, let sampleRate, let byteRate, let blockAlign, let bitsPerSample,
              let dataOffset, let dataBytes else {
            throw failure("SEP_OUTPUT_WAV_METADATA_INVALID", false)
        }
        guard audioFormat == 1 || audioFormat == 3 else {
            throw failure("SEP_OUTPUT_WAV_CODEC_UNSUPPORTED", false)
        }
        guard channels > 0, channels <= 64,
              sampleRate >= 8_000, sampleRate <= 384_000,
              blockAlign > 0, bitsPerSample > 0 else {
            throw failure("SEP_OUTPUT_WAV_METADATA_INVALID", false)
        }
        let supportedBits = audioFormat == 1 ? Set([8, 16, 24, 32]) : Set([32, 64])
        guard supportedBits.contains(bitsPerSample) else {
            throw failure("SEP_OUTPUT_WAV_SAMPLE_FORMAT_UNSUPPORTED", false)
        }
        let expectedBlockAlign = channels * bitsPerSample / 8
        guard bitsPerSample % 8 == 0, blockAlign == expectedBlockAlign else {
            throw failure("SEP_OUTPUT_WAV_BLOCK_ALIGN_INVALID", false)
        }
        guard byteRate == sampleRate * blockAlign else {
            throw failure("SEP_OUTPUT_WAV_BYTE_RATE_INVALID", false)
        }
        guard dataBytes > 0, dataBytes % Int64(blockAlign) == 0 else {
            throw failure("SEP_OUTPUT_WAV_DATA_ALIGNMENT_INVALID", false)
        }

        let frames = dataBytes / Int64(blockAlign)
        guard frames > 0 else { throw failure("SEP_OUTPUT_WAV_METADATA_INVALID", false) }
        let stats = try scanSamples(
            handle: handle,
            offset: dataOffset,
            byteCount: dataBytes,
            audioFormat: audioFormat,
            bitsPerSample: bitsPerSample,
            channels: channels
        )
        guard stats.sampleCount == frames * Int64(channels) else {
            throw failure("SEP_OUTPUT_WAV_SAMPLE_COUNT_MISMATCH", false)
        }

        var flags: [String] = []
        if stats.absolutePeak <= 1e-12 { flags.append("DIGITAL_SILENCE") }
        else if stats.rms <= 1e-5 { flags.append("NEAR_SILENCE") }
        if stats.sampleCount >= 1024 && stats.clippedFraction >= 0.999 {
            flags.append("PATHOLOGICAL_CLIPPING")
        }

        _ = rawAudioFormat
        return WAVInspection(
            sampleRate: sampleRate,
            channels: channels,
            frameCount: frames,
            durationSeconds: Double(frames) / Double(sampleRate),
            audioFormat: audioFormat,
            bitsPerSample: bitsPerSample,
            dataByteCount: dataBytes,
            fileByteCount: fileSize,
            analyzedSampleCount: stats.sampleCount,
            absolutePeak: stats.absolutePeak,
            rms: stats.rms,
            zeroSampleFraction: stats.zeroFraction,
            clippedSampleFraction: stats.clippedFraction,
            samplePathologyFlags: flags
        )
    }

    private struct SampleStats {
        let sampleCount: Int64
        let absolutePeak: Double
        let rms: Double
        let zeroFraction: Double
        let clippedFraction: Double
    }

    private static func scanSamples(
        handle: FileHandle,
        offset: UInt64,
        byteCount: Int64,
        audioFormat: UInt16,
        bitsPerSample: Int,
        channels: Int
    ) throws -> SampleStats {
        try seek(handle, to: offset, code: "SEP_OUTPUT_WAV_TRUNCATED")
        let bytesPerSample = bitsPerSample / 8
        let blockAlign = bytesPerSample * channels
        let chunkTarget = max(blockAlign, (1024 * 1024 / blockAlign) * blockAlign)
        var remaining = byteCount
        var sampleCount: Int64 = 0
        var zeroCount: Int64 = 0
        var clippedCount: Int64 = 0
        var peak = 0.0
        var sumSquares = 0.0

        while remaining > 0 {
            let request = Int(min(Int64(chunkTarget), remaining))
            let data = try readExact(handle, count: request, code: "SEP_OUTPUT_WAV_TRUNCATED")
            guard data.count % bytesPerSample == 0 else {
                throw failure("SEP_OUTPUT_WAV_DATA_ALIGNMENT_INVALID", false)
            }
            var index = 0
            while index < data.count {
                let sample: Double
                if audioFormat == 1 {
                    switch bitsPerSample {
                    case 8:
                        sample = Double(Int(data[index]) - 128) / 128.0
                    case 16:
                        let raw = data.littleEndianUInt16(at: index)
                        sample = Double(Int16(bitPattern: raw)) / 32768.0
                    case 24:
                        var raw = Int32(data[index]) | (Int32(data[index + 1]) << 8) | (Int32(data[index + 2]) << 16)
                        if raw & 0x0080_0000 != 0 { raw |= ~0x00FF_FFFF }
                        sample = Double(raw) / 8_388_608.0
                    case 32:
                        let raw = data.littleEndianUInt32(at: index)
                        sample = Double(Int32(bitPattern: raw)) / 2_147_483_648.0
                    default:
                        throw failure("SEP_OUTPUT_WAV_SAMPLE_FORMAT_UNSUPPORTED", false)
                    }
                } else {
                    switch bitsPerSample {
                    case 32:
                        sample = Double(Float(bitPattern: data.littleEndianUInt32(at: index)))
                    case 64:
                        sample = Double(bitPattern: data.littleEndianUInt64(at: index))
                    default:
                        throw failure("SEP_OUTPUT_WAV_SAMPLE_FORMAT_UNSUPPORTED", false)
                    }
                    guard sample.isFinite else {
                        throw failure("SEP_OUTPUT_WAV_NONFINITE_SAMPLE", false)
                    }
                    guard abs(sample) <= 16.0 else {
                        throw failure("SEP_OUTPUT_WAV_FLOAT_SAMPLE_RANGE_INVALID", false)
                    }
                }

                let magnitude = abs(sample)
                peak = max(peak, magnitude)
                if sample == 0 { zeroCount += 1 }
                if magnitude >= 0.999 { clippedCount += 1 }
                sumSquares += sample * sample
                guard sumSquares.isFinite else {
                    throw failure("SEP_OUTPUT_WAV_NUMERIC_ACCUMULATION_INVALID", false)
                }
                sampleCount += 1
                index += bytesPerSample
            }
            remaining -= Int64(data.count)
        }
        guard sampleCount > 0 else { throw failure("SEP_OUTPUT_EMPTY", false) }
        return SampleStats(
            sampleCount: sampleCount,
            absolutePeak: peak,
            rms: sqrt(sumSquares / Double(sampleCount)),
            zeroFraction: Double(zeroCount) / Double(sampleCount),
            clippedFraction: Double(clippedCount) / Double(sampleCount)
        )
    }

    private static func readExact(_ handle: FileHandle, count: Int, code: String) throws -> Data {
        guard count >= 0 else { throw failure(code, false) }
        if count == 0 { return Data() }
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            do {
                guard let chunk = try handle.read(upToCount: count - result.count), !chunk.isEmpty else {
                    throw failure(code, false)
                }
                result.append(chunk)
            } catch let error as DomainFailure {
                throw error
            } catch {
                throw failure(code, false)
            }
        }
        return result
    }

    private static func seek(_ handle: FileHandle, to offset: UInt64, code: String) throws {
        do { try handle.seek(toOffset: offset) }
        catch { throw failure(code, false) }
    }

    private static func failure(_ code: String, _ retryable: Bool) -> DomainFailure {
        .processingFailed(code: code, retryable: retryable)
    }
}

extension Data {
    func littleEndianUInt16(at offset: Int) -> UInt16 {
        UInt16(self[index(startIndex, offsetBy: offset)]) |
        (UInt16(self[index(startIndex, offsetBy: offset + 1)]) << 8)
    }

    func littleEndianUInt32(at offset: Int) -> UInt32 {
        UInt32(self[index(startIndex, offsetBy: offset)]) |
        (UInt32(self[index(startIndex, offsetBy: offset + 1)]) << 8) |
        (UInt32(self[index(startIndex, offsetBy: offset + 2)]) << 16) |
        (UInt32(self[index(startIndex, offsetBy: offset + 3)]) << 24)
    }

    func littleEndianUInt64(at offset: Int) -> UInt64 {
        UInt64(littleEndianUInt32(at: offset)) | (UInt64(littleEndianUInt32(at: offset + 4)) << 32)
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
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw DomainFailure.processingFailed(code: "SEP_OUTPUT_HASH_READ_FAILED", retryable: true)
        }
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
        for shift in stride(from: 56, through: 0, by: -8) {
            buffer.append(UInt8((bitLength >> UInt64(shift)) & 0xff))
        }
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

    private static func rotateRight(_ value: UInt32, _ amount: UInt32) -> UInt32 {
        (value >> amount) | (value << (32 - amount))
    }
}
