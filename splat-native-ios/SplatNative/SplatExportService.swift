import CryptoKit
import Foundation
import SplatIO
import simd

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

    static func makePlan(sourceURL: URL, sourcePointCount: Int) async throws -> Plan {
        let settings = loadSettings(sourceURL: sourceURL)
        guard settings != .default else {
            return Plan(settings: settings, bounds: nil, outputPointCount: sourcePointCount)
        }

        let bounds = settings.hasCrop
            ? try await sampledCropBounds(sourceURL: sourceURL, sourcePointCount: sourcePointCount)
            : nil
        let reader = try DotSplatSceneReader(sourceURL)
        let stream = try reader.read()
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
        let reader = try DotSplatSceneReader(sourceURL)
        let stream = try reader.read()
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

        if settings.cropXMin > 0.0001 || settings.cropXMax < 0.9999 {
            if p.x < bounds.x.value(at: settings.cropXMin) || p.x > bounds.x.value(at: settings.cropXMax) { return false }
        }
        if settings.cropYMin > 0.0001 || settings.cropYMax < 0.9999 {
            if p.y < bounds.y.value(at: settings.cropYMin) || p.y > bounds.y.value(at: settings.cropYMax) { return false }
        }
        if settings.cropZMin > 0.0001 || settings.cropZMax < 0.9999 {
            if p.z < bounds.z.value(at: settings.cropZMin) || p.z > bounds.z.value(at: settings.cropZMax) { return false }
        }
        return true
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(clamping: Int((max(0, min(1, value)) * 255).rounded()))
    }
}

/// C2 export pipeline for Gaussian Splat assets.
///
/// The reconstruction output is the 32-byte-per-point `.splat` format emitted by Msplat.
/// We intentionally decode it through SplatIO and re-encode through SplatIO's PLY/SPZ writers
/// instead of duplicating coordinate, scale, opacity, rotation, or color conversions here.
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
        let editPlan = try await SplatPersistedEditMaterializer.makePlan(
            sourceURL: sourceURL,
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
            .appendingPathComponent(".\(outputURL.lastPathComponent).\(UUID().uuidString).partial")

        try? FileManager.default.removeItem(at: temporaryURL)

        do {
            let reader = try DotSplatSceneReader(sourceURL)
            let stream = try reader.read()
            var pointsWritten = 0

            switch format {
            case .ply:
                let writer = try SplatPLYSceneWriter(toFileAtPath: temporaryURL.path)
                try await writer.start(sphericalHarmonicDegree: 0, binary: true, pointCount: pointCount)
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

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
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

    private static func fileByteLength(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw ExportError.outputMissing }
        return size.intValue
    }

    private static func validateNonEmptyFile(_ url: URL) throws {
        guard try fileByteLength(url) > 0 else { throw ExportError.outputMissing }
    }
}
