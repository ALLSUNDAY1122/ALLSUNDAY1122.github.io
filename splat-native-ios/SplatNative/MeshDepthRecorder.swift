@preconcurrency import ARKit
import CoreVideo
import Foundation
import simd

private struct MeshDepthSampleRecord: Codable {
    let file: String
    let timestamp: TimeInterval
    let width: Int
    let height: Int
    let transform: [[Float]]
    let intrinsics: [[Float]]
}

private struct MeshDepthIndex: Codable {
    let schemaVersion: Int
    let format: String
    let createdAt: Date
    let samples: [MeshDepthSampleRecord]
}

@MainActor
final class MeshDepthRecorder: ObservableObject {
    private var directoryURL: URL?
    private var samples: [MeshDepthSampleRecord] = []
    private var lastTimestamp: TimeInterval = -1

    var isRecording: Bool { directoryURL != nil }

    func start() {
        guard directoryURL == nil else { return }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let root = documents.appendingPathComponent("SplatLab", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let directory = root.appendingPathComponent("\(UUID().uuidString).depthcapture", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            directoryURL = directory
            samples.removeAll(keepingCapacity: true)
            lastTimestamp = -1
        } catch {
            directoryURL = nil
        }
    }

    func record(frame: ARFrame) {
        guard let directoryURL,
              frame.timestamp - lastTimestamp >= 1.0,
              let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }

        let depthMap = sceneDepth.depthMap
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else { return }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerPixel = MemoryLayout<Float>.size
        let rowBytes = width * bytesPerPixel

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }

        let sourceRowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        var data = Data(capacity: rowBytes * height)
        for row in 0..<height {
            data.append(Data(bytes: baseAddress.advanced(by: row * sourceRowBytes), count: rowBytes))
        }

        let fileName = String(format: "depth_%05d.f32", samples.count)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            samples.append(MeshDepthSampleRecord(
                file: fileName,
                timestamp: frame.timestamp,
                width: width,
                height: height,
                transform: Self.rows(frame.camera.transform),
                intrinsics: Self.rows3(frame.camera.intrinsics)
            ))
            lastTimestamp = frame.timestamp
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func finalize(into projectURL: URL) {
        guard let directoryURL, !samples.isEmpty else {
            discard()
            return
        }
        do {
            let index = MeshDepthIndex(
                schemaVersion: 1,
                format: "Float32 meters, little-endian, tightly packed row-major",
                createdAt: Date(),
                samples: samples
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(index).write(
                to: directoryURL.appendingPathComponent("depth-index.json"),
                options: .atomic
            )

            let destination = projectURL.appendingPathComponent("lidar-depth", isDirectory: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: directoryURL, to: destination)
            self.directoryURL = nil
            samples.removeAll()
            lastTimestamp = -1
        } catch {
            // Temporary capture is intentionally retained for recovery.
        }
    }

    func discard() {
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
        samples.removeAll()
        lastTimestamp = -1
    }

    private static func rows(_ matrix: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
    }

    private static func rows3(_ matrix: simd_float3x3) -> [[Float]] {
        (0..<3).map { row in (0..<3).map { column in matrix[column][row] } }
    }
}
