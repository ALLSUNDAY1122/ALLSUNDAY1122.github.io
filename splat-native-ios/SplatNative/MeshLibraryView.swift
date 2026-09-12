import SceneKit
import SwiftUI

/// Unified local-library entry point. Existing Splat library remains C-owned and is presented as-is;
/// Mesh uses C's durable MeshProjectStore with integrity verification before every open/export.
struct ScanLabLibraryHubView: View {
    @State private var showingSplatLibrary = false
    @State private var splatCount = 0
    @State private var meshCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section("端末内の3D") {
                    Button {
                        showingSplatLibrary = true
                    } label: {
                        libraryRow(
                            title: "Splat",
                            subtitle: "保存済み・生成待ち・再処理",
                            count: splatCount,
                            icon: "sparkles"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        MeshLibraryView()
                    } label: {
                        libraryRow(
                            title: "Mesh",
                            subtitle: "保存済みMesh・書き出し・ゴミ箱",
                            count: meshCount,
                            icon: "cube"
                        )
                    }
                }

                Section {
                    Text("SplatとMeshは端末内ライブラリを正本として保持します。オンライン公開はSplatの公開操作を明示的に選んだ場合だけ実行されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Library")
            .task { await refreshCounts(adoptLegacyMesh: true) }
            .refreshable { await refreshCounts(adoptLegacyMesh: true) }
            .fullScreenCover(isPresented: $showingSplatLibrary, onDismiss: {
                Task { await refreshCounts(adoptLegacyMesh: false) }
            }) {
                ScanLibraryView()
            }
        }
    }

    @ViewBuilder
    private func libraryRow(title: String, subtitle: String, count: Int, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 42, height: 42)
                .background(.mint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func refreshCounts(adoptLegacyMesh: Bool) async {
        let counts = await Task.detached(priority: .utility) {
            let splatStore = ScanProjectStore()
            let meshStore = MeshProjectStore()
            if adoptLegacyMesh { meshStore.adoptLegacyCompletedProjects() }
            return (splatStore.listProjects().count, meshStore.listProjects().count)
        }.value
        splatCount = counts.0
        meshCount = counts.1
    }
}

struct MeshLibraryView: View {
    @State private var projects: [MeshProjectSummary] = []
    @State private var errorMessage: String?
    @State private var showingTrash = false
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && projects.isEmpty {
                ProgressView("Meshライブラリを読み込み中")
            } else if projects.isEmpty {
                ContentUnavailableView(
                    "保存済みMeshはありません",
                    systemImage: "cube",
                    description: Text("Mesh生成が完了すると、自動的にこのライブラリへ安全に保存されます。")
                )
            } else {
                List {
                    ForEach(projects) { summary in
                        NavigationLink {
                            SavedMeshView(summary: summary)
                        } label: {
                            MeshLibraryRow(summary: summary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("ゴミ箱", role: .destructive) {
                                Task { await moveToTrash(summary) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Mesh")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingTrash = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Meshのゴミ箱")
            }
        }
        .task { await refresh(adoptLegacy: true) }
        .refreshable { await refresh(adoptLegacy: true) }
        .sheet(isPresented: $showingTrash, onDismiss: {
            Task { await refresh(adoptLegacy: false) }
        }) {
            MeshTrashView()
        }
        .alert("Meshライブラリを更新できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "不明なエラーです")
        }
    }

    private func refresh(adoptLegacy: Bool) async {
        isLoading = true
        defer { isLoading = false }
        let values = await Task.detached(priority: .utility) {
            let store = MeshProjectStore()
            if adoptLegacy { store.adoptLegacyCompletedProjects() }
            return store.listProjects()
        }.value
        projects = values
    }

    private func moveToTrash(_ summary: MeshProjectSummary) async {
        do {
            try await Task.detached(priority: .utility) {
                try MeshProjectStore().moveToTrash(projectURL: summary.projectURL)
            }.value
            await refresh(adoptLegacy: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MeshLibraryRow: View {
    let summary: MeshProjectSummary

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: summary.captureMode == "lidar" ? "sensor.tag.radiowaves.forward" : "camera.viewfinder")
                .font(.title3)
                .foregroundStyle(.mint)
                .frame(width: 40, height: 40)
                .background(.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.title).font(.headline)
                Text(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: summary.storageBytes, countStyle: .file))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SavedMeshView: View {
    let summary: MeshProjectSummary

    @State private var scene: SCNScene?
    @State private var trustedURL: URL?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var showingExport = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let scene {
                    MeshPreviewView(scene: scene, measurementEnabled: false) { _ in }
                } else if isLoading {
                    ProgressView("保存済みMeshを検証中")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Meshを開けません",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage ?? "保存済みMeshの整合性を確認できませんでした。")
                    )
                }
            }

            if let trustedURL {
                HStack(spacing: 12) {
                    Button {
                        showingExport = true
                    } label: {
                        Label("書き出す", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    ShareLink(item: trustedURL) {
                        Label("元データ", systemImage: "doc")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(14)
                .background(.black)
            }
        }
        .navigationTitle(summary.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadTrustedMesh() }
        .sheet(isPresented: $showingExport) {
            if let trustedURL {
                MeshExportOptionsView(sourceURL: trustedURL)
            }
        }
    }

    private func loadTrustedMesh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let verified = try await Task.detached(priority: .utility) {
                try MeshProjectIntegrity.verifyOrSeal(summary: summary)
            }.value
            let loaded = try SCNScene(url: verified, options: nil)
            trustedURL = verified
            scene = loaded
        } catch {
            trustedURL = nil
            scene = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct MeshTrashView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [MeshProjectSummary] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView("ゴミ箱は空です", systemImage: "trash")
                } else {
                    List {
                        ForEach(items) { summary in
                            VStack(alignment: .leading, spacing: 8) {
                                MeshLibraryRow(summary: summary)
                                HStack {
                                    Button("復元") { Task { await restore(summary) } }
                                        .buttonStyle(.bordered)
                                    Spacer()
                                    Button("完全に削除", role: .destructive) {
                                        Task { await permanentlyDelete(summary) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Meshのゴミ箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await refresh() }
        }
        .alert("ゴミ箱を更新できませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("閉じる", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "不明なエラーです")
        }
    }

    private func refresh() async {
        items = await Task.detached(priority: .utility) {
            MeshProjectStore().listTrash()
        }.value
    }

    private func restore(_ summary: MeshProjectSummary) async {
        do {
            try await Task.detached(priority: .utility) {
                try MeshProjectStore().restoreFromTrash(id: summary.id)
            }.value
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func permanentlyDelete(_ summary: MeshProjectSummary) async {
        do {
            try await Task.detached(priority: .utility) {
                try MeshProjectStore().permanentlyDeleteFromTrash(id: summary.id)
            }.value
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
