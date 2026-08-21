@preconcurrency import ARKit
import SceneKit
import SwiftUI
import UIKit

/// Keeps one ARSession alive for the whole Splat lifecycle.
/// The camera is not started until ScanModel.startCapture() explicitly runs the session.
struct PersistentScanCameraView: UIViewRepresentable {
    @EnvironmentObject var model: ScanModel

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.automaticallyUpdatesLighting = false
        view.rendersCameraGrain = false
        context.coordinator.install(on: view)
        model.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.refresh(
            in: uiView,
            acceptedFrameCount: model.acceptedFrames,
            isActive: model.phase == .capturing && !model.isCapturePaused
        )
    }

    final class Coordinator: NSObject {
        private weak var sceneView: ARSCNView?
        private let heatmap = CaptureCoverageHeatmapView()
        private var acceptedFeatureIDs = Set<UInt64>()
        private var lastAcceptedFrameCount = 0
        private var isActive = false
        private var timer: Timer?

        func install(on sceneView: ARSCNView) {
            self.sceneView = sceneView
            heatmap.translatesAutoresizingMaskIntoConstraints = false
            heatmap.isUserInteractionEnabled = false
            heatmap.backgroundColor = .clear
            sceneView.addSubview(heatmap)
            NSLayoutConstraint.activate([
                heatmap.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
                heatmap.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
                heatmap.topAnchor.constraint(equalTo: sceneView.topAnchor),
                heatmap.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor),
            ])

            let timer = Timer(timeInterval: 0.22, repeats: true) { [weak self] _ in
                self?.updateHeatmap()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func refresh(in sceneView: ARSCNView, acceptedFrameCount: Int, isActive: Bool) {
            self.sceneView = sceneView
            self.isActive = isActive
            heatmap.isHidden = !isActive

            if acceptedFrameCount < lastAcceptedFrameCount || acceptedFrameCount == 0 {
                acceptedFeatureIDs.removeAll(keepingCapacity: true)
                lastAcceptedFrameCount = acceptedFrameCount
            }

            if acceptedFrameCount > lastAcceptedFrameCount {
                if let cloud = sceneView.session.currentFrame?.rawFeaturePoints {
                    acceptedFeatureIDs.formUnion(cloud.identifiers)
                }
                lastAcceptedFrameCount = acceptedFrameCount
            }
        }

        private func updateHeatmap() {
            guard isActive,
                  let sceneView,
                  sceneView.bounds.width > 1,
                  sceneView.bounds.height > 1,
                  let cloud = sceneView.session.currentFrame?.rawFeaturePoints else {
                heatmap.update(samples: [], viewport: .zero)
                return
            }

            var samples: [CaptureCoverageHeatmapView.Sample] = []
            samples.reserveCapacity(cloud.points.count)

            for (point, identifier) in zip(cloud.points, cloud.identifiers) {
                let projected = sceneView.projectPoint(SCNVector3(point.x, point.y, point.z))
                guard projected.z > 0,
                      projected.z < 1 else { continue }
                let screenPoint = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                guard sceneView.bounds.contains(screenPoint) else { continue }
                samples.append(
                    .init(
                        point: screenPoint,
                        covered: acceptedFeatureIDs.contains(identifier)
                    )
                )
            }

            heatmap.update(samples: samples, viewport: sceneView.bounds)
        }

        deinit {
            timer?.invalidate()
        }
    }
}

/// Screen-space guidance derived from real ARKit feature points.
/// Red hatched cells contain currently visible features that have not appeared in an accepted
/// capture frame yet. Green cells are predominantly backed by already accepted feature IDs.
private final class CaptureCoverageHeatmapView: UIView {
    struct Sample {
        let point: CGPoint
        let covered: Bool
    }

    private struct Cell {
        var total = 0
        var covered = 0
    }

    private struct RenderCell {
        let rect: CGRect
        let covered: Bool
    }

    private var renderCells: [RenderCell] = []

    func update(samples: [Sample], viewport: CGRect) {
        guard viewport.width > 1, viewport.height > 1, !samples.isEmpty else {
            if !renderCells.isEmpty {
                renderCells = []
                setNeedsDisplay()
            }
            return
        }

        let columns = 10
        let rows = 18
        let cellWidth = viewport.width / CGFloat(columns)
        let cellHeight = viewport.height / CGFloat(rows)
        var cells: [Int: Cell] = [:]

        for sample in samples {
            let column = min(columns - 1, max(0, Int(sample.point.x / cellWidth)))
            let row = min(rows - 1, max(0, Int(sample.point.y / cellHeight)))
            let key = row * columns + column
            var cell = cells[key, default: Cell()]
            cell.total += 1
            if sample.covered { cell.covered += 1 }
            cells[key] = cell
        }

        renderCells = cells.compactMap { key, cell in
            // A single drifting AR feature should not paint a large warning block.
            guard cell.total >= 2 else { return nil }
            let row = key / columns
            let column = key % columns
            let rect = CGRect(
                x: CGFloat(column) * cellWidth,
                y: CGFloat(row) * cellHeight,
                width: cellWidth,
                height: cellHeight
            ).insetBy(dx: 1.5, dy: 1.5)
            let coveredRatio = CGFloat(cell.covered) / CGFloat(cell.total)
            return RenderCell(rect: rect, covered: coveredRatio >= 0.58)
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }

        for cell in renderCells {
            if cell.covered {
                context.setFillColor(UIColor.systemGreen.withAlphaComponent(0.10).cgColor)
                context.fill(cell.rect)
                context.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.42).cgColor)
                context.setLineWidth(0.8)
                context.stroke(cell.rect)
                continue
            }

