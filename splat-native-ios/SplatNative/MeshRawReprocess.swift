import Foundation
import RealityKit
import SceneKit
import SwiftUI

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
            guard let imageFiles = try? fileManager.contentsOfDirectory(at: imagesURL, includingPropertiesForKeys: nil) else { return nil }
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
        model.invalidPhotogrammetrySamples = 0
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
