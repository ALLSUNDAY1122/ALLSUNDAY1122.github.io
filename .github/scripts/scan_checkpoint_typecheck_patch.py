from pathlib import Path

path = Path('splat-native-ios/SplatNative/ScanModel.swift')
text = path.read_text()
old = '''        let storedFeatures = featurePoints.map { id, point in
            StoredFeaturePoint(id: id, x: point.x, y: point.y, z: point.z)
        }.sorted { $0.id < $1.id }
        let center = estimatedTargetCenter.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        let previousPosition = previousCoveragePosition.map { StoredVector3(x: $0.x, y: $0.y, z: $0.z) }
        let storedCells = spatialCells.map { StoredGridCell(x: $0.x, z: $0.z) }
            .sorted { lhs, rhs in lhs.x == rhs.x ? lhs.z < rhs.z : lhs.x < rhs.x }
        return ScanCaptureCheckpoint(
            frames: frames,
            featurePoints: storedFeatures,
            coverageSectors: coverageSectors.sorted(),
            estimatedTargetCenter: center,
            lastAcceptedTransform: lastAcceptedTransform.map { Self.rows($0) },
            lastAcceptedTimestamp: lastAcceptedTimestamp,
            elevationBands: elevationBands.sorted(),
            viewDirectionSectors: viewDirectionSectors.sorted(),
            spatialCells: storedCells,
            estimatedSubjectDistance: estimatedSubjectDistance,
            previousCoveragePosition: previousPosition,
            pathLengthMeters: pathLengthMeters,
            accumulatedCaptureSeconds: activeCaptureSeconds,
            ignoreLiDAR: ignoreLiDAR
        )
'''
new = '''        var storedFeatures: [StoredFeaturePoint] = []
        storedFeatures.reserveCapacity(featurePoints.count)
        for (id, point) in featurePoints {
            storedFeatures.append(StoredFeaturePoint(id: id, x: point.x, y: point.y, z: point.z))
        }
        storedFeatures.sort { $0.id < $1.id }

        let center: StoredVector3?
        if let value = estimatedTargetCenter {
            center = StoredVector3(x: value.x, y: value.y, z: value.z)
        } else {
            center = nil
        }

        let previousPosition: StoredVector3?
        if let value = previousCoveragePosition {
            previousPosition = StoredVector3(x: value.x, y: value.y, z: value.z)
        } else {
            previousPosition = nil
        }

        var storedCells: [StoredGridCell] = []
        storedCells.reserveCapacity(spatialCells.count)
        for cell in spatialCells {
            storedCells.append(StoredGridCell(x: cell.x, z: cell.z))
        }
        storedCells.sort { lhs, rhs in
            if lhs.x == rhs.x { return lhs.z < rhs.z }
            return lhs.x < rhs.x
        }

        let storedCoverageSectors: [Int] = coverageSectors.sorted()
        let storedElevationBands: [Int] = elevationBands.sorted()
        let storedViewDirectionSectors: [Int] = viewDirectionSectors.sorted()
        let storedLastTransform: [[Float]]? = lastAcceptedTransform.map(Self.rows)

        let checkpoint = ScanCaptureCheckpoint(
            frames: frames,
            featurePoints: storedFeatures,
            coverageSectors: storedCoverageSectors,
            estimatedTargetCenter: center,
            lastAcceptedTransform: storedLastTransform,
            lastAcceptedTimestamp: lastAcceptedTimestamp,
            elevationBands: storedElevationBands,
            viewDirectionSectors: storedViewDirectionSectors,
            spatialCells: storedCells,
            estimatedSubjectDistance: estimatedSubjectDistance,
            previousCoveragePosition: previousPosition,
            pathLengthMeters: pathLengthMeters,
            accumulatedCaptureSeconds: activeCaptureSeconds,
            ignoreLiDAR: ignoreLiDAR
        )
        return checkpoint
'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'checkpoint typecheck anchor count={count}')
path.write_text(text.replace(old, new, 1))
