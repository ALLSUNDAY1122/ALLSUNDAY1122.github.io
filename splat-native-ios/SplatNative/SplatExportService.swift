import CryptoKit
import Foundation
import Msplat
import SplatIO
import simd

enum SplatCanonicalSHAsset {
    struct Descriptor: Equatable, Sendable {
        let pointCount: Int
        let shDegree: UInt
        let higherOrderPropertyCount: Int
    }

    struct Asset: Equatable, Sendable {
        let url: URL
        let descriptor: Descriptor
    }

    enum CanonicalError: LocalizedError {
        case sourceMissing
        case invalidPLYHeader
        case unsupportedSHLayout(Int)
        case pointCountMismatch(expected: Int, actual: Int)
        case shDegreeMismatch(expected: UInt, actual: UInt)

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "SH3 canonical asset の元データが見つかりません。"
            case .invalidPLYHeader:
                return "SH3 canonical asset のPLYヘッダーを検証できません。"
            case .unsupportedSHLayout(let count):
                return "SH係数レイアウトが不正です（f_rest: \(count)）。"
            case .pointCountMismatch(let expected, let actual):
                return "canonical asset のGaussian数が一致しません（期待: \(expected)、実際: \(actual)）。"
            case .shDegreeMismatch(let expected, let actual):
                return "canonical asset のSH次数が一致しません（期待: SH\(expected)、実際: SH\(actual)）。"
            }
        }
    }

    static let requiredSHDegree: UInt = 3
    private static let headerReadLimit = 128 * 1024
    private static let canonicalPrefix = "result.sh3-"

    static func canonicalURL(forLegacySplat sourceURL: URL) throws -> URL {
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CanonicalError.sourceMissing
        }
        let digest = try SplatExportService.sha256Hex(fileURL: sourceURL)
        return sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(canonicalPrefix)\(digest).ply")
    }

    static func existingAsset(forLegacySplat sourceURL: URL, expectedPointCount: Int) -> Asset? {
        guard let url = try? canonicalURL(forLegacySplat: sourceURL),
              FileManager.default.fileExists(atPath: url.path),
              let descriptor = try? inspectPLY(url),
              descriptor.shDegree == requiredSHDegree,
              descriptor.pointCount == expectedPointCount else {
            return nil
        }
        return Asset(url: url, descriptor: descriptor)
    }

    /// Persist the lossless trainer output beside the legacy `.splat` using a content-addressed name.
    /// The SHA-256 key is derived from the legacy `.splat`, so a failed reprocess can never pair an
    /// older committed `.splat` with a newer SH asset (or vice versa).
    static func persist(
        from trainer: Msplat.GaussianTrainer,
        legacySplatURL: URL,
        expectedPointCount: Int
    ) throws -> Asset {
        let targetURL = try canonicalURL(forLegacySplat: legacySplatURL)
        let temporaryURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent(".\(targetURL.lastPathComponent).\(UUID().uuidString).partial.ply")
        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            trainer.exportPly(to: temporaryURL.path)
            let descriptor = try inspectPLY(temporaryURL)
            guard descriptor.pointCount == expectedPointCount else {
                throw CanonicalError.pointCountMismatch(
                    expected: expectedPointCount,
                    actual: descriptor.pointCount
                )
            }
            guard descriptor.shDegree == requiredSHDegree else {
                throw CanonicalError.shDegreeMismatch(
                    expected: requiredSHDegree,
                    actual: descriptor.shDegree
                )
            }

            if FileManager.default.fileExists(atPath: targetURL.path) {
                _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: targetURL)
            }
            return Asset(url: targetURL, descriptor: descriptor)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    static func inspectPLY(_ url: URL) throws -> Descriptor {
        guard url.isFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            throw CanonicalError.sourceMissing
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: headerReadLimit), !data.isEmpty else {
            throw CanonicalError.invalidPLYHeader
        }
        let marker = Data("end_header".utf8)
        guard let markerRange = data.range(of: marker) else {
            throw CanonicalError.invalidPLYHeader
        }
        let headerData = data.prefix(upTo: markerRange.upperBound)
        guard let header = String(data: headerData, encoding: .utf8),
              header.hasPrefix("ply") else {
            throw CanonicalError.invalidPLYHeader
        }

        var pointCount: Int?
        var dcIndices = Set<Int>()
        var restIndices = Set<Int>()
        for rawLine in header.split(whereSeparator: { $0.isNewline }) {
            let line = String(rawLine)
            if line.hasPrefix("element vertex ") {
                pointCount = Int(line.dropFirst("element vertex ".count))
            } else if line.hasPrefix("property float f_dc_") {
                if let index = Int(line.dropFirst("property float f_dc_".count)) {
                    dcIndices.insert(index)
                }
            } else if line.hasPrefix("property float f_rest_") {
                if let index = Int(line.dropFirst("property float f_rest_".count)) {
                    restIndices.insert(index)
                }
            }
        }

        guard let pointCount, pointCount > 0, dcIndices == Set([0, 1, 2]) else {
            throw CanonicalError.invalidPLYHeader
        }
        let restCount = restIndices.count
        if restCount > 0, restIndices != Set(0..<restCount) {
            throw CanonicalError.invalidPLYHeader
        }

        let degree: UInt
        switch restCount {
        case 0: degree = 0
        case 9: degree = 1
        case 24: degree = 2
        case 45: degree = 3
        default: throw CanonicalError.unsupportedSHLayout(restCount)
        }
        return Descriptor(
            pointCount: pointCount,
            shDegree: degree,
            higherOrderPropertyCount: restCount
        )
    }
}

