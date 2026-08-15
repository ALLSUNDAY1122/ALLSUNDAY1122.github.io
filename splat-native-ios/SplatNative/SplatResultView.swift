import SwiftUI

@MainActor
struct SplatResultView: View {
    @EnvironmentObject private var model: ScanModel
    let url: URL
    @Binding var showingShare: Bool

    @StateObject private var viewerState = SplatViewerState()
    @State private var selectedTool: ViewerTool = .view
    @State private var confirmNewScan = false

    private enum ViewerTool: String, CaseIterable, Hashable {
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
                    topOverlay
                    Spacer()
                }

                if let error = viewerState.errorMessage {
                    errorOverlay(error)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
        }
        .background(Color.black)
        .onAppear { viewerState.attach(url: url) }
        .onChange(of: url) { _, newURL in
            viewerState.attach(url: newURL)
        }
        .onChange(of: viewerState.editSettings) { _, _ in
            viewerState.schedulePersistence()
        }
        .confirmationDialog("新しい撮影を開始しますか？", isPresented: $confirmNewScan, titleVisibility: .visible) {
            Button("現在の撮影データを削除して開始", role: .destructive) {
                model.discardAndReset()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のプロジェクトは削除されます。")
        }
    }

    private var topOverlay: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Scan Lab")
                    .font(.headline.bold())
                if viewerState.totalPointCount > 0 {
                    Text("表示 \(viewerState.visiblePointCount.formatted()) / \(viewerState.totalPointCount.formatted()) splats")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            if viewerState.isLoading || viewerState.isApplyingEdits {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(viewerState.isLoading ? "読込中" : "反映中")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.black.opacity(0.62), in: Capsule())
            }
        }
        .padding()
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("表示ツール", selection: $selectedTool) {
                ForEach(ViewerTool.allCases, id: \.self) { tool in
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

            Divider().overlay(.white.opacity(0.15))

            HStack(spacing: 9) {
                Button {
                    viewerState.persistNow()
                    model.enhanceResult()
                } label: {
                    Label("品質向上", systemImage: "sparkles")
                }
                .buttonStyle(ViewerActionButtonStyle())

                Button {
                    viewerState.persistNow()
                    showingShare = true
                } label: {
                    Label("書き出す", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ViewerActionButtonStyle())
            }

            HStack(spacing: 9) {
                Button {
                    viewerState.persistNow()
                    model.retryGeneration()
                } label: {
                    Label("再処理", systemImage: "arrow.clockwise")
                }
                .buttonStyle(ViewerActionButtonStyle())
                .disabled(!model.canRetryGeneration)

                Button {
                    confirmNewScan = true
                } label: {
                    Label("新規", systemImage: "camera")
                }
                .buttonStyle(ViewerActionButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.black)
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch selectedTool {
        case .view:
            VStack(spacing: 10) {
                Text("1本指で回転・2本指で移動・ピンチで拡大縮小。2本指ダブルタップでも初期位置へ戻せます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Button {
                        viewerState.requestCameraReset()
                    } label: {
                        Label("表示位置を戻す", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewerState.resetEdits()
                    } label: {
                        Label("編集を全解除", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.bordered)
                }
            }

        case .crop:
            VStack(spacing: 10) {
                Text("元のSplatは残したまま、不要な範囲だけを非表示にします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                cropRangeRow("左右", low: $viewerState.cropXMin, high: $viewerState.cropXMax)
                cropRangeRow("上下", low: $viewerState.cropYMin, high: $viewerState.cropYMax)
                cropRangeRow("奥行き", low: $viewerState.cropZMin, high: $viewerState.cropZMax)
            }

        case .adjust:
            VStack(spacing: 10) {
                sliderRow(
                    title: "露出",
                    valueText: String(format: "%+.1f EV", viewerState.exposureEV),
                    value: $viewerState.exposureEV,
                    range: -2...2,
                    step: 0.1
                )
                sliderRow(
                    title: "コントラスト",
                    valueText: "\(Int((viewerState.contrast * 100).rounded()))%",
                    value: $viewerState.contrast,
                    range: 0.5...1.5,
                    step: 0.05
                )
            }

        case .measure:
            VStack(spacing: 10) {
                Toggle("2点計測", isOn: $viewerState.measurementEnabled)
                    .tint(.mint)
                Text(viewerState.measurementText)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("計測中は画面上のSplatを2点タップします。距離は撮影時のARKit実スケールを使用します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("クリア") {
                        viewerState.requestMeasurementClear()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func cropRangeRow(_ title: String,
                              low: Binding<Double>,
                              high: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.caption.bold())
                Spacer()
                Text("\(Int((low.wrappedValue * 100).rounded()))–\(Int((high.wrappedValue * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Text("始").font(.caption2).foregroundStyle(.secondary)
                Slider(value: low, in: 0...max(0.02, high.wrappedValue - 0.02), step: 0.01)
                    .tint(.mint)
                Text("終").font(.caption2).foregroundStyle(.secondary)
                Slider(value: high, in: min(0.98, low.wrappedValue + 0.02)...1, step: 0.01)
                    .tint(.mint)
            }
        }
    }

    private func sliderRow(title: String,
                           valueText: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           step: Double) -> some View {
        VStack(spacing: 4) {
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

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
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
        .padding(20)
        .frame(maxWidth: 320)
        .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct ViewerActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(.white.opacity(configuration.isPressed ? 0.08 : 0.14), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
    }
}
