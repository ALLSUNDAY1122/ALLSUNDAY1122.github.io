import Foundation
import simd

struct SplatDepthSeedFrame: Sendable {
    let depthFilePath: String?
    let depthWidth: Int?
    let depthHeight: Int?
    let depthBytesPerRow: Int?
    let transformMatrix: [[Float]]
    let flX: Float
    let flY: Float
    let cx: Float
    let cy: Float
    let w: Int
    let h: Int
}

/// S14 reconstruction initialization.
///
/// Hardware scene depth remains the preferred source when it exists. On captures such as the
/// physical same-raw failure where `depth 0 frames` was observed, S14 now computes bounded RGB
/// multi-view software depth before falling back to ARKit raw feature points. This isolates dense
/// initialization from camera-pose refinement while preserving all trainer/resource contracts.
enum SplatDepthSeedBuilder {
    // Recipe version is a cache-compatibility epoch, not the file-format version. Bump it whenever
    // seed-generation semantics change so a same-RAW comparison cannot silently reuse stale points3D.ply.
    static let recipeVersion = 7
    static let targetSamplesPerFrame = 900
    static let voxelDensity: Float = 100
    static let minimumDepth: Float = 0.18
    static let maximumDepth: Float = 5.0
    static let minimumGeometryPointCount = 64
    static let maximumDepthSeedPointCount = 120_000
    static let legacyMetadataFileName = "s13-seed-recipe.json"
    static let metadataFileName = "s14-seed-recipe.json"

    enum Source: String, Codable, Sendable {
        case depth
        case planeSweep
        case rawFeaturePoints
    }

    struct Outcome: Sendable {
        let source: Source
        let pointCount: Int
        let depthFrameCount: Int
        let geometryPointCount: Int
        let skySeedCount: Int
        let requiresFreshTrainer: Bool
    }

    private struct RecipeMetadata: Codable {
        let recipeVersion: Int
        let source: Source
        let pointCount: Int
        let depthFrameCount: Int
        let geometryPointCount: Int
        let skySeedCount: Int
        let captureFingerprint: String?
        let createdAt: Date
    }

    private struct Voxel: Hashable {
        let x: Int
        let y: Int
        let z: Int

        init?(_ point: SIMD3<Float>) {
            guard let x = Int(exactly: floor(Double(point.x) * Double(voxelDensity))),
                  let y = Int(exactly: floor(Double(point.y) * Double(voxelDensity))),
                  let z = Int(exactly: floor(Double(point.z) * Double(voxelDensity))) else {
                return nil
            }
            self.x = x
            self.y = y
            self.z = z
        }
    }

    static func preparePointCloudPLY(
        projectURL: URL,
        depthFrames: [SplatDepthSeedFrame],
        fallbackPoints: [SIMD3<Float>],
        colorFrames: [SplatSeedFrame],
        fileManager: FileManager = .default
    ) throws -> Outcome {
        let plyURL = projectURL.appendingPathComponent("points3D.ply")
        let metadataURL = projectURL.appendingPathComponent(metadataFileName)
        let canonicalFallbackPoints = fallbackPoints
            .filter { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }
            .sorted(by: pointLessThan)
        let currentCaptureFingerprint = captureFingerprint(
            depthFrames: depthFrames,
            fallbackPoints: canonicalFallbackPoints,
            colorFrames: colorFrames
        )

        if fileManager.fileExists(atPath: plyURL.path),
           let metadataData = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(RecipeMetadata.self, from: metadataData),
           metadata.recipeVersion == recipeVersion,
           metadata.captureFingerprint == currentCaptureFingerprint,
           metadata.geometryPointCount >= minimumGeometryPointCount,
           metadata.pointCount >= metadata.geometryPointCount,
           cachedPLYIsComplete(at: plyURL, expectedPointCount: metadata.pointCount) {
            return Outcome(
                source: metadata.source,
                pointCount: metadata.pointCount,
                depthFrameCount: metadata.depthFrameCount,
                geometryPointCount: metadata.geometryPointCount,
                skySeedCount: metadata.skySeedCount,
                requiresFreshTrainer: false
            )
        }

        let depthResult = depthSeedPoints(projectURL: projectURL, frames: depthFrames, fileManager: fileManager)
        let source: Source
        let geometryPoints: [SIMD3<Float>]
        let geometryColors: [SplatSeedSample]

        if depthResult.points.count >= minimumGeometryPointCount {
            source = .depth
            geometryPoints = depthResult.points
            geometryColors = SplatSeedColorizer.colorize(
                points: geometryPoints,
                frames: colorFrames,
                projectURL: projectURL
            )
        } else {
            let softwareResult = SplatSoftwareDepthSeedBuilder.makeSeedPoints(
                projectURL: projectURL,
                frames: colorFrames
            )
            if softwareResult.points.count >= SplatSoftwareDepthSeedBuilder.minimumUsablePointCount,
               softwareResult.colors.count == softwareResult.points.count {
                source = .planeSweep
                geometryPoints = softwareResult.points
                geometryColors = softwareResult.colors
            } else {
                guard canonicalFallbackPoints.count >= minimumGeometryPointCount else {
                    throw NSError(
                        domain: "SplatLab.S14",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "初期3Dデータに必要なdepth/RGB multi-view/特徴点が不足しています"]
                    )
                }
                source = .rawFeaturePoints
                geometryPoints = canonicalFallbackPoints
                geometryColors = SplatSeedColorizer.colorize(
                    points: geometryPoints,
                    frames: colorFrames,
                    projectURL: projectURL
                )
            }
        }

