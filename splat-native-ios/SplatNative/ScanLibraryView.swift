import SwiftUI
import UIKit

@MainActor
struct ScanHomeView: View {
    @EnvironmentObject private var model: ScanModel
    @State private var showingLibrary = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RootScanView()

            if model.phase == .ready {
                Button {
                    showingLibrary = true
                } label: {
                    Label("保存済み", systemImage: "square.grid.2x2")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.68), in: Capsule())
                }
                .foregroundStyle(.white)
                .padding(.top, 52)
                .padding(.trailing, 16)
                .accessibilityLabel("保存済みスキャンを開く")
            }
        }
        .fullScreenCover(isPresented: $showingLibrary) {
            ScanLibraryView()
        }
    }
}

@MainActor
struct ScanLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [ScanProjectSummary] = []
    @State private var trash: [ScanProjectSummary] = []
    @State private var showingTrash = false
    @State private var errorMessage: String?

    private let store = ScanProjectStore()

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "保存済みスキャンはありません",
                        systemImage: "cube.transparent",
                        description: Text("完成したSplatはここから何度でも開けます。")
                    )
                } else {
                    List {
                        ForEach(projects) { project in
                            projectRow(project)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("削除", role: .destructive) {
                                        moveToTrash(project)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("保存済みスキャン")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refresh()
                        showingTrash = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(trash.isEmpty)
                    .accessibilityLabel("最近削除したスキャン")
                }
            }
            .alert("操作を完了できませんでした", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingTrash) {
                trashView
            }
            .onAppear { refresh() }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func projectRow(_ project: ScanProjectSummary) -> some View {
        if let trustedURL = store.trustedSplatURL(projectURL: project.projectURL) {
            NavigationLink {
                SavedSplatView(
                    url: trustedURL,
                    title: project.manifest.title
                )
            } label: {
                rowLabel(project, canOpen: true)
            }
        } else {
            rowLabel(project, canOpen: false)
        }
    }

    private func rowLabel(_ project: ScanProjectSummary, canOpen: Bool) -> some View {
        HStack(spacing: 12) {
            thumbnail(for: project)

            VStack(alignment: .leading, spacing: 5) {
                Text(project.manifest.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text(stageText(project.manifest.stage))
                        .font(.caption.bold())
                        .foregroundStyle(canOpen ? .mint : .secondary)
                    Text(project.manifest.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(ByteCountFormatter.string(fromByteCount: project.storageBytes, countStyle: .file))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                if !canOpen, let message = project.manifest.lastError, !message.isEmpty {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            if !canOpen {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("再開または再処理が必要")
            }
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private func thumbnail(for project: ScanProjectSummary) -> some View {
        if let url = project.thumbnailURL,
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.08))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "cube.transparent")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var trashView: some View {
        NavigationStack {
            Group {
                if trash.isEmpty {
                    ContentUnavailableView(
                        "最近削除したスキャンはありません",
                        systemImage: "trash"
                    )
                } else {
                    List {
                        ForEach(trash) { project in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.manifest.title)
                                        .font(.headline)
                                    Text(project.manifest.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("復元") {
                                    restore(project)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("最近削除")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { showingTrash = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func refresh() {
        projects = store.listProjects()
        trash = store.listTrash()
    }

    private func moveToTrash(_ project: ScanProjectSummary) {
        do {
            try store.moveToTrash(projectURL: project.projectURL)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ project: ScanProjectSummary) {
        do {
            try store.restoreFromTrash(id: project.id)
            refresh()
            if trash.isEmpty { showingTrash = false }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func stageText(_ stage: ScanProjectStage) -> String {
        switch stage {
        case .capturing: return "撮影途中"
        case .captured: return "生成待ち"
        case .processing: return "生成中断"
        case .finished: return "完成"
        case .failed: return "要確認"
        }
    }
}

@MainActor
private struct SavedSplatView: View {
    let url: URL
    let title: String

    @StateObject private var viewerState = SplatViewerState()
    @State private var selectedTool = SavedViewerTool.view
    @State private var showingShare = false

    private enum SavedViewerTool: String, CaseIterable, Hashable {
        case view = "見る"
        case crop = "切り抜き"
        case adjust = "調整"
        case measure = "計測"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                SplatViewer(url: url, state: viewerState)
                    .ignoresSafeArea(edges: .top)

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.headline.bold())
                            if viewerState.totalPointCount > 0 {
                                Text("表示 \(viewerState.visiblePointCount.formatted()) / \(viewerState.totalPointCount.formatted()) splats")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 13))

                        Spacer()

                        if viewerState.isLoading || viewerState.isApplyingEdits {
                            ProgressView()
                                .tint(.white)
                                .padding(10)
                                .background(.black.opacity(0.68), in: Circle())
                        }
                    }
                    .padding()
                    Spacer()
                }

                if let error = viewerState.errorMessage {
                    viewerError(error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
        }
        .background(Color.black)
        .navigationTitle("3D")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewerState.attach(url: url) }
        .onChange(of: viewerState.editSettings) { _, _ in
            viewerState.schedulePersistence()
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [url])
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("表示ツール", selection: $selectedTool) {
                ForEach(SavedViewerTool.allCases, id: \.self) { tool in
                    Text(tool.rawValue).tag(tool)
                }
            }
            .pickerStyle(.segmented)

            toolPanel

            if let warning = viewerState.warningMessage {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    viewerState.requestCameraReset()
                } label: {
                    Label("表示を戻す", systemImage: "scope")
                }
                .buttonStyle(.bordered)

                Button {
                    viewerState.persistNow()
                    showingShare = true
                } label: {
                    Label("共有", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 10)
        .background(.black)
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch selectedTool {
        case .view:
            Text("1本指で回転・2本指で移動・ピンチで拡大縮小できます。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .crop:
            VStack(spacing: 8) {
                rangeRow("左右", low: $viewerState.cropXMin, high: $viewerState.cropXMax)
                rangeRow("上下", low: $viewerState.cropYMin, high: $viewerState.cropYMax)
                rangeRow("奥行き", low: $viewerState.cropZMin, high: $viewerState.cropZMax)
            }

        case .adjust:
            VStack(spacing: 8) {
                sliderRow(
                    "露出",
                    valueText: String(format: "%+.1f EV", viewerState.exposureEV),
                    value: $viewerState.exposureEV,
                    range: -2...2,
                    step: 0.1
                )
                sliderRow(
                    "コントラスト",
                    valueText: "\(Int((viewerState.contrast * 100).rounded()))%",
                    value: $viewerState.contrast,
                    range: 0.5...1.5,
                    step: 0.05
                )
            }

        case .measure:
            VStack(spacing: 8) {
                Toggle("2点計測", isOn: $viewerState.measurementEnabled)
                    .tint(.mint)
                Text(viewerState.measurementText)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("計測点をクリア") {
                    viewerState.requestMeasurementClear()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func rangeRow(_ title: String, low: Binding<Double>, high: Binding<Double>) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title).font(.caption.bold())
                Spacer()
                Text("\(Int((low.wrappedValue * 100).rounded()))–\(Int((high.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Slider(value: low, in: 0...max(0.02, high.wrappedValue - 0.02), step: 0.01)
                    .tint(.mint)
                Slider(value: high, in: min(0.98, low.wrappedValue + 0.02)...1, step: 0.01)
                    .tint(.mint)
            }
        }
    }

    private func sliderRow(
        _ title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title).font(.caption.bold())
                Spacer()
                Text(valueText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .tint(.mint)
        }
    }

    private func viewerError(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("3Dを表示できません")
                .font(.headline)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("再読み込み") {
                viewerState.requestReload()
            }
            .buttonStyle(.borderedProminent)
            .tint(.mint)
            .foregroundStyle(.black)
        }
        .padding(18)
        .frame(maxWidth: 310)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
    }
}
