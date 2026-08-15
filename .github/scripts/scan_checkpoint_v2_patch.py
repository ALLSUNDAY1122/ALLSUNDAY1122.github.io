from pathlib import Path

path = Path('splat-native-ios/SplatNative/ScanProjectStore.swift')
text = path.read_text()

old = '''struct StoredCapturedFrame: Codable, Equatable {
    var id: Int
    var filePath: String
    var transformMatrix: [[Float]]
    var flX: Float
    var flY: Float
    var cx: Float
    var cy: Float
    var w: Int
    var h: Int
}

struct StoredFeaturePoint: Codable, Equatable {
    var id: UInt64
    var x: Float
    var y: Float
    var z: Float
}

struct StoredVector3: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
}

struct ScanCaptureCheckpoint: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var savedAt: Date
    var frames: [StoredCapturedFrame]
    var featurePoints: [StoredFeaturePoint]
    var coverageSectors: [Int]
    var estimatedTargetCenter: StoredVector3?
    var lastAcceptedTransform: [[Float]]?
    var lastAcceptedTimestamp: TimeInterval

    init(
        savedAt: Date = Date(),
        frames: [StoredCapturedFrame],
        featurePoints: [StoredFeaturePoint],
        coverageSectors: [Int],
        estimatedTargetCenter: StoredVector3?,
        lastAcceptedTransform: [[Float]]?,
        lastAcceptedTimestamp: TimeInterval
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.savedAt = savedAt
        self.frames = frames
        self.featurePoints = featurePoints
        self.coverageSectors = coverageSectors
        self.estimatedTargetCenter = estimatedTargetCenter
        self.lastAcceptedTransform = lastAcceptedTransform
        self.lastAcceptedTimestamp = lastAcceptedTimestamp
    }
}
'''

new = '''struct StoredCapturedFrame: Codable, Equatable {
    var id: Int
    var filePath: String
    var transformMatrix: [[Float]]
    var flX: Float
    var flY: Float
    var cx: Float
    var cy: Float
    var w: Int
    var h: Int
    var depthFilePath: String? = nil
    var depthWidth: Int? = nil
    var depthHeight: Int? = nil
    var depthBytesPerRow: Int? = nil
}

struct StoredFeaturePoint: Codable, Equatable {
    var id: UInt64
    var x: Float
    var y: Float
    var z: Float
}

struct StoredVector3: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
}

struct StoredGridCell: Codable, Equatable {
    var x: Int
    var z: Int
}

struct ScanCaptureCheckpoint: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var savedAt: Date
    var frames: [StoredCapturedFrame]
    var featurePoints: [StoredFeaturePoint]
    var coverageSectors: [Int]
    var estimatedTargetCenter: StoredVector3?
    var lastAcceptedTransform: [[Float]]?
    var lastAcceptedTimestamp: TimeInterval
    var elevationBands: [Int]? = nil
    var viewDirectionSectors: [Int]? = nil
    var spatialCells: [StoredGridCell]? = nil
    var estimatedSubjectDistance: Float? = nil
    var previousCoveragePosition: StoredVector3? = nil
    var pathLengthMeters: Float? = nil
    var accumulatedCaptureSeconds: Double? = nil
    var ignoreLiDAR: Bool? = nil

    init(
        savedAt: Date = Date(),
        frames: [StoredCapturedFrame],
        featurePoints: [StoredFeaturePoint],
        coverageSectors: [Int],
        estimatedTargetCenter: StoredVector3?,
        lastAcceptedTransform: [[Float]]?,
        lastAcceptedTimestamp: TimeInterval,
        elevationBands: [Int]? = nil,
        viewDirectionSectors: [Int]? = nil,
        spatialCells: [StoredGridCell]? = nil,
        estimatedSubjectDistance: Float? = nil,
        previousCoveragePosition: StoredVector3? = nil,
        pathLengthMeters: Float? = nil,
        accumulatedCaptureSeconds: Double? = nil,
        ignoreLiDAR: Bool? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.savedAt = savedAt
        self.frames = frames
        self.featurePoints = featurePoints
        self.coverageSectors = coverageSectors
        self.estimatedTargetCenter = estimatedTargetCenter
        self.lastAcceptedTransform = lastAcceptedTransform
        self.lastAcceptedTimestamp = lastAcceptedTimestamp
        self.elevationBands = elevationBands
        self.viewDirectionSectors = viewDirectionSectors
        self.spatialCells = spatialCells
        self.estimatedSubjectDistance = estimatedSubjectDistance
        self.previousCoveragePosition = previousCoveragePosition
        self.pathLengthMeters = pathLengthMeters
        self.accumulatedCaptureSeconds = accumulatedCaptureSeconds
        self.ignoreLiDAR = ignoreLiDAR
    }
}
'''

count = text.count(old)
if count != 1:
    raise SystemExit(f'checkpoint anchor count={count}')
path.write_text(text.replace(old, new, 1))
