@preconcurrency import ARKit
import CoreVideo
import Foundation
import simd

private struct MeshDepthSampleRecord: Codable, Sendable {
    let file: String
    let timestamp: TimeInterval
    let width: Int
    let height: Int
    let cameraWidth: Int
    let cameraHeight: Int
    let transform: [[Float]]
    let intrinsics: [[Float]]
}

private struct MeshDepthIndex: Codable, Sendable {
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
    private var isWritingSample = false
    private var pendingFinalizeProjectURL: URL?
    private let writeQueue = DispatchQueue(label: "jp.allsunday1122.splatlab.mesh.depth-write", qos: .utility)

    var isRecording: Bool { directoryURL != nil }

    func start() {
        guard directoryURL == nil, !isWritingSample else { return }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let root = documents.appendingPathComponent("SplatLab", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let directory = root.appendingPathComponent("\(UUID().uuidString).depthcapture", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            directoryURL = directory
            samples.removeAll(keepingCapacity: true)
            lastTimestamp = -1
            pendingFinalizeProjectURL = nil
        } catch {
            directoryURL = nil
        }
    }

    func record(frame: ARFrame) {
        guard let directoryURL,
              !isWritingSample,
              frame.timestamp - lastTimestamp >= 0.75,
              let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return }

        let depthMap = sceneDepth.depthMap
        guard CVPixelBufferGetPixelFormatType(depthMap) == kCVPixelFormatType_DepthFloat32 else { return }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap),
              let data = MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: baseAddress,
                width: width,
                height: height,
                sourceRowBytes: CVPixelBufferGetBytesPerRow(depthMap)
              ) else { return }

        let fileName = String(format: "depth_%05d.f32", samples.count)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        let cameraResolution = frame.camera.imageResolution
        let record = MeshDepthSampleRecord(
            file: fileName,
            timestamp: frame.timestamp,
            width: width,
            height: height,
            cameraWidth: Int(cameraResolution.width),
            cameraHeight: Int(cameraResolution.height),
            transform: Self.rows(frame.camera.transform),
            intrinsics: Self.rows3(frame.camera.intrinsics)
        )
        isWritingSample = true

        // Pixel-buffer access above remains synchronous so ARKit-owned memory never crosses
        // executors. The copied Data is value-semantic/Sendable, so the comparatively slow
        // atomic filesystem write can safely leave MainActor and avoid stalling capture UI.
        writeQueue.async { [weak self] in
            let success: Bool
            do {
                try data.write(to: fileURL, options: .atomic)
                success = true
            } catch {
                try? FileManager.default.removeItem(at: fileURL)
                success = false
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.directoryURL == directoryURL else {
                    self.isWritingSample = false
                    return
                }

                self.isWritingSample = false
                if success {
                    self.samples.append(record)
                    self.lastTimestamp = record.timestamp
                }

                if let projectURL = self.pendingFinalizeProjectURL {
                    self.pendingFinalizeProjectURL = nil
                    self.finalize(into: projectURL)
                }
            }
        }
    }

    func finalize(into projectURL: URL) {
        if isWritingSample {
            // Finish is allowed immediately after the user taps stop. Preserve that intent and
            // finalize only after the last in-flight atomic sample write has committed.
            pendingFinalizeProjectURL = projectURL
            return
        }

        guard let directoryURL, !samples.isEmpty else {
            discard()
            return
        }
        do {
            let index = MeshDepthIndex(
                schemaVersion: 2,
                format: "Float32 meters, little-endian, tightly packed row-major; ARCamera intrinsics include source camera resolution",
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

            try Self.validateCaptureDirectory(directoryURL)
            let destination = projectURL.appendingPathComponent("lidar-depth", isDirectory: true)
            try Self.installCaptureDirectory(directoryURL, at: destination)
            self.directoryURL = nil
            samples.removeAll()
            lastTimestamp = -1
            pendingFinalizeProjectURL = nil
        } catch {
            // Temporary capture is intentionally retained for recovery. If a previous
            // lidar-depth generation existed, it remains untouched until validation succeeds.
        }
    }

    static func validateCaptureDirectory(
        _ source: URL,
        fileManager: FileManager = .default
    ) throws {
        let indexURL = source.appendingPathComponent("depth-index.json")
        guard fileManager.fileExists(atPath: indexURL.path) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let index = try decoder.decode(MeshDepthIndex.self, from: Data(contentsOf: indexURL))
        guard index.schemaVersion == 2, !index.samples.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let sourcePath = source.standardizedFileURL.path
        var seenFiles = Set<String>()
        var previousTimestamp: TimeInterval?
        for sample in index.samples {
            guard sample.width > 0,
                  sample.height > 0,
                  sample.cameraWidth > 0,
                  sample.cameraHeight > 0,
                  sample.timestamp.isFinite,
                  previousTimestamp.map({ sample.timestamp > $0 }) ?? true,
                  seenFiles.insert(sample.file).inserted,
                  sample.transform.count == 4,
                  sample.transform.allSatisfy({ $0.count == 4 && $0.allSatisfy(\.isFinite) }),
                  sample.intrinsics.count == 3,
                  sample.intrinsics.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
                  sample.file == URL(fileURLWithPath: sample.file).lastPathComponent,
                  sample.file.hasSuffix(".f32") else {
                throw CocoaError(.fileReadCorruptFile)
            }
            previousTimestamp = sample.timestamp

            let (pixelCount, pixelOverflow) = sample.width.multipliedReportingOverflow(by: sample.height)
            let (expectedBytes, byteOverflow) = pixelCount.multipliedReportingOverflow(by: MemoryLayout<Float>.size)
            guard !pixelOverflow, !byteOverflow, expectedBytes > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let payloadURL = source.appendingPathComponent(sample.file).standardizedFileURL
            let payloadPath = payloadURL.path
            guard payloadPath.hasPrefix(sourcePath + "/"),
                  fileManager.fileExists(atPath: payloadPath) else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let attributes = try fileManager.attributesOfItem(atPath: payloadPath)
            guard (attributes[.type] as? FileAttributeType) == .typeRegular,
                  let fileSize = attributes[.size] as? NSNumber,
                  fileSize.intValue == expectedBytes,
                  try containsUsableDepthSample(payloadURL) else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }

    static func installCaptureDirectory(
        _ source: URL,
        at destination: URL,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: source.path) else {
            throw CocoaError(.fileNoSuchFile)
        }

        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: source, to: destination)
            return
        }

        let backup = destination.deletingLastPathComponent().appendingPathComponent(
            ".\(destination.lastPathComponent).previous-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.moveItem(at: destination, to: backup)

        do {
            try fileManager.moveItem(at: source, to: destination)
            try? fileManager.removeItem(at: backup)
        } catch {
            if !fileManager.fileExists(atPath: destination.path),
               fileManager.fileExists(atPath: backup.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }
    }

    func discard() {
        pendingFinalizeProjectURL = nil
        if let directoryURL {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        directoryURL = nil
        samples.removeAll()
        lastTimestamp = -1
        // If a background write is still finishing, keep the in-flight flag set so a new
        // capture cannot start until that completion returns and releases its retained Data.
    }

    private static func containsUsableDepthSample(_ url: URL) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        while let data = try handle.read(upToCount: 64 * 1024), !data.isEmpty {
            guard data.count % MemoryLayout<Float>.size == 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            for offset in stride(from: 0, to: data.count, by: MemoryLayout<Float>.size) {
                let bits = UInt32(data[offset]) |
                    (UInt32(data[offset + 1]) << 8) |
                    (UInt32(data[offset + 2]) << 16) |
                    (UInt32(data[offset + 3]) << 24)
                let depth = Float(bitPattern: bits)
                if depth.isFinite, depth > 0 {
                    return true
                }
            }
        }
        return false
    }

    private static func rows(_ matrix: simd_float4x4) -> [[Float]] {
        (0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
    }

    private static func rows3(_ matrix: simd_float3x3) -> [[Float]] {
        (0..<3).map { row in (0..<3).map { column in matrix[column][row] } }
    }
}
