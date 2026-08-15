import Foundation
import simd

struct CaptureGridCell: Hashable {
    let x: Int
    let z: Int
}

enum CaptureCoverageMode: Equatable {
    case object
    case scene
}

enum CapturePolicy {
    struct Movement: Equatable {
        let translation: Float
        let rotation: Float
    }

    static func movement(from a: simd_float4x4, to b: simd_float4x4) -> Movement {
        let pa = cameraPosition(a)
        let pb = cameraPosition(b)
        let translation = simd_distance(pa, pb)
        let qa = simd_quatf(a)
        let qb = simd_quatf(b)
        let dot = min(1, max(-1, abs(simd_dot(qa.vector, qb.vector))))
        return Movement(translation: translation, rotation: 2 * acos(dot))
    }

    static func minimumTranslation(subjectDistance: Float?) -> Float {
        guard let subjectDistance, subjectDistance.isFinite, subjectDistance > 0 else {
            return 0.035
        }
        return min(0.12, max(0.018, subjectDistance * 0.045))
    }

    static func shouldAcceptFrame(
        previous: simd_float4x4?,
        current: simd_float4x4,
        subjectDistance: Float?,
        previousTimestamp: TimeInterval,
        currentTimestamp: TimeInterval
    ) -> Bool {
        guard currentTimestamp - previousTimestamp >= 0.16 else { return false }
        guard let previous else { return true }

        let delta = movement(from: previous, to: current)
        let minimum = minimumTranslation(subjectDistance: subjectDistance)

        // Large discontinuities are more likely to be relocalization jumps than useful overlap.
        guard delta.translation <= 1.25 else { return false }

        if delta.translation >= minimum { return true }
        return delta.translation >= minimum * 0.45 && delta.rotation >= 0.09
    }

    static func coverageMode(subjectDistance: Float?) -> CaptureCoverageMode {
        // A reliably detected nearby center is treated as an object capture. In that mode,
        // walking/turning around on one side must never satisfy the scene coverage fallback.
        guard let subjectDistance, subjectDistance.isFinite, subjectDistance > 0 else {
            return .scene
        }
        return subjectDistance <= 1.50 ? .object : .scene
    }

    static func orbitSector(
        cameraPosition: SIMD3<Float>,
        center: SIMD3<Float>,
        count: Int
    ) -> Int? {
        guard count > 0 else { return nil }
        let dx = cameraPosition.x - center.x
        let dz = cameraPosition.z - center.z
        guard hypot(dx, dz) >= 0.08 else { return nil }
        let angle = atan2(dx, dz)
        let normalized = (angle + .pi) / (2 * .pi)
        return min(count - 1, max(0, Int(floor(normalized * Float(count)))))
    }

    static func viewDirectionSector(transform: simd_float4x4, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let forward = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let angle = atan2(forward.x, forward.z)
        let normalized = (angle + .pi) / (2 * .pi)
        return min(count - 1, max(0, Int(floor(normalized * Float(count)))))
    }

    static func elevationBand(cameraPosition: SIMD3<Float>, center: SIMD3<Float>) -> Int? {
        let delta = cameraPosition - center
        let horizontal = hypot(delta.x, delta.z)
        guard horizontal >= 0.08 else { return nil }
        let angle = atan2(delta.y, horizontal)
        if angle < -0.18 { return 0 }
        if angle > 0.18 { return 2 }
        return 1
    }

    static func spatialCell(cameraPosition: SIMD3<Float>, cellSize: Float = 0.25) -> CaptureGridCell {
        let safeSize = max(0.10, cellSize)
        return CaptureGridCell(
            x: Int(floor(cameraPosition.x / safeSize)),
            z: Int(floor(cameraPosition.z / safeSize))
        )
    }

    static func objectCoverageSatisfied(orbitSectors: Int, elevationBands: Int) -> Bool {
        orbitSectors >= 8 && elevationBands >= 2
    }

    static func sceneCoverageSatisfied(
        viewDirectionSectors: Int,
        spatialCells: Int,
        pathLength: Float
    ) -> Bool {
        viewDirectionSectors >= 5 && spatialCells >= 5 && pathLength >= 0.80
    }

    static func coverageSatisfied(
        subjectDistance: Float?,
        orbitSectors: Int,
        elevationBands: Int,
        viewDirectionSectors: Int,
        spatialCells: Int,
        pathLength: Float
    ) -> Bool {
        switch coverageMode(subjectDistance: subjectDistance) {
        case .object:
            return objectCoverageSatisfied(
                orbitSectors: orbitSectors,
                elevationBands: elevationBands
            )
        case .scene:
            return sceneCoverageSatisfied(
                viewDirectionSectors: viewDirectionSectors,
                spatialCells: spatialCells,
                pathLength: pathLength
            )
        }
    }

    static func coverageScore(
        subjectDistance: Float?,
        orbitSectors: Int,
        elevationBands: Int,
        viewDirectionSectors: Int,
        spatialCells: Int,
        pathLength: Float
    ) -> Float {
        let objectScore = min(1, Float(orbitSectors) / 8) * 0.82
            + min(1, Float(elevationBands) / 2) * 0.18
        let sceneScore = min(1, Float(viewDirectionSectors) / 5) * 0.35
            + min(1, Float(spatialCells) / 5) * 0.30
            + min(1, pathLength / 0.80) * 0.35

        switch coverageMode(subjectDistance: subjectDistance) {
        case .object:
            return min(1, objectScore)
        case .scene:
            return min(1, sceneScore)
        }
    }

    static func cameraPosition(_ transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}
