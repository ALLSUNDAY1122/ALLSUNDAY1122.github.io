@preconcurrency import ARKit
import RealityKit
import SwiftUI

@MainActor
struct MeshAdvancedSupervisor: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var depthRecorder = MeshDepthRecorder()
    @StateObject private var qualityAdvisor = MeshCaptureQualityAdvisor()
    @State private var isPaused = false
    @State private var autoPaused = false
    @State private var showingRawReprocess = false
    @State private var showingDetailSimplifier = false
    @State private var showingTrim = false
    @State private var showingAppearance = false
    @State private var showingUncalibratedShare = false
    @State private var showingARViewer = false
    @State private var attemptedDepthFusion = false
    @State private var attemptedGeometryRefine = false
    @State private var attemptedDenseTextureBake = false
    @State private var attemptedParityAudit = false

    private var captureQualitySatisfied: Bool {
        qualityAdvisor.isSufficient(mode: model.mode, size: model.scanSize, frameCount: model.frameCount, faceCount: model.faceCount)
    }

    private var currentOBJ: URL? {
        guard let url = model.resultURL, url.pathExtension.lowercased() == "obj" else { return nil }
        return url
    }

    var body: some View {
        ZStack {
            if model.phase == .scanning {
                scanningControls
            } else if model.phase == .ready {
                readyControls
            } else if model.phase == .finished, currentOBJ != nil {
                resultControls
            }

            if model.phase == .finished,
               let descriptor = model.exporterMeshAsset,
               !descriptor.hasMetricScale {
                uncalibratedOverlay
            }
        }
        .sheet(isPresented: $showingRawReprocess) {
            MeshRawReprocessSheet().environmentObject(model)
        }
        .sheet(isPresented: $showingDetailSimplifier) {
            if let url = model.rawOBJURL ?? currentOBJ {
                MeshDetailSimplifySheet(sourceURL: url).environmentObject(model)
            }
        }
        .sheet(isPresented: $showingTrim) {
            if let url = currentOBJ { MeshTrimEditorSheet(sourceURL: url).environmentObject(model) }
        }
        .sheet(isPresented: $showingAppearance) {
            if let url = currentOBJ { MeshAppearanceEditorSheet(sourceURL: url).environmentObject(model) }
        }
        .sheet(isPresented: $showingARViewer) {
            MeshARViewerSheet().environmentObject(model)
        }
        .sheet(isPresented: $showingUncalibratedShare) {
            if let url = model.resultURL { ShareSheet(items: [url]) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                if model.phase == .scanning && !isPaused { pauseCapture(auto: true) }
            case .active:
                if model.phase == .scanning && autoPaused { resumeCapture() }
            @unknown default:
                break
            }
        }
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .ready {
                isPaused = false
                autoPaused = false
                attemptedDepthFusion = false
                attemptedGeometryRefine = false
                attemptedDenseTextureBake = false
                attemptedParityAudit = false
                qualityAdvisor.reset()
                if depthRecorder.isRecording { depthRecorder.discard() }
            }
            if newPhase == .scanning {
                attemptedDepthFusion = false
                attemptedGeometryRefine = false
                attemptedDenseTextureBake = false
                attemptedParityAudit = false
            }
            if newPhase != .scanning {
                isPaused = false
                autoPaused = false
            }
            if newPhase == .finished { advanceQualityPipeline() }
        }
        .onChange(of: model.resultURL) { _, newURL in
            guard let newURL else { return }
            if depthRecorder.isRecording { depthRecorder.finalize(into: newURL.deletingLastPathComponent()) }
            try? model.persistExporterMeshAssetContract()
        }
        .task(id: model.phase) {
            guard model.phase == .scanning else { return }
            if model.mode == .lidar && !depthRecorder.isRecording { depthRecorder.start() }
            while !Task.isCancelled && model.phase == .scanning {
                if !isPaused, let frame = model.session?.currentFrame {
                    qualityAdvisor.record(frame: frame, mode: model.mode, size: model.scanSize, frameCount: model.frameCount, faceCount: model.faceCount)
                    if model.mode == .lidar { depthRecorder.record(frame: frame) }
                }
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private var scanningControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                Text(qualityAdvisor.compactStatus)
                    .font(.caption2.bold().monospacedDigit())
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.black.opacity(0.72), in: Capsule())
                Button {
                    if isPaused { resumeCapture() } else { pauseCapture(auto: false) }
                } label: {
                    Label(isPaused ? "再開" : "一時停止", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.black.opacity(0.72), in: Capsule())
                }
            }
            .padding(.top, 72).padding(.trailing, 16)
            Spacer()
            if model.canFinish && !captureQualitySatisfied {
                VStack(spacing: 7) {
                    Label("撮影品質がまだ不足", systemImage: "viewfinder").font(.subheadline.bold())
                    Text(qualityAdvisor.guidance).font(.caption).multilineTextAlignment(.center)
                    Text("枚数だけで終了せず、周回・高さ・移動量・形状密度を満たすと完了できます。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(14).frame(maxWidth: .infinity)
                .background(.black.opacity(0.94), in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 14).padding(.bottom, 12).contentShape(Rectangle())
            }
        }
    }

    private var readyControls: some View {
        VStack {
            HStack {
                Spacer()
                Button { showingRawReprocess = true } label: {
                    Label("raw再処理", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
            }
            .padding(.top, 70).padding(.trailing, 18)
            Spacer()
        }
    }

    private var resultControls: some View {
        VStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if model.currentMeshHasMetricScale { actionButton("AR", systemImage: "arkit") { showingARViewer = true } }
                    actionButton("トリミング", systemImage: "crop") { showingTrim = true }
                    if model.resultURL?.lastPathComponent.lowercased().contains("textured") == true || model.resultURL?.lastPathComponent.lowercased().contains("edited") == true {
                        actionButton("見た目", systemImage: "slider.horizontal.3") { showingAppearance = true }
                    }
                    if model.currentMeshHasMetricScale, model.frameCount >= 8, !(model.resultURL?.lastPathComponent.lowercased().contains("textured") ?? false) {
                        actionButton("高品質RGB", systemImage: "photo.on.rectangle.angled") {
                            attemptedDenseTextureBake = true
                            model.bakeDenseRGBTextureAtlas()
                        }
                    }
                    actionButton("軽量化", systemImage: "square.3.layers.3d.down.right") { showingDetailSimplifier = true }
                    actionButton("品質監査", systemImage: "checkmark.seal") {
                        attemptedParityAudit = true
                        model.runMeshParityAudit()
                    }
                }
                .padding(.horizontal, 14)
            }
            .padding(.bottom, 320)
        }
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9)
                .background(.black.opacity(0.72), in: Capsule()).foregroundStyle(.white)
        }
    }

    private var uncalibratedOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 14) {
                Label("尺度未校正のMesh", systemImage: "ruler.fill").font(.headline).foregroundStyle(.orange)
                Text("写真だけから再構築したUSDZはARKit実寸座標へ校正していません。誤ったcm/m値を出さないため、この結果では計測と実寸AR配置を無効にしています。")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack {
                    Button("Meshを書き出す") { showingUncalibratedShare = true }.buttonStyle(SecondaryButtonStyle())
                    Button("新しく撮る") { model.reset() }.buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(18).frame(maxWidth: .infinity).frame(height: 310).background(.black)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func advanceQualityPipeline() {
        guard let url = model.resultURL, url.pathExtension.lowercased() == "obj" else { return }
        let name = url.lastPathComponent.lowercased()
        if model.mode == .lidar,
           model.currentMeshHasMetricScale,
           !attemptedDepthFusion,
           name == "mesh.obj" {
            attemptedDepthFusion = true
            model.fuseLiDARDenseDepth()
            return
        }
        if model.currentMeshHasMetricScale,
           !attemptedGeometryRefine,
           !name.contains("refined"), !name.contains("textured"), !name.contains("trimmed"), !name.contains("simplified") {
            attemptedGeometryRefine = true
            model.refineMetricGeometry()
            return
        }
        if model.currentMeshHasMetricScale,
           !attemptedDenseTextureBake,
           model.frameCount >= 8,
           !name.contains("textured"), !name.contains("edited") {
            attemptedDenseTextureBake = true
            model.bakeDenseRGBTextureAtlas()
            return
        }
        if !attemptedParityAudit {
            attemptedParityAudit = true
            model.runMeshParityAudit()
        }
    }

    private func pauseCapture(auto: Bool) {
        guard model.phase == .scanning else { return }
        model.session?.pause()
        isPaused = true
        autoPaused = auto
        model.statusMessage = auto ? "バックグラウンド移行のため撮影を自動停止しました" : "撮影を一時停止しました"
    }

    private func resumeCapture() {
        guard model.phase == .scanning, let session = model.session else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        if model.mode == .lidar {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) { configuration.sceneReconstruction = .meshWithClassification }
            else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) { configuration.sceneReconstruction = .mesh }
        }
        session.run(configuration, options: [])
        isPaused = false
        autoPaused = false
        model.statusMessage = "撮影を再開しました。既存の追跡状態を維持して続けます"
    }
}

struct MeshScanContainerView: View {
    @EnvironmentObject var model: MeshScanModel
    var body: some View {
        ZStack {
            MeshScanView().environmentObject(model)
            MeshAdvancedSupervisor().environmentObject(model)
            MeshDenseVisualFallbackOverlay().environmentObject(model)
        }
    }
}