enum SplatPersistedEditMaterializer {
    struct AxisRange: Sendable {
        let low: Float
        let high: Float

        var extent: Float { max(0.0001, high - low) }
        func value(at fraction: Double) -> Float {
            low + extent * Float(min(1, max(0, fraction)))
        }
    }

    struct CropBounds: Sendable {
        let x: AxisRange
        let y: AxisRange
        let z: AxisRange
    }

    struct Plan: Sendable {
        let settings: SplatEditSettings
        let bounds: CropBounds?
        let outputPointCount: Int

        var isIdentity: Bool { settings == .default }
    }

    enum MaterializeError: LocalizedError {
        case emptyEditedScene

        var errorDescription: String? {
            switch self {
            case .emptyEditedScene:
                return "現在の切り抜き範囲には書き出せるGaussianがありません。切り抜きを調整してください。"
            }
        }
    }

    static func makePlan(
        sourceURL: URL,
        assetURL: URL? = nil,
        sourcePointCount: Int
    ) async throws -> Plan {
        let settings = loadSettings(sourceURL: sourceURL)
        guard settings != .default else {
            return Plan(settings: settings, bounds: nil, outputPointCount: sourcePointCount)
        }

        let resolvedAssetURL = assetURL ?? sourceURL
        let bounds = settings.hasCrop
            ? try await sampledCropBounds(sourceURL: resolvedAssetURL, sourcePointCount: sourcePointCount)
            : nil
        let reader = try AutodetectSceneReader(resolvedAssetURL)
        let stream = try await reader.read()
        var outputPointCount = 0
        for try await points in stream {
            try Task.checkCancellation()
            outputPointCount += eligiblePointCount(points, settings: settings, bounds: bounds)
        }
        guard outputPointCount > 0 else { throw MaterializeError.emptyEditedScene }
        return Plan(settings: settings, bounds: bounds, outputPointCount: outputPointCount)
    }

    static func materializeInMemory(sourceURL: URL, points: [SplatPoint]) throws -> [SplatPoint] {
        let settings = loadSettings(sourceURL: sourceURL)
        guard settings != .default else { return points }
        let bounds = settings.hasCrop ? robustCropBounds(for: points) : nil
        let plan = Plan(settings: settings, bounds: bounds, outputPointCount: points.count)
        let edited = apply(points, plan: plan)
        guard !edited.isEmpty else { throw MaterializeError.emptyEditedScene }
        return edited
    }

    static func apply(_ points: [SplatPoint], plan: Plan) -> [SplatPoint] {
        guard !plan.isIdentity else { return points }
        let settings = plan.settings
        let exposureGain = Float(pow(2.0, settings.exposureEV))
        let contrast = Float(settings.contrast)
        let needsColorAdjustment = abs(settings.exposureEV) > 0.0001 || abs(settings.contrast - 1) > 0.0001

        var result: [SplatPoint] = []
        result.reserveCapacity(points.count)
        for point in points {
            guard isEligible(point, settings: settings, bounds: plan.bounds) else { continue }
            guard needsColorAdjustment else {
                result.append(point)
                continue
            }

            var edited = point
            let base = point.color.asSRGBFloat
            let exposed = base * exposureGain
            let midpoint = SIMD3<Float>(repeating: 0.5)
            let adjusted = simd_clamp((exposed - midpoint) * contrast + midpoint, .zero, .one)
            switch point.color {
            case .sphericalHarmonicFloat(var coefficients):
                if !coefficients.isEmpty {
                    coefficients[0] = (adjusted - midpoint) * SplatPoint.Color.INV_SH_C0
                    edited.color = .sphericalHarmonicFloat(coefficients)
                }
            case .sRGBUInt8:
                edited.color = .sRGBUInt8(SIMD3<UInt8>(
                    byte(adjusted.x), byte(adjusted.y), byte(adjusted.z)
                ))
            }
            result.append(edited)
        }
        return result
    }

