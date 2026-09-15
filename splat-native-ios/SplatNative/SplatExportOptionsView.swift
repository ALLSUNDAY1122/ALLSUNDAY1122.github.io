import SwiftUI

@MainActor
struct SplatExportOptionsView: View {
    let sourceURL: URL

    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var statusText: String?
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var exportWorkspaceURL: URL?
    @State private var showingShareSheet = false
    @State private var showingVideoOptions = false
    @State private var videoConfiguration = SplatVideoConfiguration()
    @State private var exportTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section("Gaussian Splat") {
                    exportButton(
                        title: "PLYを書き出す",
                        subtitle: "一般的な3D/Splatツール向け",
                        systemImage: "shippingbox"
                    ) {
                        startSplatExport(.ply)
                    }

                    exportButton(
                        title: "SPZを書き出す",
                        subtitle: "Splat向けの圧縮形式",
                        systemImage: "archivebox"
                    ) {
                        startSplatExport(.spz)
                    }
                }

                Section {
                    Button {
                        showingVideoOptions = true
                    } label: {
                        Label("MP4動画を作る", systemImage: "video")
                    }
                    .disabled(isExporting)
                } header: {
                    Text("動画")
                } footer: {
                    Text("動画は端末内で再描画します。大きすぎるシーンや空き容量不足は開始前に停止します。")
                }

                if isExporting || statusText != nil {
                    Section("状態") {
                        HStack(spacing: 12) {
                            if isExporting {
                                ProgressView()
                            }
                            Text(statusText ?? "書き出し中")
                                .foregroundStyle(.secondary)
                        }

                        if isExporting {
                            Button("キャンセル", role: .destructive) {
                                exportTask?.cancel()
                            }
                        }
                    }
                }
            }
            .navigationTitle("書き出す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        exportTask?.cancel()
                        if !showingShareSheet {
                            cleanupTransientExport()
                        }
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingVideoOptions) {
            SplatVideoOptionsView(configuration: $videoConfiguration) { configuration in
                startVideoExport(configuration)
            }
        }
        .sheet(isPresented: $showingShareSheet, onDismiss: {
            cleanupTransientExport()
        }) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .alert("書き出しできませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            if !showingShareSheet && !showingVideoOptions {
                exportTask?.cancel()
                cleanupTransientExport()
            }
        }
    }

    @ViewBuilder
    private func exportButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(isExporting)
    }

    private func startSplatExport(_ format: SplatExportService.Format) {
        guard !isExporting else { return }
        isExporting = true
        statusText = "\(format.displayName)を書き出しています"
        errorMessage = nil

        exportTask = Task {
            var workspace: URL?
            do {
                let kind: SplatExportAdmission.Kind = format == .ply ? .ply : .spz
                let trustedURL = try SplatExportAdmission.preflight(sourceURL: sourceURL, kind: kind)
                try Task.checkCancellation()
                let createdWorkspace = try SplatTransientExportWorkspace.create()
                workspace = createdWorkspace
                let url = try await SplatExportService.export(
                    sourceURL: trustedURL,
                    format: format,
                    destinationDirectory: createdWorkspace
                )
                try Task.checkCancellation()
                finishExport(
                    url: url,
                    workspaceURL: createdWorkspace,
                    message: "\(format.displayName)を書き出しました"
                )
                workspace = nil
            } catch is CancellationError {
                SplatTransientExportWorkspace.remove(workspace)
                finishCancellation()
            } catch {
                SplatTransientExportWorkspace.remove(workspace)
                finishFailure(error)
            }
        }
    }

    private func startVideoExport(_ configuration: SplatVideoConfiguration) {
        guard !isExporting else { return }
        isExporting = true
        statusText = "MP4動画を作っています"
        errorMessage = nil

        exportTask = Task {
            var workspace: URL?
            do {
                let dimensions = configuration.dimensions
                let trustedURL = try SplatExportAdmission.preflight(
                    sourceURL: sourceURL,
                    kind: .video(
                        width: dimensions.width,
                        height: dimensions.height,
                        framesPerSecond: configuration.framesPerSecond,
                        duration: configuration.duration
                    )
                )
                try Task.checkCancellation()
                let createdWorkspace = try SplatTransientExportWorkspace.create()
                workspace = createdWorkspace
                let url = try await SplatVideoExporter.export(
                    sourceURL: trustedURL,
                    configuration: configuration,
                    destinationDirectory: createdWorkspace
                )
                try Task.checkCancellation()
                finishExport(
                    url: url,
                    workspaceURL: createdWorkspace,
                    message: "MP4動画を作成しました"
                )
                workspace = nil
            } catch is CancellationError {
                SplatTransientExportWorkspace.remove(workspace)
                finishCancellation()
            } catch {
                SplatTransientExportWorkspace.remove(workspace)
                finishFailure(error)
            }
        }
    }

    private func finishExport(url: URL, workspaceURL: URL, message: String) {
        cleanupTransientExport()
        isExporting = false
        statusText = message
        shareURL = url
        exportWorkspaceURL = workspaceURL
        showingShareSheet = true
        exportTask = nil
    }

    private func finishCancellation() {
        isExporting = false
        statusText = "書き出しをキャンセルしました"
        exportTask = nil
    }

    private func finishFailure(_ error: Error) {
        isExporting = false
        statusText = nil
        errorMessage = error.localizedDescription
        exportTask = nil
    }

    private func cleanupTransientExport() {
        SplatTransientExportWorkspace.remove(exportWorkspaceURL)
        exportWorkspaceURL = nil
        shareURL = nil
    }
}
