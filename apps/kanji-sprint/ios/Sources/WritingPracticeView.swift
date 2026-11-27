import SwiftUI

/// なぞり書き練習。薄いお手本の上に、対象の画だけ色付きで示す。
/// 指を離した時点で判定する：ユーザーの始点・終点が対象画の始点・終点から
/// それぞれ許容距離（109座標系で28以内）にあること。
struct WritingPracticeView: View {
    let entry: KanjiEntry
    @EnvironmentObject private var records: StudyRecordStore

    @State private var currentIndex = 0
    @State private var currentPoints: [CGPoint] = []
    @State private var acceptedPaths: [Path] = []
    @State private var hint: String?
    @State private var finished = false
    @State private var showModel = false
    @State private var pulse = false

    private let tolerance: CGFloat = 28

    private var strokes: [KanjiStroke] {
        KanjiStore.shared.strokes(for: entry)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                canvas
                if let hint, !finished {
                    Text(hint)
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.bad)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                if finished {
                    finishedView
                } else {
                    HStack(spacing: 10) {
                        Button("お手本をみる") { showModel = true }
                            .buttonStyle(.bordered)
                            .tint(Palette.navy)
                        Button("はじめから") { reset() }
                            .buttonStyle(.bordered)
                            .tint(Palette.sub)
                    }
                    .frame(maxWidth: .infinity)
                }
                Text("お手本の画と同じ順番で書きます。書き始めと書き終わりの位置が合えば次へ進みます。")
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "書き練習「\(entry.kanji)」"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showModel) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        StrokeOrderView(entry: entry)
                        Text(verbatim: "音読み：\(entry.onReadings.joined(separator: "・"))")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        if !entry.kunReadings.isEmpty {
                            Text(verbatim: "訓読み：\(entry.kunReadings.map(\.plain).joined(separator: "・"))")
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .padding(18)
                }
                .background(Palette.paper.ignoresSafeArea())
                .navigationTitle(Text(verbatim: "お手本「\(entry.kanji)」"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showModel = false }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(verbatim: "\(entry.grade)年生・\(entry.strokeCount)画")
                .font(.caption.bold())
                .foregroundStyle(Palette.sub)
            Spacer()
            Text(verbatim: finished ? "\(entry.strokeCount) / \(entry.strokeCount) 画" : "\(currentIndex) / \(entry.strokeCount) 画")
                .font(.subheadline.bold())
                .foregroundStyle(Palette.ink)
        }
        .padding(.top, 8)
    }

    private var canvas: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 109
            let lineWidth = max(2, side / 109 * 3.4)
            ZStack {
                Rectangle()
                    .fill(Palette.card)
                Path { path in
                    path.move(to: CGPoint(x: side / 2, y: 0))
                    path.addLine(to: CGPoint(x: side / 2, y: side))
                    path.move(to: CGPoint(x: 0, y: side / 2))
                    path.addLine(to: CGPoint(x: side, y: side / 2))
                }
                .stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                // お手本（全画を薄く）
                ForEach(strokes.indices, id: \.self) { i in
                    KanjiStrokeShape(path: strokes[i].path)
                        .stroke(Palette.sub.opacity(0.22), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
                // 現在の対象画
                if !finished, currentIndex < strokes.count {
                    KanjiStrokeShape(path: strokes[currentIndex].path)
                        .stroke(Palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                        .opacity(pulse ? 0.95 : 0.4)
                }
                // 合格した画（ユーザーが実際に書いた線）
                ForEach(acceptedPaths.indices, id: \.self) { i in
                    acceptedPaths[i]
                        .stroke(Palette.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
                // 書いている途中の線
                if currentPoints.count > 1 {
                    polyline(currentPoints)
                        .stroke(Palette.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                }
                Rectangle()
                    .stroke(Palette.line, lineWidth: 1)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .clipped()
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !finished else { return }
                        currentPoints.append(value.location)
                    }
                    .onEnded { _ in
                        judge(side: side)
                    }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .frame(height: 340)
    }

    private var finishedView: some View {
        VStack(spacing: 12) {
            Text("書けた！")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Palette.good)
            Text(verbatim: "「\(entry.kanji)」を \(entry.strokeCount)画で書けました。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            Button("もう一度書く") { reset() }
                .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        path.addLines(Array(points.dropFirst()))
        return path
    }

    private func judge(side: CGFloat) {
        defer { currentPoints = [] }
        guard !finished, currentPoints.count >= 2, currentIndex < strokes.count else { return }
        let scale = side / 109
        guard let first = currentPoints.first, let last = currentPoints.last, scale > 0 else { return }
        let userStart = CGPoint(x: first.x / scale, y: first.y / scale)
        let userEnd = CGPoint(x: last.x / scale, y: last.y / scale)
        let target = strokes[currentIndex]
        let startOK = distance(userStart, target.start) <= tolerance
        let endOK = distance(userEnd, target.end) <= tolerance
        if startOK && endOK {
            acceptedPaths.append(polyline(currentPoints))
            currentIndex += 1
            hint = nil
            if currentIndex >= strokes.count {
                finished = true
                records.recordWriting(kanji: entry.kanji)
            }
        } else if !startOK && !endOK {
            hint = "書き始めと書き終わりの位置がちがうよ"
        } else if !startOK {
            hint = "書き始めの位置がちがうよ"
        } else {
            hint = "書き終わりの位置がちがうよ"
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func reset() {
        currentIndex = 0
        currentPoints = []
        acceptedPaths = []
        hint = nil
        finished = false
    }
}
