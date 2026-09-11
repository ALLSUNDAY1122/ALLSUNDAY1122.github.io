import Foundation
import RealityKit
import SceneKit
import SwiftUI

enum MeshRawProjectStore {
    static func discover() -> [MeshRawProject] {
        MeshRawProjectBridge.discover()
    }
}

@MainActor
enum MeshRawReprocessor {
    static func run(project: MeshRawProject, model: MeshScanModel) async {
        guard PhotogrammetrySession.isSupported else {
            model.phase = .failed("この端末では端末内PhotogrammetrySessionによるraw再処理を実行できません。")
            return
        }

        let prepared: PreparedMeshRawProject
        do {
            prepared = try MeshRawProjectBridge.prepareWorkingProject(for: project)
        } catch {
            model.phase = .failed(error.localizedDescription)
            return
        }

        // A UUID keeps retries independent even when two reprocess attempts begin in the same second.
        // Never reuse a stale derived filename: a failed remove/write must not make an older USDZ
        // look like the output of the current request.
        let outputURL = prepared.projectURL.appendingPathComponent("mesh-reprocessed-\(UUID().uuidString).usdz")

        model.mode = .photogrammetry
        model.resultURL = nil
        model.rawOBJURL = nil
        model.previewScene = nil
        model.phase = .reconstructing
        model.reconstructionProgress = 0
        model.invalidPhotogrammetrySamples = 0
        model.statusMessage = project.sourceKind == .splatProject
            ? "保存済みSplat rawからMeshを再処理しています"
            : "保存済みMesh rawからMeshを再処理しています"

        do {
            var configuration = PhotogrammetrySession.Configuration()
            configuration.isObjectMaskingEnabled = true
            let session = try PhotogrammetrySession(input: prepared.imagesURL, configuration: configuration)
            let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced, geometry: nil)
            try session.process(requests: [request])

            var completed = false
            for try await output in session.outputs {
                try Task.checkCancellation()
                switch output {
                case .requestProgress(_, let fractionComplete):
                    model.reconstructionProgress = fractionComplete
                case .inputComplete:
                    model.statusMessage = "raw画像の取り込み完了。Meshを再構築しています"
                case .requestComplete(_, _):
                    if validateAndFinish(outputURL: outputURL, sourceKind: project.sourceKind, model: model) {
                        completed = true
                    }
                case .requestError(_, let error):
                    throw error
                case .invalidSample(_, _), .skippedSample(_):
                    model.invalidPhotogrammetrySamples += 1
                case .automaticDownsampling:
                    model.statusMessage = "raw再処理中: 端末負荷を抑えるため画像を自動縮小しています"
                case .stitchingIncomplete:
                    model.statusMessage = "raw再処理中: 一部画像を接続できませんでした"
                case .processingCancelled:
                    cleanupFailedOutput(outputURL, prepared: prepared)
                    model.phase = .captured
                    model.statusMessage = "raw再処理を中断しました。保存rawは保持されています"
                    return
                case .processingComplete:
                    if !completed,
                       validateAndFinish(outputURL: outputURL, sourceKind: project.sourceKind, model: model) {
                        completed = true
                    }
                case .requestProgressInfo(_, _):
                    break
                @unknown default:
                    break
                }
            }

            if !completed {
                cleanupFailedOutput(outputURL, prepared: prepared)
                model.resultURL = nil
                model.previewScene = nil
                model.phase = .failed("raw再処理は完了しましたが、完成Meshを正常に読み込めませんでした。保存rawは保持されています。")
            }
        } catch is CancellationError {
            cleanupFailedOutput(outputURL, prepared: prepared)
            model.phase = .captured
            model.statusMessage = "raw再処理を中断しました。保存rawは保持されています"
        } catch {
            cleanupFailedOutput(outputURL, prepared: prepared)
            model.phase = .failed("raw再処理に失敗しました: \(error.localizedDescription)。保存rawは保持されています。")
        }
    }

    /// A PhotogrammetrySession request is not considered complete merely because a path exists.
    /// Require a non-empty regular file, a SceneKit decode, and at least one actual geometry node
    /// before exposing it as a finished result. This prevents a truncated, stale, or structurally
    /// empty USDZ from entering preview, save, or export flows.
    private static func validateAndFinish(
        outputURL: URL,
        sourceKind: MeshRawSourceKind,
        model: MeshScanModel
    ) -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: outputURL.path),
              let attributes = try? fileManager.attributesOfItem(atPath: outputURL.path),
              (attributes[.type] as? FileAttributeType) == .typeRegular,
              let size = (attributes[.size] as? NSNumber)?.uint64Value,
              size > 0,
              let scene = try? SCNScene(url: outputURL, options: nil),
              sceneContainsGeometry(scene) else {
            return false
        }

        model.resultURL = outputURL
        model.previewScene = scene
        model.reconstructionProgress = 1
        model.phase = .finished
        model.statusMessage = sourceKind == .splatProject
            ? "保存済みSplat rawからMeshを生成しました。ライブラリへ安全に保存しています"
            : "保存済みMesh rawから再処理したMeshを生成しました"
        return true
    }

    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains no mesh
    /// geometry. Treat that as reconstruction failure rather than a finished user-visible asset.
    private static func sceneContainsGeometry(_ scene: SCNScene) -> Bool {
        if scene.rootNode.geometry != nil {
            return true
        }
        var containsGeometry = false
        scene.rootNode.enumerateChildNodes { node, stop in
            guard node.geometry != nil else { return }
            containsGeometry = true
            stop.pointee = true
        }
        return containsGeometry
    }

    /// Derived one-shot USDZ output must never survive a failed/cancelled request. For transient
    /// bridge workspaces the whole directory is disposable; for a live Mesh project only the
    /// UUID-named candidate is disposable, so remove that candidate explicitly before asking the
    /// bridge to clean up derived containers.
    private static func cleanupFailedOutput(_ outputURL: URL, prepared: PreparedMeshRawProject) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }
        MeshRawProjectBridge.cleanupDerivedWorkingProject(projectURL: prepared.projectURL)
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
                        description: Text("保存済みMesh rawとSplat rawのうち、再処理に必要な画像・pose・point cloudが残っているものを表示します。")
                    )
                } else {
                    List(projects) { project in
                        Button {
                            dismiss()
                            Task { await MeshRawReprocessor.run(project: project, model: model) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: project.sourceKind == .splatProject ? "sparkles" : "cube")
                                    .foregroundStyle(.mint)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(project.sourceKind.displayName) ・ 画像 \(project.imageCount)枚")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(project.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(!PhotogrammetrySession.isSupported)
                    }
                }
            }
            .navigationTitle("rawからMesh再処理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .refreshable {
                projects = MeshRawProjectStore.discover()
            }
        }
    }
}