            context.setFillColor(UIColor.systemPink.withAlphaComponent(0.20).cgColor)
            context.fill(cell.rect)
            context.saveGState()
            context.clip(to: cell.rect)
            context.setStrokeColor(UIColor.systemPink.withAlphaComponent(0.78).cgColor)
            context.setLineWidth(1.4)
            let spacing: CGFloat = 9
            var x = cell.rect.minX - cell.rect.height
            while x < cell.rect.maxX {
                context.move(to: CGPoint(x: x, y: cell.rect.maxY))
                context.addLine(to: CGPoint(x: x + cell.rect.height, y: cell.rect.minY))
                x += spacing
            }
            context.strokePath()
            context.restoreGState()
        }
    }
}

struct RootScanView: View {
    @EnvironmentObject var model: ScanModel
    @EnvironmentObject var meshModel: MeshScanModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingShare = false
    @State private var showingMesh = false

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
                ready
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
        .fullScreenCover(isPresented: $showingMesh) {
            MeshScanContainerView()
                .environmentObject(meshModel)
        }
        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                SplatExportOptionsView(sourceURL: url)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                model.handleApplicationBecameActive()
            case .inactive, .background:
                model.handleApplicationBecameInactive()
            @unknown default:
                break
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "cube.transparent")
                .font(.system(size: 68, weight: .thin))
                .foregroundStyle(.mint)
            Text("Scan Lab")
                .font(.largeTitle.bold())
            Text("SplatとMeshを用途で選び、\niPhone内で実3Dデータを生成します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("撮影データを開発者サーバーへ自動送信しません", systemImage: "lock.iphone")
                Label("Splat: 写実的な見た目を優先", systemImage: "sparkles")
                Label("Mesh: 計測・編集・3Dツール利用を優先", systemImage: "square.3.layers.3d")
            }
            .font(.subheadline)

            if model.lidarControlAvailable {
                Toggle(isOn: Binding(
                    get: { !model.ignoreLiDAR },
                    set: { model.ignoreLiDAR = !$0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SplatでLiDAR深度を使う")
                        Text("OFFでもRGB＋ARKit姿勢で撮影できます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
            VStack(spacing: 10) {
                Button("Splatをスキャン") {
                    model.startCapture()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    meshModel.reset()
                    showingMesh = true
                } label: {
                    HStack {
                        Image(systemName: "square.3.layers.3d")
                        Text("Meshをスキャン")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(24)
    }

    private var captureOverlay: some View {
        ZStack {
            Color.black.opacity(model.isCapturePaused ? 0.28 : 0.08).ignoresSafeArea()
            VStack {
                HStack {
                    Button {
                        model.discardAndReset()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.55), in: Circle())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(model.progressText)
                            .font(.subheadline.bold().monospacedDigit())
                        HStack(spacing: 7) {
                            Text(formatDuration(model.activeCaptureSeconds))
                            if model.depthCaptureActive {
                                Label("Depth", systemImage: "viewfinder.circle")
                            }
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.62), in: Capsule())
                }

                HStack(spacing: 12) {
                    Label("未撮影", systemImage: "rectangle.inset.filled")
                        .foregroundStyle(.pink)
                    Label("撮影済み", systemImage: "checkmark.square.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    Text("方向 \(model.coverageSectorCount)/\(model.coverageSectorTotal)")
                        .foregroundStyle(.white)
                }
                .font(.caption.bold().monospacedDigit())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.62), in: Capsule())

                Spacer()

                RoundedRectangle(cornerRadius: 150)
                    .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: 270, height: 270)
                    .overlay(alignment: .top) {
                        Text(model.captureBand)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(model.isCapturePaused ? .orange : .mint, in: Capsule())
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

                    if model.isCapturePaused {
                        Button("撮影を再開") {
                            model.resumeCapture()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        HStack(spacing: 10) {
                            Button {
                                model.pauseCapture()
                            } label: {
                                Label("一時停止", systemImage: "pause.fill")
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button("撮影を終了して生成へ") {
                                model.finishCapture()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!model.canFinishCapture)
                            .opacity(model.canFinishCapture ? 1 : 0.48)
                        }
                    }

                    if model.canFinishCapture {
                        Text("必要な撮影量に達しました。終了して生成できます。")
                            .font(.caption.bold())
                            .foregroundStyle(.mint)
                    } else {
                        Text("赤い未撮影領域を減らしながら、対象の周囲をゆっくり撮影してください。必要量に達すると終了できます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text(model.captureQualityText)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
            }
            .padding()
        }
    }

    private var captured: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.mint)
            Text("撮影できました")
                .font(.title2.bold())
            Text("対象の周囲から必要な写真がそろいました。\nこのまま生成するか、同じスキャンへ撮影を追加できます。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("3Dを生成") {
                model.train()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("あとで生成") {
                model.returnHomePreservingProject()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("撮影データを保存したままホームへ戻ります")
            Button("撮影を再開して追加") {
                model.resumeCapture()
            }
            .buttonStyle(SecondaryButtonStyle())
            Button("撮り直す") {
                model.discardAndReset()
            }
            .foregroundStyle(.secondary)
            Text("「あとで生成」を選ぶと、保存済み一覧の「生成待ち」から再開できます。")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
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
            Text("処理はiPhone内だけで行っています。生成中はアプリを閉じないでください。")
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
            SplatResultView(url: url, showingShare: $showingShare)
                .environmentObject(model)
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

            if model.canRetryGeneration {
                Button("生成だけもう一度試す") {
                    model.retryGeneration()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("撮影からやり直す") {
                    model.discardAndReset()
                }
                .foregroundStyle(.secondary)
            } else {
                Button("撮影からやり直す") {
                    model.discardAndReset()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            Spacer()
        }
        .padding(24)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
