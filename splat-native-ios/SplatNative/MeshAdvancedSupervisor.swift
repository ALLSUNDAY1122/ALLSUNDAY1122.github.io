@preconcurrency import ARKit
import RealityKit
import SwiftUI

@MainActor
struct MeshAdvancedSupervisor: View {
    @EnvironmentObject var model: MeshScanModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var depthRecorder = MeshDepthRecorder()
    @State private var isPaused = false
    @State private var autoPaused = false
    @State private var showingRawReprocess = false
    @State private var showingSimplifier = false

    var body: some View {
        ZStack {
            if model.phase == .scanning {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if isPaused { resumeCapture() } else { pauseCapture(auto: false) }
                        } label: {
                            Label(isPaused ? "再開" : "一時停止", systemImage: isPaused ? "play.fill" : "pause.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.black.opacity(0.72), in: Capsule())
                        }
                    }
                    .padding(.top, 72)
                    .padding(.trailing, 16)
                    Spacer()
                }
            } else if model.phase == .ready {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showingRawReprocess = true
                        } label: {
                            Label("raw再処理", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                    }
                    .padding(.top, 70)
                    .padding(.trailing, 18)
                    Spacer()
                }
            } else if model.phase == .finished,
                      model.resultURL?.pathExtension.lowercased() == "obj",
                      model.rawOBJURL != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingSimplifier = true
                        } label: {
                            Label("Mesh軽量化", systemImage: "square.3.layers.3d.down.right")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(.mint, in: Capsule())
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 320)
                }
            }
        }
        .sheet(isPresented: $showingRawReprocess) {
            MeshRawReprocessSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $showingSimplifier) {
            if let url = model.rawOBJURL {
                MeshSimplifySheet(sourceURL: url)
                    .environmentObject(model)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                if model.phase == .scanning && !isPaused {
                    pauseCapture(auto: true)
                }
            case .active:
                if model.phase == .scanning && autoPaused {
                    resumeCapture()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: model.phase) { _, newPhase in
            if newPhase == .ready {
                isPaused = false
                autoPaused = false
                if depthRecorder.isRecording { depthRecorder.discard() }
            }
            if newPhase != .scanning {
                isPaused = false
                autoPaused = false
            }
        }
        .onChange(of: model.resultURL) { _, newURL in
            guard let newURL, depthRecorder.isRecording else { return }
            depthRecorder.finalize(into: newURL.deletingLastPathComponent())
        }
        .task(id: model.phase) {
            guard model.phase == .scanning, model.mode == .lidar else { return }
            if !depthRecorder.isRecording { depthRecorder.start() }
            while !Task.isCancelled && model.phase == .scanning {
                if !isPaused, let frame = model.session?.currentFrame {
                    depthRecorder.record(frame: frame)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    private func pauseCapture(auto: Bool) {
        guard model.phase == .scanning else { return }
        model.session?.pause()
        isPaused = true
        autoPaused = auto
        model.statusMessage = auto
            ? "バックグラウンド移行のため撮影を自動停止しました"
            : "撮影を一時停止しました"
    }

    private func resumeCapture() {
        guard model.phase == .scanning, let session = model.session else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isLightEstimationEnabled = true
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
        if model.mode == .lidar {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                configuration.sceneReconstruction = .meshWithClassification
            } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
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
            MeshScanView()
                .environmentObject(model)
            MeshAdvancedSupervisor()
                .environmentObject(model)
        }
    }
}
