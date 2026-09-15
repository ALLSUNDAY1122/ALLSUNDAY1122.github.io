@preconcurrency import ARKit
import SceneKit
import SwiftUI
import UIKit

struct MeshScanCameraView: UIViewRepresentable {
    @EnvironmentObject var model: MeshScanModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.automaticallyUpdatesLighting = true
        view.rendersCameraGrain = false
        model.attach(session: view.session)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}
}

struct MeshPreviewView: UIViewRepresentable {
    let scene: SCNScene
    let measurementEnabled: Bool
    let onMeasurement: (Float?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMeasurement: onMeasurement)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.backgroundColor = .black
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.scene !== scene { uiView.scene = scene }
        context.coordinator.measurementEnabled = measurementEnabled
        context.coordinator.onMeasurement = onMeasurement
        if !measurementEnabled {
            context.coordinator.clearMeasurement()
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        weak var view: SCNView?
        var measurementEnabled = false
        var onMeasurement: (Float?) -> Void
        private var firstPoint: SCNVector3?
        private var markers: [SCNNode] = []
        private var lineNode: SCNNode?

        init(onMeasurement: @escaping (Float?) -> Void) {
            self.onMeasurement = onMeasurement
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard measurementEnabled, let view else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: [
                .firstFoundOnly: true,
                .backFaceCulling: false,
                .ignoreHiddenNodes: true
            ])
            guard let hit = hits.first else { return }
            let position = hit.worldCoordinates

            if let firstPoint {
                let dx = position.x - firstPoint.x
                let dy = position.y - firstPoint.y
                let dz = position.z - firstPoint.z
                let distance = sqrt(dx * dx + dy * dy + dz * dz)
                addMarker(at: position, to: view.scene)
                addLine(from: firstPoint, to: position, scene: view.scene)
                self.firstPoint = nil
                onMeasurement(distance)
            } else {
                clearMeasurement()
                self.firstPoint = position
                addMarker(at: position, to: view.scene)
                onMeasurement(nil)
            }
        }

        func clearMeasurement() {
            firstPoint = nil
            for marker in markers { marker.removeFromParentNode() }
            markers.removeAll()
            lineNode?.removeFromParentNode()
            lineNode = nil
            onMeasurement(nil)
        }

        private func addMarker(at point: SCNVector3, to scene: SCNScene?) {
            let sphere = SCNSphere(radius: 0.008)
            sphere.firstMaterial?.diffuse.contents = UIColor.systemMint
            let node = SCNNode(geometry: sphere)
            node.position = point
            scene?.rootNode.addChildNode(node)
            markers.append(node)
        }

        private func addLine(from a: SCNVector3, to b: SCNVector3, scene: SCNScene?) {
            lineNode?.removeFromParentNode()
            let source = SCNGeometrySource(vertices: [a, b])
            let indices: [UInt32] = [0, 1]
            let data = indices.withUnsafeBytes { Data($0) }
            let element = SCNGeometryElement(data: data, primitiveType: .line, primitiveCount: 1, bytesPerIndex: MemoryLayout<UInt32>.size)
            let geometry = SCNGeometry(sources: [source], elements: [element])
            geometry.firstMaterial?.diffuse.contents = UIColor.systemMint
            let node = SCNNode(geometry: geometry)
            scene?.rootNode.addChildNode(node)
            lineNode = node
        }
    }
}

