@preconcurrency import ARKit
import SceneKit
import SwiftUI

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
    @State private var showingShare = false
    @State private var showingDiscardConfirmation = false

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
        .sheet(isPresented: $showingShare) {
            if let url = model.resultURL {
                ShareSheet(items: [url])
            }
        }
        .alert("現在の3Dを破棄しますか？", isPresented: $showingDiscardConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("破棄して新しく撮る", role: .destructive) {
                model.discardAndReset()
            }
        } message: {
            Text("この検証版にはまだスキャンライブラリがありません。書き出していない3Dは、破棄すると元に戻せません。")
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
            Text("スマホを向けて周囲を撮影し、\niPhone内で高品質な3Dを生成します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("撮影データを開発者サーバーへ自動送信しません", systemImage: "lock.iphone")
                Label("LiDARなしでもSplat撮影を検証できます", systemImage: "iphone")
                Label("完成後は回転・拡大して確認できます", systemImage: "rotate.3d")
            }
            .font(.subheadline)
            Spacer()
            Button("新しくスキャン") {
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
            Text("対象の周囲から必要な写真がそろいました。\niPhoneの中でGaussian Splatを生成します。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("3Dを生成") {
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
}
