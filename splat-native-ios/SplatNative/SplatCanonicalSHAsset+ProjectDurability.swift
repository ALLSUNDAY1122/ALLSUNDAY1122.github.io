import Foundation
import Msplat

extension SplatCanonicalSHAsset {
    static let manifestOutputKeyPrefix = "splatSH3Canonical."
    static let abandonedCandidateAge: TimeInterval = 24 * 60 * 60

    enum DurabilityError: LocalizedError {
        case lossyFingerprintCollision
        case incompleteCanonicalPayload

        var errorDescription: String? {
            switch self {
            case .lossyFingerprintCollision:
                return "同じlegacy .splat識別子に異なるSH3内容が検出されたため、安全のため再生成結果を確定しませんでした。"
            case .incompleteCanonicalPayload:
                return "SH3 canonical asset の点データが途中で欠損しているため、安全のため確定しませんでした。"
            }
        }
    }

    static func persistCollisionSafe(
        from trainer: Msplat.GaussianTrainer,
        legacySplatURL: URL,
        expectedPointCount: Int
    ) throws -> Asset {
        let targetURL = try canonicalURL(forLegacySplat: legacySplatURL)
        let directoryURL = targetURL.deletingLastPathComponent()
        pruneAbandonedCandidates(in: directoryURL)

        let temporaryURL = directoryURL
            .appendingPathComponent(".\(targetURL.lastPathComponent).\(UUID().uuidString).candidate.ply")
        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            trainer.exportPly(to: temporaryURL.path)
            return try installCollisionSafeTemporaryPLY(
                temporaryURL,
                targetURL: targetURL,
                expectedPointCount: expectedPointCount
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    static func installCollisionSafeTemporaryPLY(
        _ temporaryURL: URL,
        targetURL: URL,
        expectedPointCount: Int
    ) throws -> Asset {
        let candidate = try inspectPLY(temporaryURL)
        guard candidate.pointCount == expectedPointCount else {
            throw CanonicalError.pointCountMismatch(expected: expectedPointCount, actual: candidate.pointCount)
        }
        guard candidate.shDegree == requiredSHDegree else {
            throw CanonicalError.shDegreeMismatch(expected: requiredSHDegree, actual: candidate.shDegree)
        }
        guard hasCompleteVertexPayload(at: temporaryURL, expectedPointCount: expectedPointCount) else {
            throw DurabilityError.incompleteCanonicalPayload
        }

        if FileManager.default.fileExists(atPath: targetURL.path) {
            if let existing = try? inspectPLY(targetURL),
               existing.pointCount == expectedPointCount,
               existing.shDegree == requiredSHDegree,
               hasCompleteVertexPayload(at: targetURL, expectedPointCount: expectedPointCount) {
                guard try SplatExportService.sha256Hex(fileURL: targetURL) ==
                        SplatExportService.sha256Hex(fileURL: temporaryURL) else {
                    throw DurabilityError.lossyFingerprintCollision
                }
                try? FileManager.default.removeItem(at: temporaryURL)
                return Asset(url: targetURL, descriptor: existing)
            }

            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: temporaryURL)
            return Asset(url: targetURL, descriptor: candidate)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
        return Asset(url: targetURL, descriptor: candidate)
    }

    /// Returns a canonical SH asset only when both its schema and declared binary vertex payload
    /// are complete. Viewer/export admission use this stricter resolver so a header-valid but
    /// truncated PLY cannot replace the known-good legacy `.splat` fallback.
    static func existingCompleteAsset(
        forLegacySplat legacySplatURL: URL,
        expectedPointCount: Int
    ) -> Asset? {
        guard let asset = existingAsset(
            forLegacySplat: legacySplatURL,
            expectedPointCount: expectedPointCount
        ), hasCompleteVertexPayload(at: asset.url, expectedPointCount: expectedPointCount) else {
            return nil
        }
        return asset
    }

    /// Validates that a binary PLY contains at least the full declared vertex payload.
    /// This deliberately does not require EOF immediately after the vertex element because future
    /// exporters may append other legal PLY elements after the Gaussian vertices.
    static func hasCompleteVertexPayload(
        at url: URL,
        expectedPointCount: Int,
        fileManager: FileManager = .default
    ) -> Bool {
        guard expectedPointCount > 0,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let sizeNumber = attributes[.size] as? NSNumber,
              sizeNumber.int64Value > 0 else { return false }

        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            return false
        }
        defer { try? handle.close() }

        let prefix: Data
        do {
            guard let data = try handle.read(upToCount: 128 * 1024) else { return false }
            prefix = data
        } catch {
            return false
        }
        guard !prefix.isEmpty,
              let markerRange = prefix.range(of: Data("end_header".utf8)) else { return false }

        var payloadOffset = markerRange.upperBound
        if payloadOffset < prefix.endIndex, prefix[payloadOffset] == 13 { payloadOffset += 1 }
        if payloadOffset < prefix.endIndex, prefix[payloadOffset] == 10 { payloadOffset += 1 }

        let headerData = prefix.prefix(upTo: markerRange.upperBound)
        guard let header = String(data: headerData, encoding: .utf8) else { return false }

        var binaryFormat = false
        var inVertexElement = false
        var declaredVertexCount: Int?
        var vertexStride: UInt64 = 0
        for rawLine in header.split(whereSeparator: { $0.isNewline }) {
            let fields = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard !fields.isEmpty else { continue }
            if fields[0] == "format", fields.count >= 2 {
                binaryFormat = fields[1] == "binary_little_endian" || fields[1] == "binary_big_endian"
            } else if fields[0] == "element", fields.count >= 3 {
                inVertexElement = fields[1] == "vertex"
                if inVertexElement { declaredVertexCount = Int(fields[2]) }
            } else if fields[0] == "property", inVertexElement {
                guard fields.count >= 3, fields[1] != "list",
                      let byteWidth = plyScalarByteWidth(String(fields[1])) else { return false }
                guard vertexStride <= UInt64.max - byteWidth else { return false }
                vertexStride += byteWidth
            }
        }

        guard binaryFormat,
              declaredVertexCount == expectedPointCount,
              vertexStride > 0 else { return false }
        let count = UInt64(expectedPointCount)
        guard count <= UInt64.max / vertexStride else { return false }
        let bodyBytes = count * vertexStride
        let headerBytes = UInt64(payloadOffset)
        guard headerBytes <= UInt64.max - bodyBytes else { return false }
        return UInt64(sizeNumber.int64Value) >= headerBytes + bodyBytes
    }

    private static func plyScalarByteWidth(_ type: String) -> UInt64? {
        switch type.lowercased() {
        case "char", "int8", "uchar", "uint8": return 1
        case "short", "int16", "ushort", "uint16": return 2
        case "int", "int32", "uint", "uint32", "float", "float32": return 4
        case "double", "float64", "int64", "uint64": return 8
        default: return nil
        }
    }

    @discardableResult
    static func registerDurableProjectOutput(
        _ asset: Asset,
        legacySplatURL: URL,
        store: ScanProjectStore = ScanProjectStore()
    ) throws -> ScanProjectManifest {
        let projectURL = legacySplatURL.deletingLastPathComponent()
        let key = manifestOutputKeyPrefix + asset.url.deletingPathExtension().lastPathComponent
        return try store.updateManifest(projectURL: projectURL) { manifest in
            manifest.outputs[key] = asset.url.lastPathComponent
        }
    }

    static func pruneAbandonedCandidates(
        in directoryURL: URL,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsSubdirectoryDescendants]
        ) else { return }

        for url in urls {
            let name = url.lastPathComponent
            guard name.hasPrefix(".result.sh3-"), name.hasSuffix(".candidate.ply") else { continue }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) >= abandonedCandidateAge else { continue }
            try? fileManager.removeItem(at: url)
        }
    }
}