    static func loadSettings(sourceURL: URL) -> SplatEditSettings {
        let sidecar = sourceURL.deletingPathExtension().appendingPathExtension("viewer.json")
        guard let data = try? Data(contentsOf: sidecar),
              let decoded = try? JSONDecoder().decode(SplatEditSettings.self, from: data) else {
            return .default
        }
        return decoded.normalized()
    }

    private static func sampledCropBounds(sourceURL: URL, sourcePointCount: Int) async throws -> CropBounds {
        let sampleStride = max(1, sourcePointCount / 8_000)
        let reader = try AutodetectSceneReader(sourceURL)
        let stream = try await reader.read()
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(min(sourcePointCount, 8_001))
        ys.reserveCapacity(min(sourcePointCount, 8_001))
        zs.reserveCapacity(min(sourcePointCount, 8_001))
        var globalIndex = 0

        for try await points in stream {
            try Task.checkCancellation()
            for point in points {
                if globalIndex % sampleStride == 0 {
                    let p = point.position
                    if p.x.isFinite, p.y.isFinite, p.z.isFinite {
                        xs.append(p.x); ys.append(p.y); zs.append(p.z)
                    }
                }
                globalIndex += 1
            }
        }
        return CropBounds(x: percentileRange(xs), y: percentileRange(ys), z: percentileRange(zs))
    }

    private static func robustCropBounds(for points: [SplatPoint]) -> CropBounds {
        let strideSize = max(1, points.count / 8_000)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            xs.append(p.x); ys.append(p.y); zs.append(p.z)
        }
        return CropBounds(x: percentileRange(xs), y: percentileRange(ys), z: percentileRange(zs))
    }

    private static func percentileRange(_ values: [Float]) -> AxisRange {
        guard !values.isEmpty else { return AxisRange(low: -1, high: 1) }
        let sorted = values.sorted()
        let lowIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.01))
        let highIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.99))
        var low = sorted[lowIndex]
        var high = sorted[highIndex]
        if !low.isFinite || !high.isFinite || high - low < 0.0001 {
            low = sorted.first ?? -1
            high = sorted.last ?? 1
        }
        if high - low < 0.0001 { high = low + 0.0001 }
        return AxisRange(low: low, high: high)
    }

    private static func eligiblePointCount(
        _ points: [SplatPoint],
        settings: SplatEditSettings,
        bounds: CropBounds?
    ) -> Int {
        points.reduce(into: 0) { count, point in
            if isEligible(point, settings: settings, bounds: bounds) { count += 1 }
        }
    }

    private static func isEligible(
        _ point: SplatPoint,
        settings: SplatEditSettings,
        bounds: CropBounds?
    ) -> Bool {
        let p = point.position
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { return false }
        guard let bounds else { return true }

        // Robust percentile bounds stabilize slider travel, but an untouched endpoint must
        // remain open-ended. Otherwise moving only the lower handle would silently drop the
        // upper 1% tail (and vice versa), so Viewer/export/video would not represent the UI.
        if settings.cropXMin > 0.0001, p.x < bounds.x.value(at: settings.cropXMin) { return false }
        if settings.cropXMax < 0.9999, p.x > bounds.x.value(at: settings.cropXMax) { return false }
        if settings.cropYMin > 0.0001, p.y < bounds.y.value(at: settings.cropYMin) { return false }
        if settings.cropYMax < 0.9999, p.y > bounds.y.value(at: settings.cropYMax) { return false }
        if settings.cropZMin > 0.0001, p.z < bounds.z.value(at: settings.cropZMin) { return false }
        if settings.cropZMax < 0.9999, p.z > bounds.z.value(at: settings.cropZMax) { return false }
        return true
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(clamping: Int((max(0, min(1, value)) * 255).rounded()))
    }
}

