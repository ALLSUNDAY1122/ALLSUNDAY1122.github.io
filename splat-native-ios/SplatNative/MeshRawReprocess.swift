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

        let formatter = ISO8601DateFormatter()
        let safeStamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let outputURL = prepared.projectURL.appendingPathComponent("mesh-reprocessed-\(safeStamp).usdz")
        try? FileManager.default.removeItem(at: outputURL)

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
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        finish(outputURL: outputURL, sourceKind: project.sourceKind, model: model)
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
                    MeshRawProjectBridge.cleanupDerivedWorkingProject(projectURL: prepared.projectURL)
                    model.phase = .captured
                    model.statusMessage = "raw再処理を中断しました。保存rawは保持されています"
                    return
                case .processingComplete:
                    if !completed, FileManager.default.fileExists(atPath: outputURL.path) {
                        finish(outputURL: outputURL, sourceKind: project.sourceKind, model: model)
                        completed = true
                    }
                case .requestProgressInfo(_, _):
                    break
                @unknown default:
                    break
                }
            }

            if !completed {
                MeshRawProjectBridge.cleanupDerivedWorkingProject(projectURL: prepared.projectURL)
                model.phase = .failed("raw再処理は完了しましたが、完成Meshを確認できませんでした。保存rawは保持されています。")
            }
        } catch is CancellationError {
            MeshRawProjectBridge.cleanupDerivedWorkingProject(projectURL: prepared.projectURL)
            model.phase = .captured
            model.statusMessage = "raw再処理を中断しました。保存rawは保持されています"
        } catch {
            MeshRawProjectBridge.cleanupDerivedWorkingProject(projectURL: prepared.projectURL)
            model.phase = .failed("raw再処理に失敗しました: \(error.localizedDescription)。保存rawは保持されています。")
        }
    }

    private static func finish(
        outputURL: URL,
        sourceKind: MeshRawSourceKind,
        model: MeshScanModel
    ) {
        model.resultURL = outputURL
        model.previewScene = try? SCNScene(url: outputURL, options: nil)
        model.reconstructionProgress = 1
        model.phase = .finished
        model.statusMessage = sourceKind == .splatProject
            ? "保存済みSplat rawからMeshを生成しました。ライブラリへ安全に保存しています"
            : "保存済みMesh rawから再処理したMeshを生成しました"
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
