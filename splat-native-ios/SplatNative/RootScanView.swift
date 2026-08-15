@preconcurrency import ARKit
import SceneKit
import SwiftUI
import UIKit

/// Keeps one ARSession alive for the whole app lifecycle.
/// The camera is not started until ScanModel.startCapture() explicitly runs the session.
struct PersistentScanCameraView: UIViewRepresentable {
    @EnvironmentObject var model: ScanModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.automaticallyUpdatesLighting = false
        view.rendersCameraGrain = false
        model.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct RootScanView: View {
    @EnvironmentObject var model: ScanModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingShare = false
    @State private var showingDiscardConfirmation = false
    @State private var showingTrash = false
    @State private var showingRawClearConfirmation = false
    @State private var deleteCandidate: ScanProjectSummary?

    private var isCapturing: Bool { model.phase == .capturing }

    var body: some View {
        ZStack {
            PersistentScanCameraView()
                .environmentObject(model)
                .ignoresSafeArea()
                .opacity(isCapturing ? 1 : 0)
                .allowsHitTesting(isCapturing)

            if !isCapturing {
                Color.black.ignoresSafeArea()
            }

            switch model.phase {
            case .ready:
                library
            case .capturing:
                captureOverlay
            case .captured:
                captured
            case .training:
                training
            case .finished:
                finished
            case .failed(let message):
                failed(message)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, newValue in
            model.handleScenePhase(newValue)
        }
        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingTrash) {
            RecentlyDeletedView(model: model)
        }
        .alert("このスキャンを削除しますか？", isPresented: $showingDiscardConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("最近削除した項目へ移動", role: .destructive) {
                model.discardAndReset()
            }
        } message: {
            Text("すぐには完全削除されません。ライブラリの「最近削除した項目」から復元できます。")
        }
        .alert("rawデータを消去しますか？", isPresented: $showingRawClearConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("rawデータを消去", role: .destructive) {
                model.clearRawDataForActiveProject()
            }
        } message: {
            Text("完成済み3Dは残りますが、この撮影から再処理したりスキャンを再開したりできなくなります。")
        }
        .alert(item: $deleteCandidate) { summary in
            Alert(
                title: Text("「\(summary.manifest.title)」を削除しますか？"),
                message: Text("最近削除した項目へ移動するため、あとから復元できます。"),
                primaryButton: .destructive(Text("削除")) { model.deleteProject(id: summary.id) },
                secondaryButton: .cancel()
            )
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan Lab")
                            .font(.largeTitle.bold())
                        Text("端末内のスキャン")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        model.refreshLibrary()
                        showingTrash = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.10), in: Circle())
                    }
                    .accessibilityLabel("最近削除した項目")
                }

                HStack {
                    Label("\(model.libraryProjects.count)件", systemImage: "square.grid.2x2")
                    Spacer()
                    Text(Self.byteString(model.libraryStorageBytes))
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

                Button {
                    model.startCapture()
                } label: {
                    Label("新しくスキャン", systemImage: "viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())

                if model.libraryProjects.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 58, weight: .thin))
                            .foregroundStyle(.mint)
                        Text("まだスキャンがありません")
                            .font(.title3.bold())
                        Text("撮影途中でも端末内に保存できます。\n生成は今すぐでも、あとからでも行えます。")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 46)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(model.libraryProjects) { summary in
                            Button {
                                model.openProject(id: summary.id)
                            } label: {
                                ScanProjectCard(summary: summary)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteCandidate = summary
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if !model.trashProjects.isEmpty {
                    Button {
                        showingTrash = true
                    } label: {
                        HStack {
                            Label("最近削除した項目", systemImage: "trash")
                            Spacer()
                            Text("\(model.trashProjects.count)")
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 6) }
    }

    private var captureOverlay: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
            VStack {
                HStack {
                    Button {
                        model.saveDraftAndReturnToLibrary()
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }
                    .accessibilityLabel("保存して閉じる")
                    Spacer()
                    Text(model.progressText)
                        .font(.subheadline.bold().monospacedDigit())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.62), in: Capsule())
                }

                Spacer()

                RoundedRectangle(cornerRadius: 150)
                    .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: 270, height: 270)
                    .overlay(alignment: .top) {
                        Text(model.captureBand)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.mint, in: Capsule())
                            .foregroundStyle(.black)
                            .offset(y: -20)
                    }

                Spacer()

                VStack(spacing: 10) {
                    Text(model.trackingMessage)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)

                    ProgressView(
                        value: Double(model.coverageSectorCount),
                        total: Double(model.coverageSectorTotal)
                    )
                    .tint(.mint)

                    if model.canFinishCapture {
                        Button("この撮影で生成へ") {
                            model.finishCapture()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text(model.captureQualityText)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("保存してあとで続ける") {
                            model.saveDraftAndReturnToLibrary()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        Spacer()
                        Button("破棄") {
                            showingDiscardConfirmation = true
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                    }
                }
                .padding(16)
                .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
    }

    private var captured: some View {
        ScrollView {
            VStack(spacing: 20) {
                projectHeader

                ProjectThumbnail(url: activeThumbnailURL)
                    .frame(height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                VStack(spacing: 8) {
                    Text(model.activeManifest?.title ?? "スキャン")
                        .font(.title2.bold())
                    Text(projectStateText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("\(model.acceptedFrames)枚 • 撮影方向 \(model.coverageSectorCount)/\(model.coverageSectorTotal)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                if model.activeProjectCanProcess {
                    Button("3Dを生成") {
                        model.train()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                if model.activeProjectCanResume {
                    Button("スキャンを再開") {
                        model.resumeActiveCapture()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else if model.activeProjectIsDraft {
                    Text("撮影途中の画像は保存されています。再起動後の撮影再開には、保存済みのカメラ位置情報が必要です。")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Button("あとで処理") {
                    model.returnToLibrary()
                }
                .foregroundStyle(.secondary)

                Button("削除") {
                    showingDiscardConfirmation = true
                }
                .foregroundStyle(.red)
                .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private var training: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView(value: model.trainingProgress)
                .progressViewStyle(.circular)
                .scaleEffect(1.7)
                .tint(.mint)
            Text("3Dを生成中")
                .font(.title2.bold())
            Text(model.trainingStageText)
                .font(.body.weight(.medium))
            Text("\(Int(model.trainingProgress * 100))%")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            ProgressView(value: model.trainingProgress)
                .tint(.mint)
                .padding(.horizontal, 24)
            Text("処理状態は端末内に記録しています。途中でアプリが終了しても、rawデータが残っていればライブラリから生成をやり直せます。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private var finished: some View {
        if let url = model.resultURL {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SplatViewer(url: url)
                        .ignoresSafeArea(edges: .top)
                    HStack {
                        Button {
                            model.returnToLibrary()
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        Spacer()
                        Text("3D生成完了")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.mint, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    .padding()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button("3Dを書き出す") {
                            showingShare = true
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if model.activeProjectHasRaw {
                            Button("rawから再生成") {
                                model.reprocessCurrentSplat()
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button("rawを消去") {
                                showingRawClearConfirmation = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        Button("削除") {
                            showingDiscardConfirmation = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 12)
                .background(.black)

                Text("1本指で回転・ピンチで拡大縮小・ダブルタップで表示を戻す")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 16)
                    .background(.black)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange)
            Text("処理を完了できませんでした")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if model.activeProjectCanResume {
                Button("撮影を再開") {
                    model.resumeActiveCapture()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if model.canRetryGeneration {
                Button("生成だけもう一度試す") {
                    model.retryGeneration()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if model.activeManifest != nil {
                Button("データを残してライブラリへ") {
                    model.returnToLibrary()
                }
                .foregroundStyle(.secondary)
                Button("削除") {
                    showingDiscardConfirmation = true
                }
                .foregroundStyle(.red)
            } else {
                Button("ライブラリへ戻る") {
                    model.returnToLibrary()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Spacer()
        }
        .padding(24)
    }

    private var projectHeader: some View {
        HStack {
            Button {
                model.returnToLibrary()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.10), in: Circle())
            }
            Spacer()
            Text(model.activeProjectIsDraft ? "撮影途中" : "撮影済み")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.10), in: Capsule())
        }
    }

    private var projectStateText: String {
        if let error = model.activeManifest?.lastError, !error.isEmpty { return error }
        if model.activeProjectIsDraft { return "撮影途中のrawデータを端末内に保存しています。" }
        if model.activeProjectCanProcess { return "rawデータを保持しているため、今でもあとからでも3Dを生成できます。" }
        return "このスキャンは保存されています。"
    }

    private var activeThumbnailURL: URL? {
        guard let id = model.activeManifest?.id else { return nil }
        return model.libraryProjects.first(where: { $0.id == id })?.thumbnailURL
    }

    private static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private struct ScanProjectCard: View {
    let summary: ScanProjectSummary

    var body: some View {
        HStack(spacing: 14) {
            ProjectThumbnail(url: summary.thumbnailURL)
                .frame(width: 94, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 7) {
                Text(summary.manifest.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(stageText)
                    .font(.caption.bold())
                    .foregroundStyle(stageColor)
                Text(summary.manifest.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: summary.storageBytes, countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private var stageText: String {
        switch summary.manifest.stage {
        case .capturing: return "撮影途中"
        case .captured: return "処理待ち"
        case .processing: return "生成中断を確認中"
        case .finished: return summary.manifest.rawDataRetained ? "完成 • raw保持" : "完成"
        case .failed: return summary.manifest.rawDataRetained ? "再試行できます" : "要確認"
        }
    }

    private var stageColor: Color {
        switch summary.manifest.stage {
        case .finished: return .mint
        case .failed: return .orange
        default: return .secondary
        }
    }
}

private struct ProjectThumbnail: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.06)
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundStyle(.mint)
                }
            }
        }
        .clipped()
    }
}

private struct RecentlyDeletedView: View {
    @ObservedObject var model: ScanModel
    @Environment(\.dismiss) private var dismiss
    @State private var permanentDeleteCandidate: ScanProjectSummary?

    var body: some View {
        NavigationStack {
            List {
                if model.trashProjects.isEmpty {
                    ContentUnavailableView("最近削除した項目はありません", systemImage: "trash")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(model.trashProjects) { summary in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                ProjectThumbnail(url: summary.thumbnailURL)
                                    .frame(width: 62, height: 62)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary.manifest.title).font(.headline)
                                    Text(summary.manifest.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            HStack {
                                Button("復元") {
                                    model.restoreProject(id: summary.id)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.mint)
                                Button("完全に削除", role: .destructive) {
                                    permanentDeleteCandidate = summary
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("最近削除した項目")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { model.refreshLibrary() }
            .alert(item: $permanentDeleteCandidate) { summary in
                Alert(
                    title: Text("完全に削除しますか？"),
                    message: Text("「\(summary.manifest.title)」とrawデータは復元できなくなります。"),
                    primaryButton: .destructive(Text("完全に削除")) {
                        model.permanentlyDeleteProject(id: summary.id)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
