import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: ScanModel
    @StateObject private var viewerState = SplatViewerState()
    @State private var showingShare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch model.phase {
            case .ready:
                ready
            case .capturing:
                capture
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
            if let url = model.resultURL { ShareSheet(items: [url]) }
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "cube.transparent")
                .font(.system(size: 68, weight: .thin))
                .foregroundStyle(.mint)
            Text("Splat Lab Native").font(.largeTitle.bold())
            Text("iPhoneだけで撮影 → 3D Gaussian Splat学習 → その場で表示。\n写真をポリゴンへ貼る方式は使いません。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("処理は端末内のみ", systemImage: "iphone")
                Label("LiDAR不要のARKitカメラ姿勢を使用", systemImage: "viewfinder")
                Label("MetalでGaussian Splatを学習", systemImage: "cpu")
            }.font(.subheadline)
            Spacer()
            Button("新しく3Dで残す") { model.startCapture() }
                .buttonStyle(PrimaryButtonStyle())
        }.padding(24)
    }

    private var capture: some View {
        ZStack {
            ScanCameraView().environmentObject(model).ignoresSafeArea()
            Color.black.opacity(0.08).ignoresSafeArea()
            VStack {
                HStack {
                    Button { model.discardAndReset() } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle())
                    }
                    Spacer()
                    Text(model.progressText).font(.headline.monospacedDigit()).padding(.horizontal, 14).padding(.vertical, 9).background(.black.opacity(0.55), in: Capsule())
                }
                Spacer()
                RoundedRectangle(cornerRadius: 150)
                    .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
                    .frame(width: 270, height: 270)
                    .overlay(alignment: .top) {
                        Text(model.captureBand).font(.caption.bold()).padding(8).background(.mint, in: Capsule()).foregroundStyle(.black).offset(y: -20)
                    }
                Spacer()
                VStack(spacing: 10) {
                    Text(model.trackingMessage).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                    ProgressView(value: Double(model.acceptedFrames), total: Double(model.targetFrames)).tint(.mint)
                    if model.canFinishCapture {
                        Button("この撮影で生成へ") { model.finishCapture() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Text("最低24枚、推奨48枚").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(16).background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
            }.padding()
        }
    }

    private var captured: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.mint)
            Text("\(model.acceptedFrames)枚を保存しました").font(.title2.bold())
            Text("次に、撮影画像とARKitのカメラ姿勢からGaussian SplatをiPhone内で学習します。初回PoCは2,000 iterationです。")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("端末内で3Dを生成") { model.train() }.buttonStyle(PrimaryButtonStyle())
            Button("撮り直す") { model.discardAndReset() }.foregroundStyle(.secondary)
            Spacer()
        }.padding(24)
    }

    private var training: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView(value: model.trainingProgress).progressViewStyle(.circular).scaleEffect(1.7).tint(.mint)
            Text("Gaussian Splatを生成中").font(.title2.bold())
            Text("iteration \(model.trainingIteration) / 2000")
                .font(.body.monospacedDigit()).foregroundStyle(.secondary)
            Text("splats \(model.splatCount.formatted())")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            ProgressView(value: model.trainingProgress).tint(.mint).padding(.horizontal, 24)
            Text("クラウドには送信していません。アプリを閉じずに生成を完了してください。")
                .font(.caption).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Spacer()
        }.padding(24)
    }

    @ViewBuilder private var finished: some View {
        if let url = model.resultURL {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SplatViewer(url: url, state: viewerState).ignoresSafeArea(edges: .top)
                    HStack {
                        Button { model.discardAndReset() } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle())
                        }
                        Spacer()
                        Text("実Gaussian Splat").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 8).background(.mint, in: Capsule()).foregroundStyle(.black)
                    }.padding()
                }
                VStack(spacing: 10) {
                    Text("1本指で回転・ピンチで拡大縮小").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Splatを書き出す") { showingShare = true }.buttonStyle(SecondaryButtonStyle())
                        Button("もう一度撮る") { model.discardAndReset() }.buttonStyle(PrimaryButtonStyle())
                    }
                }.padding(16).background(.black)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 54)).foregroundStyle(.orange)
            Text("処理を完了できませんでした").font(.title2.bold())
            Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("最初からやり直す") { model.discardAndReset() }.buttonStyle(PrimaryButtonStyle())
            Spacer()
        }.padding(24)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(.mint.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.black)
    }
}
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(.white.opacity(configuration.isPressed ? 0.08 : 0.14), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
