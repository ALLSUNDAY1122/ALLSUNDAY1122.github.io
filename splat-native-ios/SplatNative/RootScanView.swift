@preconcurrency import ARKit
import SceneKit
import SwiftUI

/// Keeps one ARSession alive for the whole app lifecycle.
/// The camera is not started until ScanModel.startCapture() explicitly runs the session.
struct PersistentScanCameraView: UIViewRepresentable {
    @EnvironmentObject var model: ScanModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.automaticallyConfigureSession = false
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
    @State private var showingShare = false

    private var isCapturing: Bool { model.phase == .capturing }

    var body: some View {
        ZStack {
            // This view must stay mounted even before capture starts. ScanModel.startCapture()
            // requires an attached ARSession and then explicitly starts world tracking.
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
        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "cube.transparent")
                .font(.system(size: 68, weight: .thin))
                .foregroundStyle(.mint)
            Text("Splat Lab")
                .font(.largeTitle.bold())
            Text("残したい物の周囲をゆっくり撮影すると、\niPhoneの中だけで立体の思い出を生成します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("写真・3Dデータは端末外へ送信しません", systemImage: "lock.iphone")
                Label("LiDARなしでも撮影できます", systemImage: "viewfinder")
                Label("生成後は指で回して見返せます", systemImage: "rotate.3d")
            }
            .font(.subheadline)
            Spacer()
            Button("新しく3Dで残す") {
                model.startCapture()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }

    private var captureOverlay: some View {
        ZStack {
            Color.black.opacity(0.08).ignoresSafeArea()
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
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(model.progressText)
                            .font(.headline.monospacedDigit())
                        Text("特徴点 \(model.featurePointCount.formatted())")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
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
                    ProgressView(value: Double(model.acceptedFrames), total: Double(model.targetFrames))
                        .tint(.mint)

                    if model.canFinishCapture && model.featurePointCount >= 64 {
                        Button("この撮影で生成へ") {
                            model.finishCapture()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else if model.acceptedFrames >= 24 {
                        Text("立体の手がかりを集めています。対象の周囲をもう少し移動してください")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("最低24枚、推奨48枚")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 20))
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
            Text("\(model.acceptedFrames)枚の画像と \(model.featurePointCount.formatted()) 個の立体特徴点を使い、端末内で3Dを生成します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("端末内で3Dを生成") {
                model.train()
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("撮り直す") {
                model.discardAndReset()
            }
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
            Text("立体の思い出を生成中")
                .font(.title2.bold())
            Text("iteration \(model.trainingIteration) / 2000")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("splats \(model.splatCount.formatted())")
                .font(.caption.monospacedDigit())
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
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SplatViewer(url: url)
                        .ignoresSafeArea(edges: .top)
                    HStack {
                        Button {
                            model.discardAndReset()
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

                VStack(spacing: 10) {
                    Text("1本指で回転・ピンチで拡大縮小")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("3Dを書き出す") {
                            showingShare = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        Button("もう一度撮る") {
                            model.discardAndReset()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(16)
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
            Button("最初からやり直す") {
                model.discardAndReset()
            }
            .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding(24)
    }
}
