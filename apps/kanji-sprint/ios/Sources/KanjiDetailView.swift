import SwiftUI

/// 漢字の詳細：大きな漢字、音読み・訓読み、画数、筆順、クイズと書き練習への導線。
struct KanjiDetailView: View {
    let kanji: String
    @Binding var path: NavigationPath
    @EnvironmentObject private var records: StudyRecordStore

    private var entry: KanjiEntry? {
        KanjiStore.shared.entry(kanji)
    }

    var body: some View {
        ScrollView {
            if let entry {
                VStack(alignment: .leading, spacing: 16) {
                    header(entry)
                    readingsCard(entry)
                    strokeCard(entry)
                    recordCard(entry)
                    actionButtons(entry)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            } else {
                Text("漢字が見つかりませんでした。")
                    .foregroundStyle(Palette.sub)
                    .padding()
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "\(kanji)（\(entry?.grade ?? 0)年生）"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func header(_ entry: KanjiEntry) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(entry.kanji)
                .font(.system(size: 96, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
                .frame(width: 130, height: 130)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "\(entry.grade)年生で習う漢字")
                    .font(.subheadline.bold())
                    .foregroundStyle(Palette.navy)
                Text(verbatim: "\(entry.strokeCount)画")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
                if records.isWeak(entry.kanji) {
                    Text("苦手に登録中")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.bad)
                }
                if records.writingCompletions(entry.kanji) > 0 {
                    Text(verbatim: "書き練習 完了 \(records.writingCompletions(entry.kanji))回")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.good)
                }
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private func readingsCard(_ entry: KanjiEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("読み")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            if !entry.onReadings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("音読み")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.sub)
                    Text(entry.onReadings.joined(separator: "・"))
                        .font(.title3.bold())
                        .foregroundStyle(Palette.ink)
                }
            }
            if !entry.kunReadings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("訓読み（送り仮名は青色）")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.sub)
                    FlowLayout(spacing: 10) {
                        ForEach(entry.kunReadings, id: \.self) { reading in
                            HStack(spacing: 0) {
                                Text(reading.stem)
                                    .foregroundStyle(Palette.ink)
                                if !reading.okurigana.isEmpty {
                                    Text(reading.okurigana)
                                        .foregroundStyle(Palette.navy)
                                }
                            }
                            .font(.title3.bold())
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private func strokeCard(_ entry: KanjiEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("筆順")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            StrokeOrderView(entry: entry)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private func recordCard(_ entry: KanjiEntry) -> some View {
        let record = records.state.records[entry.kanji]
        return VStack(alignment: .leading, spacing: 6) {
            Text("この字の記録")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            if let record, record.attempts > 0 {
                Text(verbatim: "読みクイズ \(record.attempts)回中 \(record.correct)回正解")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            } else {
                Text("読みクイズはまだ解いていません。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private func actionButtons(_ entry: KanjiEntry) -> some View {
        var set: [KanjiEntry] = [entry]
        let others = (KanjiStore.shared.byGrade[entry.grade] ?? [])
            .filter { $0.kanji != entry.kanji }
            .shuffled()
        set.append(contentsOf: others.prefix(9))
        return VStack(spacing: 10) {
            NavigationLink(value: KanjiRoute.quiz(title: "読みクイズ", kanjiIDs: set.map(\.kanji), mode: .mixed)) {
                Text("読みクイズ（この字から10問）")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            NavigationLink(value: KanjiRoute.writing(entry.kanji)) {
                Text("書き練習をする")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.accent))
        }
    }
}

/// 読みの折り返し表示用レイアウト。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
