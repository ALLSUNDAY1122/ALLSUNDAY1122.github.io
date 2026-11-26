import SwiftUI

/// KanjiVG のパスを画ごとに描く筆順ビュー。
/// ステップ表示（1画ずつ進める／戻す）と自動再生（各画を trim で描く）に対応する。
struct StrokeOrderView: View {
    let entry: KanjiEntry

    @State private var shown: Int
    @State private var partial: CGFloat = 0
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?

    init(entry: KanjiEntry) {
        self.entry = entry
        _shown = State(initialValue: entry.strokeCount)
    }

    private var strokes: [KanjiStroke] {
        KanjiStore.shared.strokes(for: entry)
    }

    var body: some View {
        VStack(spacing: 12) {
            canvas
            controls
        }
        .onDisappear { stop() }
    }

    private var canvas: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lineWidth = max(2, side / 109 * 3.4)
            ZStack {
                Rectangle()
                    .fill(Palette.card)
                // マス目の十字ガイド
                Path { path in
                    path.move(to: CGPoint(x: side / 2, y: 0))
                    path.addLine(to: CGPoint(x: side / 2, y: side))
                    path.move(to: CGPoint(x: 0, y: side / 2))
                    path.addLine(to: CGPoint(x: side, y: side / 2))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                Rectangle()
                    .stroke(Palette.line, lineWidth: 1)
                ForEach(strokes.indices, id: \.self) { i in
                    if i < shown {
                        KanjiStrokeShape(path: strokes[i].path)
                            .stroke(Palette.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    } else if i == shown, partial > 0 {
                        KanjiStrokeShape(path: strokes[i].path)
                            .trim(from: 0, to: partial)
                            .stroke(Palette.navy, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 250)
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    stop()
                    partial = 0
                    shown = max(0, shown - 1)
                } label: {
                    Label("もどす", systemImage: "chevron.left")
                }
                .disabled(shown == 0 && partial == 0)
                Text(verbatim: "\(shown) / \(entry.strokeCount) 画")
                    .font(.subheadline.bold())
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 84)
                Button {
                    stop()
                    partial = 0
                    shown = min(entry.strokeCount, shown + 1)
                } label: {
                    Label("すすむ", systemImage: "chevron.right")
                }
                .disabled(shown >= entry.strokeCount)
            }
            .buttonStyle(.bordered)
            .tint(Palette.navy)
            Button {
                isPlaying ? stop() : play()
            } label: {
                Label(isPlaying ? "とめる" : "筆順を再生", systemImage: isPlaying ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
        }
    }

    private func play() {
        stop()
        isPlaying = true
        shown = 0
        partial = 0
        let list = strokes
        playTask = Task { @MainActor in
            for i in list.indices {
                shown = i
                partial = 0
                withAnimation(.linear(duration: 0.45)) { partial = 1 }
                try? await Task.sleep(nanoseconds: 600_000_000)
                if Task.isCancelled { return }
                shown = i + 1
                partial = 0
            }
            isPlaying = false
        }
    }

    private func stop() {
        playTask?.cancel()
        playTask = nil
        isPlaying = false
    }
}