        let skySeeds = SplatSkySeeder.makeSeeds(
            frames: colorFrames,
            geometryPoints: geometryPoints,
            projectURL: projectURL
        )
        try writePLY(
            geometryPoints: geometryPoints,
            colors: geometryColors,
            skySeeds: skySeeds,
            to: plyURL
        )

        let metadata = RecipeMetadata(
            recipeVersion: recipeVersion,
            source: source,
            pointCount: geometryPoints.count + skySeeds.count,
            depthFrameCount: depthResult.framesUsed,
            geometryPointCount: geometryPoints.count,
            skySeedCount: skySeeds.count,
            captureFingerprint: currentCaptureFingerprint,
            createdAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: metadataURL, options: .atomic)

        return Outcome(
            source: source,
            pointCount: metadata.pointCount,
            depthFrameCount: metadata.depthFrameCount,
            geometryPointCount: metadata.geometryPointCount,
            skySeedCount: metadata.skySeedCount,
            requiresFreshTrainer: true
        )
    }

    /// Cache admission is intentionally structural and bounded: `points3D.ply` is ASCII and is
    /// capped by `maximumDepthSeedPointCount` plus a small bounded sky seed set. Mapping the file
    /// avoids a second large heap copy while proving every persisted row has exactly the numeric
    /// shape written by this app. A torn, appended, non-finite, or malformed cache is regenerated
    /// instead of being handed to the trainer.
    static func cachedPLYIsComplete(at url: URL, expectedPointCount: Int) -> Bool {
        guard expectedPointCount >= minimumGeometryPointCount,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              !data.isEmpty,
              let headerMarker = "end_header\n".data(using: .utf8),
              let headerRange = data.range(of: headerMarker) else {
            return false
        }

        let headerData = data[..<headerRange.upperBound]
        guard let header = String(data: headerData, encoding: .utf8),
              let declaredLine = header.split(separator: "\n").first(where: { $0.hasPrefix("element vertex ") }),
              let declaredCount = Int(declaredLine.dropFirst("element vertex ".count)),
              declaredCount == expectedPointCount else {
            return false
        }

        let body = data[headerRange.upperBound...]
        var rowCount = 0
        var rowStart = body.startIndex
        var rowHasContent = false

        func rowIsValid(_ row: Data.SubSequence) -> Bool {
            let line = String(decoding: row, as: UTF8.self)
            let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
            guard fields.count == 6,
                  let x = Float(fields[0]), x.isFinite,
                  let y = Float(fields[1]), y.isFinite,
                  let z = Float(fields[2]), z.isFinite,
                  let red = Int(fields[3]), (0...255).contains(red),
                  let green = Int(fields[4]), (0...255).contains(green),
                  let blue = Int(fields[5]), (0...255).contains(blue) else {
                return false
            }
            return true
        }

        for index in body.indices {
            let byte = body[index]
            if byte == 0x0A {
                if rowHasContent {
                    guard rowIsValid(body[rowStart..<index]) else { return false }
                    rowCount += 1
                    if rowCount > expectedPointCount { return false }
                }
                rowStart = body.index(after: index)
                rowHasContent = false
            } else if byte != 0x0D && byte != 0x20 && byte != 0x09 {
                rowHasContent = true
            }
        }
        if rowHasContent {
            guard rowIsValid(body[rowStart..<body.endIndex]) else { return false }
            rowCount += 1
        }
        return rowCount == expectedPointCount
    }

    private static func captureFingerprint(
        depthFrames: [SplatDepthSeedFrame],
        fallbackPoints: [SIMD3<Float>],
        colorFrames: [SplatSeedFrame]
    ) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        func mixByte(_ byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        func mixUInt64(_ value: UInt64) {
            var value = value
            for _ in 0..<8 {
                mixByte(UInt8(truncatingIfNeeded: value))
                value >>= 8
            }
        }
        func mixInt(_ value: Int) {
            mixUInt64(UInt64(bitPattern: Int64(value)))
        }
        func mixFloat(_ value: Float) {
            mixUInt64(UInt64(value.bitPattern))
        }
        func mixString(_ value: String?) {
            guard let value else {
                mixByte(0xFF)
                return
            }
            mixByte(0x01)
            for byte in value.utf8 { mixByte(byte) }
            mixByte(0)
        }
        func mixMatrix(_ matrix: [[Float]]) {
            mixInt(matrix.count)
            for row in matrix {
                mixInt(row.count)
                for value in row { mixFloat(value) }
            }
        }

        mixInt(colorFrames.count)
        for frame in colorFrames {
            mixString(frame.filePath)
            mixMatrix(frame.transformMatrix)
            mixFloat(frame.flX); mixFloat(frame.flY)
            mixFloat(frame.cx); mixFloat(frame.cy)
            mixInt(frame.w); mixInt(frame.h)
        }

        mixInt(depthFrames.count)
        for frame in depthFrames {
            mixString(frame.depthFilePath)
            mixInt(frame.depthWidth ?? -1)
            mixInt(frame.depthHeight ?? -1)
            mixInt(frame.depthBytesPerRow ?? -1)
            mixMatrix(frame.transformMatrix)
            mixFloat(frame.flX); mixFloat(frame.flY)
            mixFloat(frame.cx); mixFloat(frame.cy)
            mixInt(frame.w); mixInt(frame.h)
        }

        mixInt(fallbackPoints.count)
        for point in fallbackPoints {
            mixFloat(point.x); mixFloat(point.y); mixFloat(point.z)
        }
        return String(format: "%016llx", hash)
    }

    private static func pointLessThan(_ lhs: SIMD3<Float>, _ rhs: SIMD3<Float>) -> Bool {
        if lhs.x != rhs.x { return lhs.x < rhs.x }
        if lhs.y != rhs.y { return lhs.y < rhs.y }
        return lhs.z < rhs.z
    }

    static func validatedDepthInputURL(
        projectURL: URL,
        relativePath: String,
        fileManager: FileManager = .default
    ) -> URL? {
        let lexicalRoot = projectURL.standardizedFileURL
        let resolvedRoot = lexicalRoot.resolvingSymlinksInPath()
        return validatedDepthInputURL(
            lexicalRoot: lexicalRoot,
            resolvedRoot: resolvedRoot,
            relativePath: relativePath,
            fileManager: fileManager
        )
    }

    private static func validatedDepthInputURL(
        lexicalRoot: URL,
        resolvedRoot: URL,
        relativePath: String,
        fileManager: FileManager
    ) -> URL? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { return nil }
        let lexicalCandidate = lexicalRoot.appendingPathComponent(relativePath).standardizedFileURL
        guard isContained(lexicalCandidate, in: lexicalRoot) else { return nil }

        let resolvedCandidate = lexicalCandidate.resolvingSymlinksInPath()
        guard isContained(resolvedCandidate, in: resolvedRoot),
              let values = try? resolvedCandidate.resourceValues(forKeys: [.isRegularFileKey]),
              values.isRegularFile == true else {
            return nil
        }
        return resolvedCandidate
    }

    private static func isContained(_ candidate: URL, in root: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.pathComponents
        let candidateComponents = candidate.standardizedFileURL.pathComponents
        guard candidateComponents.count > rootComponents.count else { return false }
        return candidateComponents.prefix(rootComponents.count).elementsEqual(rootComponents)
    }

    private static func depthSeedPoints(
        projectURL: URL,
        frames: [SplatDepthSeedFrame],
        fileManager: FileManager
    ) -> (points: [SIMD3<Float>], framesUsed: Int) {
        var voxels: [Voxel: SIMD3<Float>] = [:]
        let (reserveEstimate, reserveOverflow) = frames.count.multipliedReportingOverflow(by: targetSamplesPerFrame)
        voxels.reserveCapacity(min(maximumDepthSeedPointCount, reserveOverflow ? maximumDepthSeedPointCount : reserveEstimate))
        var framesUsed = 0
        let lexicalRoot = projectURL.standardizedFileURL
        let resolvedRoot = lexicalRoot.resolvingSymlinksInPath()

        for frame in frames {
            guard voxels.count < maximumDepthSeedPointCount,
                  let relativePath = frame.depthFilePath,
                  let depthWidth = frame.depthWidth,
                  let depthHeight = frame.depthHeight,
                  let bytesPerRow = frame.depthBytesPerRow,
                  depthWidth > 0,
                  depthHeight > 0,
                  bytesPerRow > 0,
                  frame.w > 0,
                  frame.h > 0,
                  frame.flX.isFinite,
                  frame.flY.isFinite,
                  frame.cx.isFinite,
                  frame.cy.isFinite,
                  frame.flX > 0,
                  frame.flY > 0,
                  let cameraToWorld = matrix(fromRows: frame.transformMatrix),
                  let depthURL = validatedDepthInputURL(
                    lexicalRoot: lexicalRoot,
                    resolvedRoot: resolvedRoot,
                    relativePath: relativePath,
                    fileManager: fileManager
                  ) else {
                continue
            }

            let (minimumBytesPerRow, widthOverflow) = depthWidth.multipliedReportingOverflow(by: MemoryLayout<Float32>.stride)
            let (requiredByteCount, payloadOverflow) = bytesPerRow.multipliedReportingOverflow(by: depthHeight)
            let (pixelCount, pixelOverflow) = depthWidth.multipliedReportingOverflow(by: depthHeight)
            guard !widthOverflow,
                  !payloadOverflow,
                  !pixelOverflow,
                  bytesPerRow >= minimumBytesPerRow,
                  requiredByteCount > 0,
                  pixelCount > 0,
                  let data = try? Data(contentsOf: depthURL, options: .mappedIfSafe),
                  data.count >= requiredByteCount else {
                continue
            }

            let step = max(2, Int(sqrt(Double(pixelCount) / Double(targetSamplesPerFrame))))
            var acceptedInFrame = 0

            for y in stride(from: step / 2, to: depthHeight, by: step) {
                for x in stride(from: step / 2, to: depthWidth, by: step) {
                    if voxels.count >= maximumDepthSeedPointCount { break }
                    let (rowOffset, rowOverflow) = y.multipliedReportingOverflow(by: bytesPerRow)
                    let (pixelOffset, pixelOverflow) = x.multipliedReportingOverflow(by: MemoryLayout<Float32>.stride)
                    let (offset, offsetOverflow) = rowOffset.addingReportingOverflow(pixelOffset)
                    guard !rowOverflow,
                          !pixelOverflow,
                          !offsetOverflow,
                          offset >= 0,
                          offset <= data.count - MemoryLayout<Float32>.stride else {
                        continue
                    }
                    let bits = UInt32(data[offset])
                        | (UInt32(data[offset + 1]) << 8)
                        | (UInt32(data[offset + 2]) << 16)
                        | (UInt32(data[offset + 3]) << 24)
                    let z = Float(bitPattern: bits)
                    guard z.isFinite, z >= minimumDepth, z <= maximumDepth else { continue }

                    let imageX = Float(x) * Float(frame.w) / Float(depthWidth)
                    let imageY = Float(y) * Float(frame.h) / Float(depthHeight)
                    let cameraX = (imageX - frame.cx) * z / frame.flX
                    let cameraY = (frame.cy - imageY) * z / frame.flY
                    let world4 = cameraToWorld * SIMD4<Float>(cameraX, cameraY, -z, 1)
                    let world = SIMD3<Float>(world4.x, world4.y, world4.z)
                    guard world.x.isFinite,
                          world.y.isFinite,
                          world.z.isFinite,
                          let voxel = Voxel(world) else { continue }
                    voxels[voxel] = world
                    acceptedInFrame += 1
                }
                if voxels.count >= maximumDepthSeedPointCount { break }
            }

            if acceptedInFrame > 0 { framesUsed += 1 }
        }

        let ordered = voxels.sorted { lhs, rhs in
            if lhs.key.x != rhs.key.x { return lhs.key.x < rhs.key.x }
            if lhs.key.y != rhs.key.y { return lhs.key.y < rhs.key.y }
            return lhs.key.z < rhs.key.z
        }.map(\.value)
        return (ordered, framesUsed)
    }

    private static func matrix(fromRows rows: [[Float]]) -> simd_float4x4? {
        guard rows.count == 4,
              rows.allSatisfy({ row in row.count == 4 && row.allSatisfy({ $0.isFinite }) }) else {
            return nil
        }
        return simd_float4x4(
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        )
    }

    private static func writePLY(
        geometryPoints: [SIMD3<Float>],
        colors: [SplatSeedSample],
        skySeeds: [SplatSkySeed],
        to url: URL
    ) throws {
        let totalCount = geometryPoints.count + skySeeds.count
        var ply = "ply\nformat ascii 1.0\nelement vertex \(totalCount)\n"
        ply += "property float x\nproperty float y\nproperty float z\n"
        ply += "property uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"
        ply.reserveCapacity(totalCount * 56)

        for (index, point) in geometryPoints.enumerated() {
            let color = colors.indices.contains(index) ? colors[index] : SplatSeedColorizer.fallback
            ply += "\(point.x) \(point.y) \(point.z) \(color.red) \(color.green) \(color.blue)\n"
        }
        for seed in skySeeds {
            let point = seed.position
            let color = seed.color
            ply += "\(point.x) \(point.y) \(point.z) \(color.red) \(color.green) \(color.blue)\n"
        }
        try ply.write(to: url, atomically: true, encoding: .utf8)
    }
}
