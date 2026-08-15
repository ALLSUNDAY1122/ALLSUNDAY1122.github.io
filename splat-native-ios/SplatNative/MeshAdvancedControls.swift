@preconcurrency import ARKit
import Foundation
import RealityKit
import SceneKit
import SwiftUI
import UIKit
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
            try encoder.encode(index).write(to: directoryURL.appendingPathComponent("depth-index.json"), options: .atomic)

            let destination = projectURL.appendingPathComponent("lidar-depth", isDirectory: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: directoryURL, to: destination)
            self.directoryURL = nil
            samples.removeAll()
            lastTimestamp = -1
        } catch {
            // Keep the temporary capture on disk so recovery remains possible.
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

struct MeshRawProject: Identifiable, Sendable {
    let id: String
    let url: URL
    let imagesURL: URL
    let imageCount: Int
    let modifiedAt: Date
}

enum MeshRawProjectStore {
    static func discover() -> [MeshRawProject] {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        let root = documents.appendingPathComponent("SplatLab", isDirectory: true)
        guard let urls = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return urls.compactMap { projectURL in
            guard projectURL.pathExtension == "meshproject" else { return nil }
            let imagesURL = projectURL.appendingPathComponent("images", isDirectory: true)
            guard let imageFiles = try? fileManager.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil),
                  !imageFiles.isEmpty else { return nil }
            let imageCount = imageFiles.filter { ["jpg", "jpeg", "heic", "png"].contains($0.pathExtension.lowercased()) }.count
            guard imageCount > 0 else { return nil }
            let values = try? projectURL.resourceValues(forKeys: [.contentModificationDateKey])
            return MeshRawProject(
                id: projectURL.lastPathComponent,
                url: projectURL,
                imagesURL: imagesURL,
                imageCount: imageCount,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }
}

@MainActor
enum MeshRawReprocessor {
    static func run(project: MeshRawProject, model: MeshScanModel) async {
        guard PhotogrammetrySession.isSupported else {
            model.phase = .failed("この端末では端末内PhotogrammetrySessionによるraw再処理を実行できません。")
            return
        }

        let formatter = ISO8601DateFormatter()
        let safeStamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outputURL = project.url.appendingPathComponent("mesh-reprocessed-\(safeStamp).usdz")
        try? FileManager.default.removeItem(at: outputURL)

        model.phase = .reconstructing
        model.reconstructionProgress = 0
        model.statusMessage = "保存済みraw画像からMeshを再処理しています"

        do {
            var configuration = PhotogrammetrySession.Configuration()
            configuration.isObjectMaskingEnabled = true
            let session = try PhotogrammetrySession(input: project.imagesURL, configuration: configuration)
            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced, geometry: nil)
            try session.process(requests: [request])

            for try await output in session.outputs {
                switch output {
                case .requestProgress(_, let fractionComplete):
                    model.reconstructionProgress = fractionComplete
                case .inputComplete:
                    model.statusMessage = "raw画像の取り込み完了。Meshを再構築しています"
                case .requestComplete(_, _):
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        model.resultURL = outputURL
                        model.previewScene = try? SCNScene(url: outputURL, options: nil)
                        model.reconstructionProgress = 1
                        model.phase = .finished
                        model.statusMessage = "保存済みrawから再処理したMeshを生成しました"
                    }
                case .requestError(_, let error):
                    model.phase = .failed("raw再処理に失敗しました: \(error.localizedDescription)")
                case .invalidSample(_, _), .skippedSample(_):
                    model.invalidPhotogrammetrySamples += 1
                case .automaticDownsampling:
                    model.statusMessage = "raw再処理中: 端末負荷を抑えるため画像を自動縮小しています"
                case .stitchingIncomplete:
                    model.statusMessage = "raw再処理中: 一部画像を接続できませんでした"
                case .processingCancelled:
                    model.phase = .captured
                    model.statusMessage = "raw再処理を中断しました"
                case .processingComplete:
                    if model.resultURL == nil && FileManager.default.fileExists(atPath: outputURL.path) {
                        model.resultURL = outputURL
                        model.previewScene = try? SCNScene(url: outputURL, options: nil)
                        model.reconstructionProgress = 1
                        model.phase = .finished
                        model.statusMessage = "保存済みrawから再処理したMeshを生成しました"
                    }
                case .requestProgressInfo(_, _):
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            model.phase = .failed("raw再処理を開始できませんでした: \(error.localizedDescription)")
        }
    }
}

private struct MeshSimplifyResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
}

private struct MeshClusterKey: Hashable, Sendable {
    let x: Int
    let y: Int
    let z: Int
}

private enum MeshOBJSimplifier {
    static func simplify(url: URL, retainedFraction: Double) throws -> MeshSimplifyResult {
        let source = try String(contentsOf: url, encoding: .utf8)
        var vertices: [SIMD3<Float>] = []
        var faces: [SIMD3<Int>] = []

        for line in source.split(whereSeparator: \ .isNewline) {
            if line.hasPrefix("v ") {
                let parts = line.split(separator: " ")
                guard parts.count >= 4,
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else { continue }
                vertices.append(SIMD3<Float>(x, y, z))
            } else if line.hasPrefix("f ") {
                let parts = line.split(separator: " ")
                guard parts.count >= 4 else { continue }
                let parsed = parts[1...3].compactMap { token -> Int? in
                    guard let first = token.split(separator: "/").first,
                          let oneBased = Int(first), oneBased > 0 else { return nil }
                    return oneBased - 1
                }
                guard parsed.count == 3 else { continue }
                faces.append(SIMD3<Int>(parsed[0], parsed[1], parsed[2]))
            }
        }

        guard vertices.count >= 8, !faces.isEmpty else {
            throw NSError(domain: "ScanLab.MeshSimplifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "OBJに十分な三角形Meshがありません"])
        }

        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for vertex in vertices {
            minimum = simd_min(minimum, vertex)
            maximum = simd_max(maximum, vertex)
        }
        let extent = simd_max(maximum - minimum, SIMD3<Float>(repeating: 0.0001))
        let targetVertexCount = max(8, Int(Double(vertices.count) * min(0.95, max(0.1, retainedFraction))))
        let resolution = max(2, Int(ceil(pow(Double(targetVertexCount), 1.0 / 3.0))))
        let cell = extent / Float(resolution)

        var sums: [MeshClusterKey: SIMD3<Float>] = [:]
        var counts: [MeshClusterKey: Int] = [:]
        var vertexKeys: [MeshClusterKey] = []
        vertexKeys.reserveCapacity(vertices.count)

        for vertex in vertices {
            let relative = (vertex - minimum) / cell
            let key = MeshClusterKey(
                x: min(resolution - 1, max(0, Int(floor(relative.x)))),
                y: min(resolution - 1, max(0, Int(floor(relative.y)))),
                z: min(resolution - 1, max(0, Int(floor(relative.z))))
            )
            vertexKeys.append(key)
            sums[key, default: .zero] += vertex
            counts[key, default: 0] += 1
        }

        let orderedKeys = sums.keys.sorted {
            if $0.x != $1.x { return $0.x < $1.x }
            if $0.y != $1.y { return $0.y < $1.y }
            return $0.z < $1.z
        }
        var remap: [MeshClusterKey: Int] = [:]
        var simplifiedVertices: [SIMD3<Float>] = []
        simplifiedVertices.reserveCapacity(orderedKeys.count)
        for key in orderedKeys {
            let index = simplifiedVertices.count
            remap[key] = index
            simplifiedVertices.append((sums[key] ?? .zero) / Float(max(1, counts[key] ?? 1)))
        }

        var simplifiedFaces: [SIMD3<Int>] = []
        var faceSet = Set<String>()
        for face in faces {
            guard face.x < vertexKeys.count, face.y < vertexKeys.count, face.z < vertexKeys.count,
                  let a = remap[vertexKeys[face.x]],
                  let b = remap[vertexKeys[face.y]],
                  let c = remap[vertexKeys[face.z]],
                  a != b, b != c, a != c else { continue }
            let key = "\(a):\(b):\(c)"
            guard faceSet.insert(key).inserted else { continue }
            simplifiedFaces.append(SIMD3<Int>(a, b, c))
        }

        guard !simplifiedFaces.isEmpty else {
            throw NSError(domain: "ScanLab.MeshSimplifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "簡略化後に有効な三角形が残りませんでした"])
        }

        let percent = Int((retainedFraction * 100).rounded())
        let outputURL = url.deletingLastPathComponent().appendingPathComponent("mesh-simplified-\(percent).obj")
        var output = "# Scan Lab vertex-cluster simplified mesh\n"
        output += "# source vertices \(vertices.count) faces \(faces.count)\n"
        output += "# simplified vertices \(simplifiedVertices.count) faces \(simplifiedFaces.count)\n"
        for vertex in simplifiedVertices {
            output += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        for face in simplifiedFaces {
            output += "f \(face.x + 1) \(face.y + 1) \(face.z + 1)\n"
        }
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
        return MeshSimplifyResult(url: outputURL, vertexCount: simplifiedVertices.count, faceCount: simplifiedFaces.count)
    }
}

@MainActor
struct MeshRawReprocessSheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    @State private var projects = MeshRawProjectStore.discover()

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "再処理できるrawがありません",
                        systemImage: "externaldrive.badge.xmark",
                        description: Text("Mesh撮影を完了するとRGB rawが.meshproject内に保持されます。")
                    )
                } else {
                    List(projects) { project in
                        Button {
                            dismiss()
                            Task { await MeshRawReprocessor.run(project: project, model: model) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.id)
                                    .font(.subheadline.monospaced())
                                Text("画像 \(project.imageCount)枚")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!PhotogrammetrySession.isSupported)
                    }
                }
            }
            .navigationTitle("rawから再処理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

@MainActor
struct MeshSimplifySheet: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    let sourceURL: URL
    @State private var retainedFraction = 0.55
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Mesh簡略化") {
                    HStack {
                        Text("目標密度")
                        Spacer()
                        Text("\(Int(retainedFraction * 100))%")
                            .monospacedDigit()
                    }
                    Slider(value: $retainedFraction, in: 0.2...0.9, step: 0.05)
                    Text("頂点クラスタリングで実ジオメトリを削減します。元OBJは保持されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red)
                    }
                }
                Section {
                    Button(isWorking ? "簡略化中…" : "簡略化OBJを生成") {
                        isWorking = true
                        errorText = nil
                        let url = sourceURL
                        let fraction = retainedFraction
                        Task {
                            do {
                                let result = try await Task.detached(priority: .userInitiated) {
                                    try MeshOBJSimplifier.simplify(url: url, retainedFraction: fraction)
                                }.value
                                model.rawOBJURL = result.url
                                model.resultURL = result.url
                                model.previewScene = try? SCNScene(url: result.url, options: nil)
                                model.vertexCount = result.vertexCount
                                model.faceCount = result.faceCount
                                model.statusMessage = "簡略化した実Meshを生成しました"
                                isWorking = false
                                dismiss()
                            } catch {
                                isWorking = false
                                errorText = error.localizedDescription
                            }
                        }
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Meshを軽量化")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

@MainActor
struct MeshAdvancedSupervisor: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var depthRecorder = MeshDepthRecorder()
    @State private var isPaused = false
    @State private var autoPaused = false
    @State private var showingRawReprocess = false
    @State private var showingSimplifier = false

    var body: some View {
        ZStack {
            if model.phase == .scanning {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if isPaused { resumeCapture() } else { pauseCapture(auto: false) }
                        } label: {
                            Label(isPaused ? "再開" : "一時停止", systemImage: isPaused ? "play.fill" : "pause.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.72), in: Capsule())
                        }
                    }
                    .padding(.top, 72)
                    .padding(.trailing, 16)
                    Spacer()
                }
            } else if model.phase == .ready {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showingRawReprocess = true
                        } label: {
                            Label("raw再処理", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.top, 70)
                    .padding(.trailing, 18)
                    Spacer()
                }
            } else if model.phase == .finished,
                      model.resultURL?.pathExtension.lowercased() == "obj",
                      model.rawOBJURL != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingSimplifier = true
                        } label: {
                            Label("Mesh軽量化", systemImage: "square.3.layers.3d.down.right")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.mint, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 320)
                }
            }
        }
        .sheet(isPresented: $showingRawReprocess) {
            MeshRawReprocessSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $showingSimplifier) {
            if let url = model.rawOBJURL {
                MeshSimplifySheet(sourceURL: url)
                    .environmentObject(model)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                if model.phase == .scanning && !isPaused {
                    pauseCapture(auto: true)
                }
            case .active:
                if model.phase == .scanning && autoPaused {
                    resumeCapture()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .ready {
                isPaused = false
                autoPaused = false
                if depthRecorder.isRecording { depthRecorder.discard() }
            }
            if newPhase != .scanning {
                isPaused = false
                autoPaused = false
            }
        }
        .onChange(of: model.resultURL) { _, newURL in
            guard let newURL, depthRecorder.isRecording else { return }
            depthRecorder.finalize(into: newURL.deletingLastPathComponent())
        }
        .task(id: model.phase) {
            guard model.phase == .scanning, model.mode == .lidar else { return }
            if !depthRecorder.isRecording { depthRecorder.start() }
            while !Task.isCancelled && model.phase == .scanning {
                if !isPaused, let frame = model.session?.currentFrame {
                    depthRecorder.record(frame: frame)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    private func pauseCapture(auto: Bool) {
        guard model.phase == .scanning else { return }
        model.session?.pause()
        isPaused = true
        autoPaused = auto
        model.statusMessage = auto ? "バックグラウンド移行のため撮影を自動停止しました" : "撮影を一時停止しました"
    }

    private func resumeCapture() {
        guard model.phase == .scanning, let session = model.session else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        if model.mode == .lidar {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                configuration.sceneReconstruction = .meshWithClassification
            } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
        }
        session.run(configuration, options: [])
        isPaused = false
        autoPaused = false
        model.statusMessage = "撮影を再開しました。既存の追跡状態を維持して続けます"
    }
}

struct MeshScanContainerView: View {
    @EnvironmentObject var model: MeshScanModel

    var body: some View {
        ZStack {
            MeshScanView()
                .environmentObject(model)
            MeshAdvancedSupervisor()
                .environmentObject(model)
        }
    }
}