/// Export pipeline for Gaussian Splat assets.
///
/// New SH3 reconstructions retain a content-addressed SH3 PLY beside the legacy 32-byte `.splat`.
/// Export prefers that canonical asset and falls back to `.splat` only for older scans. The pinned
/// SPZ writer preserves SH3 coefficients, but currently emits the SPZ antialias flag as `false`;
/// antialias semantic parity with Scaniverse remains a separately verified Gate.
enum SplatExportService {
    enum Format: String, CaseIterable, Identifiable, Sendable {
        case ply
        case spz

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .ply: return "PLY"
            case .spz: return "SPZ"
            }
        }
    }

    enum ExportError: LocalizedError {
        case sourceMissing
        case unsupportedSource
        case corruptSource
        case emptySource
        case incompleteWrite(expected: Int, actual: Int)
        case sphericalHarmonicsLost(expectedDegree: UInt)
        case outputMissing

        var errorDescription: String? {
            switch self {
            case .sourceMissing:
                return "書き出し元の3Dデータが見つかりません。"
            case .unsupportedSource:
                return "この3Dデータ形式は現在の書き出し処理では扱えません。"
            case .corruptSource:
                return "3Dデータが途中で欠けています。再生成してから書き出してください。"
            case .emptySource:
                return "3DデータにGaussianが含まれていません。"
            case .incompleteWrite(let expected, let actual):
                return "書き出し件数が一致しません（期待: \(expected)、実際: \(actual)）。"
            case .sphericalHarmonicsLost(let expectedDegree):
                return "SH\(expectedDegree)係数を保持したまま書き出せませんでした。"
            case .outputMissing:
                return "書き出しファイルを作成できませんでした。"
            }
        }
    }

    struct BrowserShareManifest: Codable, Equatable, Sendable {
        static let currentSchemaVersion = 1

        struct Asset: Codable, Equatable, Sendable {
            let fileName: String
            let mediaType: String
            let byteLength: Int
            let sha256: String
        }

        let schemaVersion: Int
        let representation: String
        let primaryAsset: Asset
        let previewFileName: String?
        let createdAt: Date
        let containsLocation: Bool

        init(primaryAsset: Asset, previewFileName: String?, createdAt: Date = Date()) {
            self.schemaVersion = Self.currentSchemaVersion
            self.representation = "gaussian-splat"
            self.primaryAsset = primaryAsset
            self.previewFileName = previewFileName
            self.createdAt = createdAt
            self.containsLocation = false
        }
    }

    struct BrowserSharePackage: Sendable {
        let directoryURL: URL
        let assetURL: URL
        let manifestURL: URL
        let previewURL: URL?
    }

    private static let dotSplatRecordByteWidth = 32
    private static let hashChunkBytes = 1_024 * 1_024

    static func export(
        sourceURL: URL,
        format: Format,
        destinationDirectory: URL? = nil,
        outputBaseName: String? = nil
    ) async throws -> URL {
        let sourcePointCount = try sourcePointCount(sourceURL)
        let canonical = SplatCanonicalSHAsset.existingAsset(
            forLegacySplat: sourceURL,
            expectedPointCount: sourcePointCount
        )
        let retainedAssetURL = canonical?.url ?? sourceURL
        let retainedSHDegree = canonical?.descriptor.shDegree ?? 0
        let editPlan = try await SplatPersistedEditMaterializer.makePlan(
            sourceURL: sourceURL,
            assetURL: retainedAssetURL,
            sourcePointCount: sourcePointCount
        )
        let pointCount = editPlan.outputPointCount
        let directory = destinationDirectory ?? sourceURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let defaultBaseName = sourceURL.deletingPathExtension().lastPathComponent
        let baseName = outputBaseName ?? defaultBaseName
        let outputURL = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(format.rawValue)
        let temporaryURL = directory
            .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).partial.\(format.rawValue)")

        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            let reader = try AutodetectSceneReader(retainedAssetURL)
            let stream = try await reader.read()
            var pointsWritten = 0

            switch format {
            case .ply:
                let writer = try SplatPLYSceneWriter(toFileAtPath: temporaryURL.path)
                try await writer.start(
                    sphericalHarmonicDegree: retainedSHDegree,
                    binary: true,
                    pointCount: pointCount
                )
                for try await points in stream {
                    try Task.checkCancellation()
                    let outputPoints = SplatPersistedEditMaterializer.apply(points, plan: editPlan)
                    if !outputPoints.isEmpty {
                        try await writer.write(outputPoints)
                        pointsWritten += outputPoints.count
                    }
                }
                try await writer.close()

            case .spz:
                let writer = try SPZSceneWriter(toFileAtPath: temporaryURL.path)
                try await writer.start(numPoints: pointCount)
                for try await points in stream {
                    try Task.checkCancellation()
                    let outputPoints = SplatPersistedEditMaterializer.apply(points, plan: editPlan)
                    if !outputPoints.isEmpty {
                        try await writer.write(outputPoints)
                        pointsWritten += outputPoints.count
                    }
                }
                try await writer.close()
            }

            guard pointsWritten == pointCount else {
                throw ExportError.incompleteWrite(expected: pointCount, actual: pointsWritten)
            }
            try validateNonEmptyFile(temporaryURL)
            if retainedSHDegree > 0 {
                try await validateRetainedSphericalHarmonics(
                    fileURL: temporaryURL,
                    expectedDegree: retainedSHDegree,
                    expectedPointCount: pointCount
                )
            }

            if FileManager.default.fileExists(atPath: outputURL.path) {
                _ = try FileManager.default.replaceItemAt(outputURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
            }
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    static func makeBrowserSharePackage(
        sourceURL: URL,
        previewJPEG: Data? = nil,
        rootDirectory: URL = FileManager.default.temporaryDirectory
    ) async throws -> BrowserSharePackage {
        let trustedURL = try SplatExportAdmission.preflight(sourceURL: sourceURL, kind: .spz)
        try Task.checkCancellation()

        let packageURL = rootDirectory
            .appendingPathComponent("scanlab-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        do {
            let assetURL = try await export(
                sourceURL: trustedURL,
                format: .spz,
                destinationDirectory: packageURL,
                outputBaseName: "scene"
            )
            try Task.checkCancellation()

            let assetByteLength = try fileByteLength(assetURL)
            guard assetByteLength > 0 else { throw ExportError.outputMissing }
            let assetHash = try sha256Hex(fileURL: assetURL)
            try Task.checkCancellation()

            var previewURL: URL?
            if let previewJPEG, !previewJPEG.isEmpty {
                let url = packageURL.appendingPathComponent("preview.jpg")
                try previewJPEG.write(to: url, options: .atomic)
                previewURL = url
            }

            let asset = BrowserShareManifest.Asset(
                fileName: assetURL.lastPathComponent,
                mediaType: "application/octet-stream",
                byteLength: assetByteLength,
                sha256: assetHash
            )
            let manifest = BrowserShareManifest(
                primaryAsset: asset,
                previewFileName: previewURL?.lastPathComponent
            )
            let manifestURL = packageURL.appendingPathComponent("manifest.json")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

            return BrowserSharePackage(
                directoryURL: packageURL,
                assetURL: assetURL,
                manifestURL: manifestURL,
                previewURL: previewURL
            )
        } catch {
            try? FileManager.default.removeItem(at: packageURL)
            throw error
        }
    }

    static func sourcePointCount(_ sourceURL: URL) throws -> Int {
        guard sourceURL.isFileURL,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ExportError.sourceMissing
        }
        guard sourceURL.pathExtension.lowercased() == "splat" else {
            throw ExportError.unsupportedSource
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard let number = attributes[.size] as? NSNumber else {
            throw ExportError.corruptSource
        }
        let bytes = number.intValue
        guard bytes > 0 else { throw ExportError.emptySource }
        guard bytes % dotSplatRecordByteWidth == 0 else { throw ExportError.corruptSource }
        return bytes / dotSplatRecordByteWidth
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let chunk = try handle.read(upToCount: hashChunkBytes), !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func validateRetainedSphericalHarmonics(
        fileURL: URL,
        expectedDegree: UInt,
        expectedPointCount: Int
    ) async throws {
        let expectedCoefficientCount = (Int(expectedDegree) + 1) * (Int(expectedDegree) + 1)
        let reader = try AutodetectSceneReader(fileURL)
        let stream = try await reader.read()
        var pointsRead = 0

        for try await points in stream {
            try Task.checkCancellation()
            for point in points {
                guard UInt(point.color.shDegree.rawValue) == expectedDegree,
                      point.color.asSphericalHarmonicFloat.count == expectedCoefficientCount else {
                    throw ExportError.sphericalHarmonicsLost(expectedDegree: expectedDegree)
                }
            }
            pointsRead += points.count
        }
        guard pointsRead == expectedPointCount else {
            throw ExportError.incompleteWrite(expected: expectedPointCount, actual: pointsRead)
        }
    }

    private static func fileByteLength(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw ExportError.outputMissing }
        return size.intValue
    }

    private static func validateNonEmptyFile(_ url: URL) throws {
        guard try fileByteLength(url) > 0 else { throw ExportError.outputMissing }
    }
}
