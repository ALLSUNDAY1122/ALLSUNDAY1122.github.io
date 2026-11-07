import Foundation
import XCTest
import simd

final class SplatDepthSeedInputSafetyTests: XCTestCase {
    func testProjectLocalRegularDepthFileIsAccepted() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        let depth = project.appendingPathComponent("depth/frame.bin")
        try FileManager.default.createDirectory(
            at: depth.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0, 0, 0, 0]).write(to: depth)

        XCTAssertEqual(
            SplatDepthSeedBuilder.validatedDepthInputURL(
                projectURL: project,
                relativePath: "depth/frame.bin"
            ),
            depth.standardizedFileURL.resolvingSymlinksInPath()
        )
    }

    func testTraversalOutsideProjectIsRejected() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let project = parent.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("outside.bin")
        try Data([0, 0, 0, 0]).write(to: outside)

        XCTAssertNil(
            SplatDepthSeedBuilder.validatedDepthInputURL(
                projectURL: project,
                relativePath: "../outside.bin"
            )
        )
    }

    func testSymlinkEscapingProjectIsRejected() throws {
        let parent = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let project = parent.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("outside.bin")
        try Data([0, 0, 0, 0]).write(to: outside)
        let link = project.appendingPathComponent("depth.bin")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        XCTAssertNil(
            SplatDepthSeedBuilder.validatedDepthInputURL(
                projectURL: project,
                relativePath: "depth.bin"
            )
        )
    }

    func testAbsoluteDepthPathIsRejected() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        XCTAssertNil(
            SplatDepthSeedBuilder.validatedDepthInputURL(
                projectURL: project,
                relativePath: "/tmp/outside.bin"
            )
        )
    }

    func testDepthPixelCentersMapWithoutHalfPixelBias() throws {
        XCTAssertEqual(
            try XCTUnwrap(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
                sampleIndex: 0,
                sourceExtent: 256,
                destinationExtent: 1920
            )),
            3.25,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
                sampleIndex: 255,
                sourceExtent: 256,
                destinationExtent: 1920
            )),
            1915.75,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
                sampleIndex: 37,
                sourceExtent: 256,
                destinationExtent: 256
            )),
            37,
            accuracy: 0.0001
        )
    }

    func testDepthPixelCenterMappingRejectsInvalidExtentsAndIndices() {
        XCTAssertNil(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
            sampleIndex: -1,
            sourceExtent: 256,
            destinationExtent: 1920
        ))
        XCTAssertNil(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
            sampleIndex: 256,
            sourceExtent: 256,
            destinationExtent: 1920
        ))
        XCTAssertNil(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
            sampleIndex: 0,
            sourceExtent: 0,
            destinationExtent: 1920
        ))
        XCTAssertNil(SplatDepthSeedBuilder.imagePixelCenterCoordinate(
            sampleIndex: 0,
            sourceExtent: 256,
            destinationExtent: 0
        ))
    }

    func testMalformedHugeDepthDimensionsFallBackWithoutIntegerTrap() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        let depth = project.appendingPathComponent("depth.bin")
        try Data([0, 0, 0, 0]).write(to: depth)

        let frame = SplatDepthSeedFrame(
            depthFilePath: "depth.bin",
            depthWidth: Int.max,
            depthHeight: Int.max,
            depthBytesPerRow: Int.max,
            transformMatrix: identityMatrix,
            flX: 500,
            flY: 500,
            cx: 320,
            cy: 240,
            w: 640,
            h: 480
        )

        let outcome = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: project,
            depthFrames: [frame],
            fallbackPoints: fallbackPoints(),
            colorFrames: []
        )

        XCTAssertEqual(outcome.source, .rawFeaturePoints)
        XCTAssertEqual(outcome.depthFrameCount, 0)
        XCTAssertEqual(outcome.geometryPointCount, 64)
    }

    func testNonFiniteCameraMetadataCannotEnterDepthSeed() throws {
        let project = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: project) }
        let depth = project.appendingPathComponent("depth.bin")
        try Data(repeating: 0, count: 4 * 4 * 4).write(to: depth)

        let frame = SplatDepthSeedFrame(
            depthFilePath: "depth.bin",
            depthWidth: 4,
            depthHeight: 4,
            depthBytesPerRow: 16,
            transformMatrix: identityMatrix,
            flX: .infinity,
            flY: 500,
            cx: 2,
            cy: 2,
            w: 4,
            h: 4
        )

        let outcome = try SplatDepthSeedBuilder.preparePointCloudPLY(
            projectURL: project,
            depthFrames: [frame],
            fallbackPoints: fallbackPoints(),
            colorFrames: []
        )

        XCTAssertEqual(outcome.source, .rawFeaturePoints)
        XCTAssertEqual(outcome.depthFrameCount, 0)
    }

    private var identityMatrix: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ]
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fallbackPoints() -> [SIMD3<Float>] {
        (0..<64).map { index in
            SIMD3<Float>(Float(index), Float(index % 7), Float(index % 11))
        }
    }
}
