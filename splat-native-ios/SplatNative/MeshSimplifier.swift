import Foundation
import SceneKit
import SwiftUI

private struct MeshSimplifyResult: Sendable {
    let url: URL
    let vertexCount: Int
    let faceCount: Int
}

/// The original general simplifier duplicated an older vertex-cluster parser that silently skipped
/// malformed OBJ records, dropped textures/vertex color and did not protect boundaries or small
/// components. Keep one quality path: the general sheet delegates to the detail-preserving engine
/// so both entry points share the same geometry validation, topology protection and visual-data
/// safeguards.
private enum MeshOBJSimplifier {
    static func simplify(url: URL, retainedFraction: Double) throws -> MeshSimplifyResult {
        let result = try MeshDetailSimplifierEngine.simplify(
            url: url,
            retainedFraction: retainedFraction
        )
        return MeshSimplifyResult(
            url: result.url,
            vertexCount: result.vertices,
            faceCount: result.faces
        )
    }

    static func discard(_ result: MeshSimplifyResult) {
        try? FileManager.default.removeItem(at: result.url)
        let sidecar = result.url.deletingPathExtension().appendingPathExtension("mesh-asset.json")
        try? FileManager.default.removeItem(at: sidecar)
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
                    Text("境界と小さな部品を保護するクラスタリングで実ジオメトリを削減します。元OBJは保持されます。")
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
                        applySimplification()
                    }
                    .disabled(isWorking)
                }
            }
            .navigationTitle("Meshを軽量化")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.disabled(isWorking)
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private func applySimplification() {
        isWorking = true
        errorText = nil
        let url = sourceURL
        let fraction = retainedFraction
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try MeshOBJSimplifier.simplify(url: url, retainedFraction: fraction)
                }.value
                guard let candidateScene = try? SCNScene(url: result.url, options: nil) else {
                    MeshOBJSimplifier.discard(result)
                    throw NSError(domain:"ScanLab.MeshSimplifier", code:3, userInfo:[NSLocalizedDescriptionKey:"簡略化後のMeshを検証できませんでした。元Meshを保持します。"])
                }

                let previousRawURL = model.rawOBJURL
                let previousResultURL = model.resultURL
                let previousScene = model.previewScene
                let previousVertexCount = model.vertexCount
                let previousFaceCount = model.faceCount

                model.rawOBJURL = result.url
                model.resultURL = result.url
                model.previewScene = candidateScene
                model.vertexCount = result.vertexCount
                model.faceCount = result.faceCount
                do {
                    try model.persistExporterMeshAssetContract()
                } catch {
                    model.rawOBJURL = previousRawURL
                    model.resultURL = previousResultURL
                    model.previewScene = previousScene
                    model.vertexCount = previousVertexCount
                    model.faceCount = previousFaceCount
                    MeshOBJSimplifier.discard(result)
                    throw error
                }

                model.statusMessage = "境界・小部品を保護して実Meshを軽量化しました"
                isWorking = false
                dismiss()
            } catch {
                isWorking = false
                errorText = error.localizedDescription
            }
        }
    }
}
