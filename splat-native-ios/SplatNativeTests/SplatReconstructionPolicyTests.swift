import XCTest
import Msplat
import UIKit
import simd

final class SplatReconstructionPolicyTests: XCTestCase {
    func testStandardProfileKeepsFullSHAndProgressiveRefinement() {
        let config = SplatReconstructionPolicy.makeConfig()
        XCTAssertEqual(config.iterations, 30_000)
        XCTAssertEqual(config.shDegree, 3)
        XCTAssertEqual(config.shDegreeInterval, 1_000)
        XCTAssertEqual(config.numDownscales, 1)
        XCTAssertEqual(config.resolutionSchedule, 2_000)
        XCTAssertEqual(config.warmupLength, 500)
        XCTAssertEqual(config.resetAlphaEvery, 30)
        XCTAssertEqual(config.stopScreenSizeAt, 4_000)
        XCTAssertEqual(config.ssimWeight, 0.2, accuracy: 0.0001)
    }

    func testEnhancementAddsRepeatedWorkUntilTrainingHorizon() {
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 7_000), 12_000)
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 12_000), 17_000)
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 29_000), 30_000)
        XCTAssertEqual(SplatReconstructionPolicy.enhancementTarget(from: 30_000), 30_000)
    }

    func testResourceLimitsScaleWithDeviceMemoryAndRemainBounded() {
        let gib: UInt64 = 1_073_741_824
        let low = SplatResourceLimits.conservative(physicalMemoryBytes: 3 * gib)
        let high = SplatResourceLimits.conservative(physicalMemoryBytes: 8 * gib)

        XCTAssertGreaterThanOrEqual(low.residentMemoryBudgetBytes, 700 * 1_048_576)
        XCTAssertLessThanOrEqual(high.residentMemoryBudgetBytes, 1_536 * 1_048_576)
        XCTAssertGreaterThan(high.maxSplatCount, low.maxSplatCount)
        XCTAssertGreaterThanOrEqual(low.maxSplatCount, 300_000)
        XCTAssertLessThanOrEqual(high.maxSplatCount, 900_000)
    }

    func testSyntheticHighDensityTriggersCheckpointPauseBeforeUnboundedGrowth() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 4 * 1_073_741_824)
        guardrail.resetForPass()
        let safe = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount - 1,
            residentMemoryBytes: guardrail.limits.residentMemoryBudgetBytes - 1
        )
        XCTAssertNil(safe.reason)

        let saturated = guardrail.evaluate(
            splatCount: guardrail.limits.maxSplatCount,
            residentMemoryBytes: guardrail.limits.residentMemoryBudgetBytes - 1
        )
        XCTAssertEqual(saturated.reason, .splatBudget)
        XCTAssertEqual(saturated.peakSplatCount, guardrail.limits.maxSplatCount)
    }

    func testSyntheticMemoryPressureRecordsPeakAndPauses() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 4 * 1_073_741_824)
        guardrail.resetForPass()
        let first = guardrail.evaluate(splatCount: 250_000, residentMemoryBytes: 500_000_000)
        XCTAssertNil(first.reason)

        let pressure = guardrail.evaluate(
            splatCount: 300_000,
            residentMemoryBytes: guardrail.limits.residentMemoryBudgetBytes
        )
        XCTAssertEqual(pressure.reason, .residentMemoryBudget)
        XCTAssertEqual(pressure.peakResidentMemoryBytes, guardrail.limits.residentMemoryBudgetBytes)
        XCTAssertEqual(pressure.peakSplatCount, 300_000)
    }

    func testMemoryWarningOverridesOtherwiseSafeResourceSnapshot() {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()
        guardrail.noteMemoryWarning()
        let evaluation = guardrail.evaluate(splatCount: 10_000, residentMemoryBytes: 100_000_000)
        XCTAssertEqual(evaluation.reason, .memoryWarning)
    }

    func testRunReportCapturesSyntheticPeakMemory() throws {
        let guardrail = SplatResourceGuard(physicalMemoryBytes: 8 * 1_073_741_824)
        guardrail.resetForPass()
        _ = guardrail.evaluate(splatCount: 120_000, residentMemoryBytes: 640_000_000)
        _ = guardrail.evaluate(splatCount: 180_000, residentMemoryBytes: 720_000_000)
        let report = guardrail.makeReport(
            startedAt: Date(timeIntervalSince1970: 1),
            startUptime: ProcessInfo.processInfo.systemUptime,
            passStartIteration: 0,
            targetIteration: 7_000,
            finalIteration: 4_200,
            finalSplatCount: 180_000,
            initialThermalState: "nominal",
            finalThermalState: "fair",
            outcome: "synthetic-stress"
        )
        XCTAssertEqual(report.peakResidentMemoryBytes, 720_000_000)
        XCTAssertEqual(report.peakSplatCount, 180_000)
        XCTAssertEqual(report.outcome, "synthetic-stress")
        XCTAssertEqual(report.schemaVersion, 1)
    }

    func testSeedProjectionUsesARKitMinusZForwardAndImageTopLeftCoordinates() {
        let frame = SplatSeedFrame(
            filePath: "unused.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )

        let center = SplatSeedColorizer.project(point: SIMD3<Float>(0, 0, -1), frame: frame)
        XCTAssertEqual(center?.x ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(center?.y ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(center?.z ?? -1, 1, accuracy: 0.001)

        let upper = SplatSeedColorizer.project(point: SIMD3<Float>(0, 0.5, -1), frame: frame)
        XCTAssertEqual(upper?.y ?? -1, 5, accuracy: 0.001)
    }

    func testSeedColorizerSamplesProjectedPixelsFromCapturedFrame() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splat-seed-color-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 10, width: 20, height: 10))
        }
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: root.appendingPathComponent("frame.png"))

        let frame = SplatSeedFrame(
            filePath: "frame.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )
        let colors = SplatSeedColorizer.colorize(
            points: [SIMD3<Float>(0, 0.5, -1), SIMD3<Float>(0, -0.5, -1)],
            frames: [frame],
            projectURL: root
        )

        XCTAssertEqual(colors.count, 2)
        XCTAssertGreaterThan(colors[0].red, 220)
        XCTAssertLessThan(colors[0].blue, 40)
        XCTAssertGreaterThan(colors[1].blue, 220)
        XCTAssertLessThan(colors[1].red, 40)
    }

    func testSkyClassifierIsConservative() {
        XCTAssertTrue(SplatSkySeeder.isHighConfidenceSky(
            SplatSeedSample(red: 70, green: 145, blue: 220),
            sceneLuma: 0.40
        ))
        XCTAssertTrue(SplatSkySeeder.isHighConfidenceSky(
            SplatSeedSample(red: 225, green: 228, blue: 232),
            sceneLuma: 0.55
        ))
        XCTAssertFalse(SplatSkySeeder.isHighConfidenceSky(
            SplatSeedSample(red: 210, green: 210, blue: 210),
            sceneLuma: 0.78
        ))
        XCTAssertFalse(SplatSkySeeder.isHighConfidenceSky(
            SplatSeedSample(red: 40, green: 60, blue: 90),
            sceneLuma: 0.35
        ))
    }

    func testSkySeedRayIsPlacedAtFarFieldDistance() throws {
        let frame = SplatSeedFrame(
            filePath: "unused.png",
            transformMatrix: identityRows,
            flX: 10,
            flY: 10,
            cx: 10,
            cy: 10,
            w: 20,
            h: 20
        )
        let point = try XCTUnwrap(SplatSkySeeder.worldPoint(
            normalizedX: 0.5,
            normalizedY: 0.5,
            frame: frame,
            distance: 20
        ))
        XCTAssertEqual(point.x, 0, accuracy: 0.001)
        XCTAssertEqual(point.y, 0, accuracy: 0.001)
        XCTAssertEqual(point.z, -20, accuracy: 0.001)
    }

    private var identityRows: [[Float]] {
        [
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1],
        ]
    }
}
