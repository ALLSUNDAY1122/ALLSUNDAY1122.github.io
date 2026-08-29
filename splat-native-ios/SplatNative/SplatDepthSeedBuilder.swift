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

/// S13 reconstruction initialization.
///
/// Build 8 proved that the bounded trainer can finish, but the physical result can still be
/// geometrically fragmented. The previous initializer used ARKit raw feature points even when a
/// per-frame scene-depth map had been persisted. S13 makes the surface-aligned depth cloud the
/// preferred initializer, matching the reference iOS capture geometry convention while preserving
/// raw feature points as a fail-closed fallback for devices/captures without usable depth.
enum SplatDepthSeedBuilder {
    static let recipeVersion = 1
    static let targetSamplesPerFrame = 900
    static let voxelDensity: Float = 100
    static let minimumDepth: Float = 0.18
    static let maximumDepth: Float = 5.0
    static let minimumGeometryPointCount = 64
    static let maximumDepthSeedPointCount = 120_000
    static let metadataFileName = "s13-seed-recipe.json"

    enum Source: String, Codable, Sendable {
        case depth
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
        let createdAt: Date
    }

    private struct Voxel: Hashable {
        let x: Int
        let y: Int
        let z: Int

        init(_ point: SIMD3<Float>) {
            x = Int(floor(point.x * voxelDensity))
            y = Int(floor(point.y * voxelDensity))
            z = Int(floor(point.z * voxelDensity))
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

        if fileManager.fileExists(atPath: plyURL.path),
           let metadataData = try? Data(contentsOf: metadataURL),
           let metadata = try? JSONDecoder().decode(RecipeMetadata.self, from: metadataData),
           metadata.recipeVersion == recipeVersion,
           metadata.geometryPointCount >= minimumGeometryPointCount,
           metadata.pointCount >= metadata.geometryPointCount {
            return Outcome(
                source: metadata.source,
                pointCount: metadata.pointCount,
                depthFrameCount: metadata.depthFrameCount,
                geometryPointCount: metadata.geometryPointCount,
                skySeedCount: metadata.skySeedCount,
                requiresFreshTrainer: false
            )
        }

        let depthResult = depthSeedPoints(projectURL: projectURL, frames: depthFrames)
        let source: Source
        let geometryPoints: [SIMD3<Float>]

        if depthResult.points.count >= minimumGeometryPointCount {
            source = .depth
            geometryPoints = depthResult.points
        } else {
            let finiteFallback = fallbackPoints.filter {
                $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
            }
            guard finiteFallback.count >= minimumGeometryPointCount else {
                throw NSError(
                    domain: "SplatLab.S13",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "初期3Dデータに必要なdepth/特徴点が不足しています"]
                )
            }
            source = .rawFeaturePoints
            geometryPoints = finiteFallback
        }

        let colors = SplatSeedColorizer.colorize(
            points: geometryPoints,
            frames: colorFrames,
            projectURL: projectURL
        )
        let skySeeds = SplatSkySeeder.makeSeeds(
            frames: colorFrames,
            geometryPoints: geometryPoints,
            projectURL: projectURL
        )
        try writePLY(
            geometryPoints: geometryPoints,
            colors: colors,
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

    private static func depthSeedPoints(
        projectURL: URL,
        frames: [SplatDepthSeedFrame]
    ) -> (points: [SIMD3<Float>], framesUsed: Int) {
        var voxels: [Voxel: SIMD3<Float>] = [:]
        voxels.reserveCapacity(min(maximumDepthSeedPointCount, frames.count * targetSamplesPerFrame))
        var framesUsed = 0

        for frame in frames {
            guard voxels.count < maximumDepthSeedPointCount,
                  let relativePath = frame.depthFilePath,
                  let depthWidth = frame.depthWidth,
                  let depthHeight = frame.depthHeight,
                  let bytesPerRow = frame.depthBytesPerRow,
                  depthWidth > 0,
                  depthHeight > 0,
                  bytesPerRow >= depthWidth * MemoryLayout<Float32>.stride,
                  frame.w > 0,
                  frame.h > 0,
                  frame.flX > 0,
                  frame.flY > 0,
                  let cameraToWorld = matrix(fromRows: frame.transformMatrix),
                  let data = try? Data(contentsOf: projectURL.appendingPathComponent(relativePath)),
                  data.count >= bytesPerRow * depthHeight else {
                continue
            }

            let step = max(
                2,
                Int(sqrt(Double(depthWidth * depthHeight) / Double(targetSamplesPerFrame)))
            )
            var acceptedInFrame = 0

            for y in stride(from: step / 2, to: depthHeight, by: step) {
                for x in stride(from: step / 2, to: depthWidth, by: step) {
                    if voxels.count >= maximumDepthSeedPointCount { break }
                    let offset = y * bytesPerRow + x * MemoryLayout<Float32>.stride
                    guard offset >= 0, offset + 3 < data.count else { continue }
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
                    guard world.x.isFinite, world.y.isFinite, world.z.isFinite else { continue }
                    voxels[Voxel(world)] = world
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
        guard rows.count == 4, rows.allSatisfy({ $0.count == 4 }) else { return nil }
        let matrix = simd_float4x4(
            SIMD4<Float>(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
            SIMD4<Float>(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
            SIMD4<Float>(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
            SIMD4<Float>(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
        )
        guard matrix.columns.0.x.isFinite,
              matrix.columns.1.y.isFinite,
              matrix.columns.2.z.isFinite,
              matrix.columns.3.x.isFinite,
              matrix.columns.3.y.isFinite,
              matrix.columns.3.z.isFinite else { return nil }
        return matrix
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
