import Foundation
import XCTest

final class SplatDepthSeedVoxelFusionTests: XCTestCase {
    func testRepeatedVoxelObservationsAreIndependentOfFrameOrder() throws {
        let forwardProject = try makeProject()
        let reverseProject = try makeProject()
        defer {
            try? FileManager.default.removeItem(at: forwardProject)
            try? FileManager.default.removeItem(at: reverseProject)
        }

        try writeConstantDepth(1.002, to: forwardProject.appendingPathComponent("a.bin"))
        try writeConstantDepth(1.004, to: forwardProject.appendingPathComponent("b.bin"))
        try writeConstantDepth(1.002, to: reverseProject.appendingPathComponent("a.bin"))
        try writeConstantDepth(1.004, to: reverseProject.appendingPathComponent("b.bin"))

        let frameA = makeFrame(path: "a.bin")
        let frameB = makeFrame(path: "b.bin")

        let forward = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: forwardProject,
            depthFrames: [frameA, frameB],
            fallbackPoints: [],
            colorFrames: []
        )
        let reverse = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: reverseProject,
            depthFrames: [frameB, frameA],
            fallbackPoints: [],
            colorFrames: []
        )

        XCTAssertEqual(forward.source, .depth)
        XCTAssertEqual(reverse.source, .depth)
        XCTAssertEqual(forward.depthFrameCount, 2)
        XCTAssertEqual(reverse.depthFrameCount, 2)
        XCTAssertEqual(forward.geometryPointCount, 64)
        XCTAssertEqual(reverse.geometryPointCount, 64)

        let forwardPLY = try Data(contentsOf: forwardProject.appendingPathComponent("points3D.ply"))
        let reversePLY = try Data(contentsOf: reverseProject.appendingPathComponent("points3D.ply"))
        XCTAssertEqual(forwardPLY, reversePLY)
    }

    private func makeFrame(path: String) -> SplatDepthSeedFrame {
        SplatDepthSeedFrame(
            depthFilePath: path,
            depthWidth: 16,
            depthHeight: 16,
            depthBytesPerRow: 16 * MemoryLayout<Float32>.stride,
            transformMatrix: [
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0, 0, 0, 1]
            ],
            flX: 1_000,
            flY: 1_000,
            cx: 8,
            cy: 8,
            w: 16,
            h: 16
        )
    }

    private func writeConstantDepth(_ depth: Float32, to url: URL) throws {
        var data = Data()
        data.reserveCapacity(16 * 16 * MemoryLayout<Float32>.stride)
        let bits = depth.bitPattern.littleEndian
        for _ in 0..<(16 * 16) {
            data.append(UInt8(truncatingIfNeeded: bits))
            data.append(UInt8(truncatingIfNeeded: bits >> 8))
            data.append(UInt8(truncatingIfNeeded: bits >> 16))
            data.append(UInt8(truncatingIfNeeded: bits >> 24))
        }
        try data.write(to: url)
    }

    private func makeProject() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