struct MeshScanView: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    @State private var measurementEnabled = false
    @State private var showingResetConfirmation = false

    private var isScanning: Bool { model.phase == .scanning }

    var body: some View {
        ZStack {
            MeshScanCameraView()
                .environmentObject(model)
                .ignoresSafeArea()
                .opacity(isScanning ? 1 : 0)
                .allowsHitTesting(isScanning)

            if !isScanning {
                Color.black.ignoresSafeArea()
            }

            switch model.phase {
            case .ready:
                ready
            case .scanning:
                scanning
            case .captured, .reconstructing:
                processing
            case .finished:
                finished
            case .failed(let message):
                failed(message)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                MeshExportOptionsView(sourceURL: url)
            }
        }
        .alert("Mesh撮影を終了しますか？", isPresented: $showingResetConfirmation) {
            Button("キャンセル", role: .cancel) {}
            if model.destructiveResetBlockedReason == nil {
                Button("破棄して戻る", role: .destructive) {
                    if model.reset() { dismiss() }
                }
            } else {
                Button("閉じて保存を再試行") {
                    dismiss()
                }
            }
        } message: {
            if let reason = model.destructiveResetBlockedReason {
                Text("\(reason) この画面を閉じると保存の再試行操作へ戻れます。")
            } else if model.phase == .finished {
                Text("完成済みMeshはローカルライブラリへ保存されます。現在のworkingデータを閉じます。")
            } else {
                Text("まだライブラリへ完成保存していない撮影・処理データは破棄されます。")
            }
        }
    }

    private var ready: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button {
                        if model.reset() { dismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    Spacer()
                    Text("Mesh")
                        .font(.headline)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }

                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 62, weight: .thin))
                    .foregroundStyle(.mint)

                Text("Meshスキャン")
                    .font(.largeTitle.bold())
                Text("テクスチャ付きポリゴンMeshを作り、切り抜き・計測・3Dツールへの受け渡しを行います。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text(model.capabilitySummary)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.1), in: Capsule())

                modeCard(
                    mode: .lidar,
                    icon: "viewfinder.circle",
                    title: "LiDARメッシュ",
                    detail: "実空間スケールを保ったARKitポリゴンMesh。計測と空間・部屋向け。",
                    enabled: model.supportsLiDARMesh
                )

                modeCard(
                    mode: .photogrammetry,
                    icon: "camera.macro",
                    title: "写真からメッシュ",
                    detail: "重なる写真からRealityKitで形状とテクスチャを端末内再構築。対象物向け。",
                    enabled: model.supportsPhotogrammetry
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("スキャン範囲")
                        .font(.subheadline.bold())
                    Picker("スキャン範囲", selection: $model.scanSize) {
                        ForEach(MeshScanSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("背景の不要な形状を減らすため、対象に合う範囲を選びます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))

                Button("Mesh撮影を開始") {
                    model.start()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((model.mode == .lidar && !model.supportsLiDARMesh) ||
                          (model.mode == .photogrammetry && !model.supportsPhotogrammetry))
            }
            .padding(20)
        }
    }

    private func modeCard(mode: MeshCaptureMode, icon: String, title: String, detail: String, enabled: Bool) -> some View {
        Button {
            if enabled { model.select(mode: mode) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background((model.mode == mode ? Color.mint : Color.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(model.mode == mode ? .black : .white)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(.headline)
                        if !enabled {
                            Text("非対応")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.orange.opacity(0.2), in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: model.mode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(model.mode == mode ? .mint : .secondary)
            }
            .padding(14)
            .background(.white.opacity(model.mode == mode ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var scanning: some View {
        VStack {
            HStack {
                Button {
                    showingResetConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.62), in: Circle())
                }
                Spacer()
                Text(model.mode.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.65), in: Capsule())
            }

            Spacer()

            if model.mode == .lidar {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.mint.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(width: 270, height: 270)
            } else {
                Circle()
                    .stroke(.white.opacity(0.82), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: 270, height: 270)
            }

            Spacer()

            VStack(spacing: 10) {
                Text(model.statusMessage)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    stat("写真", "\(model.frameCount)")
                    if model.mode == .lidar {
                        stat("頂点", model.vertexCount.formatted())
                        stat("面", model.faceCount.formatted())
                    }
                }

                if model.canFinish {
                    Button("撮影を完了してMesh生成") {
                        model.finish()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Text(model.mode == .lidar
                         ? "最低300面＋12枚の写真を取得すると生成できます"
                         : "最低24枚。対象の全周と上下を重なりを保って撮影してください")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 20))
        }
        .padding()
    }

    private var processing: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView(value: model.reconstructionProgress)
                .progressViewStyle(.circular)
                .scaleEffect(1.7)
                .tint(.mint)
            Text("Meshを生成中")
                .font(.title2.bold())
            Text(model.statusMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("\(Int(model.reconstructionProgress * 100))%")
                .font(.title3.monospacedDigit())
            ProgressView(value: model.reconstructionProgress)
                .tint(.mint)
                .padding(.horizontal, 24)
            if model.invalidPhotogrammetrySamples > 0 {
                Text("再構築に使えなかった写真: \(model.invalidPhotogrammetrySamples)枚")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("処理は端末内で行います。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private var finished: some View {
        if let scene = model.previewScene {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    MeshPreviewView(
                        scene: scene,
                        measurementEnabled: measurementEnabled,
                        onMeasurement: { model.setMeasuredDistance($0) }
                    )
                    .ignoresSafeArea(edges: .top)

                    HStack {
                        Button {
                            showingResetConfirmation = true
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.58), in: Circle())
                        }
                        Spacer()
                        Text(model.resultURL?.pathExtension.uppercased() ?? "MESH")
                            .font(.caption.bold())
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(.mint, in: Capsule())
                            .foregroundStyle(.black)
                    }
                    .padding()
                }

                ScrollView {
                    VStack(spacing: 12) {
                        HStack {
                            stat("頂点", model.vertexCount.formatted())
                            stat("面", model.faceCount.formatted())
                            if let distance = model.measuredDistanceMeters {
                                stat("計測", formatDistance(distance))
                            }
                        }

                        if let resetBlockedReason = model.destructiveResetBlockedReason {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Meshを保護中", systemImage: "externaldrive.badge.exclamationmark")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                                Text(resetBlockedReason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("×でこの画面を閉じると、保存を再試行できます。")
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        }

                        Toggle("2点タップで計測", isOn: $measurementEnabled)
                            .tint(.mint)

                        if model.rawOBJURL != nil {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("切り抜き")
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text("\(Int(model.cropInset * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Slider(
                                    value: Binding(
                                        get: { model.cropInset },
                                        set: { model.applyCropInset($0) }
                                    ),
                                    in: 0...0.35,
                                    step: 0.01
                                )
                                .tint(.mint)
                                Text("外周を実ジオメトリから除去してOBJを再生成します。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if model.mode == .lidar && model.supportsPhotogrammetry && model.frameCount >= 20 && model.resultURL?.pathExtension.lowercased() != "usdz" {
                            Button("写真からテクスチャ版USDZを生成") {
                                model.reconstructTexturedModel()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        HStack {
                            Button("Meshを書き出す") {
                                showingShare = true
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            Button("新しく撮る") {
                                model.reset()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(model.destructiveResetBlockedReason != nil)
                        }
                    }
                    .padding(16)
                }
                .frame(maxHeight: 340)
                .background(.black)
            }
        } else if let url = model.resultURL {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "cube.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.mint)
                Text("Mesh生成完了")
                    .font(.title2.bold())
                Text(url.lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let resetBlockedReason = model.destructiveResetBlockedReason {
                    VStack(spacing: 6) {
                        Label("Meshを保護中", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text(resetBlockedReason)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Text("×でこの画面を閉じると、保存を再試行できます。")
                            .font(.caption.bold())
                    }
                }
                Button("Meshを書き出す") { showingShare = true }
                    .buttonStyle(PrimaryButtonStyle())
                Button("新しく撮る") { model.reset() }
                    .foregroundStyle(.secondary)
                    .disabled(model.destructiveResetBlockedReason != nil)
                Spacer()
            }
            .padding(24)
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.orange)
            Text("Mesh処理を完了できませんでした")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Mesh設定へ戻る") {
                model.reset()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Splat画面へ戻る") {
                if model.reset() { dismiss() }
            }
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDistance(_ meters: Float) -> String {
        if meters < 1 {
            return "\(Int((meters * 100).rounded())) cm"
        }
        return String(format: "%.2f m", meters)
    }
}
