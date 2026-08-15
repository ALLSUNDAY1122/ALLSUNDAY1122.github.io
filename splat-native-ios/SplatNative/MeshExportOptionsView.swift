import SwiftUI

/// Drop-in S6 export surface for S4's `MeshScanModel.resultURL`.
/// S0 only needs to present this view with the real S4 result URL after sibling-branch integration.
struct MeshExportOptionsView: View {
    let sourceURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var sharePayload: SharePayload?
    @State private var exportError: String?
    @State private var exportingFormat: MeshExportService.Format?
    @State private var exportTask: Task<Void, Never>?

    private var capabilities: [MeshExportService.Capability] {
        MeshExportService.capabilities(for: sourceURL)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(capabilities, id: \.format.id) { capability in
                        Button {
                            beginExport(capability.format)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(capability.format.displayName)
                                        .font(.headline)
                                    Text(description(for: capability.format))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if exportingFormat == capability.format {
                                    ProgressView()
                                } else if capability.isAvailable {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundStyle(.mint)
                                } else {
                                    Image(systemName: "nosign")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(!capability.isAvailable || exportingFormat != nil)

                        if !capability.isAvailable, let reason = capability.reason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Mesh形式")
                } footer: {
                    Text("実際に変換可能な形式だけを選べます。拡張子だけを変更する書き出しは行いません。")
                }

                if exportingFormat != nil {
                    Section {
                        Button("書き出しを中止", role: .destructive) {
                            exportTask?.cancel()
                        }
                    }
                }
            }
            .navigationTitle("Meshを書き出す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                        .disabled(exportingFormat != nil)
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
        }
        .alert("Meshを書き出せませんでした", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("閉じる", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "不明なエラーです")
        }
    }

    private func beginExport(_ format: MeshExportService.Format) {
        guard exportingFormat == nil else { return }
        exportingFormat = format
        exportError = nil

        exportTask = Task {
            defer {
                exportingFormat = nil
                exportTask = nil
            }
            do {
                let output = try await MeshExportService.export(
                    sourceURL: sourceURL,
                    format: format
                )
                try Task.checkCancellation()
                sharePayload = SharePayload(url: output)
            } catch is CancellationError {
                // Expected recovery path. MeshExportService removes partial outputs.
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private func description(for format: MeshExportService.Format) -> String {
        switch format {
        case .fbx: return "DCC・3Dツール向け"
        case .obj: return "広く対応する汎用Mesh"
        case .glb: return "Web・共有向け単一バイナリ"
        case .usdz: return "Apple AR・Quick Look向け"
        case .stl: return "形状中心の3Dプリント向け"
        }
    }
}
