import SwiftUI

/// 学年の漢字グリッド。セルは漢字＋読み1つ＋学習済み印。
struct GradeKanjiListView: View {
    let grade: Int
    @Binding var path: NavigationPath
    @EnvironmentObject private var records: StudyRecordStore

    private var list: [KanjiEntry] {
        KanjiStore.shared.byGrade[grade] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                quizButtons
                grid
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 32)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "\(grade)年生の漢字"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var header: some View {
        let stats = records.gradeStats(grade)
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(grade)年生で習う漢字　全\(stats.total)字")
                .font(.maru(21))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 12) {
                Text(verbatim: "学習済み \(stats.studied)字")
                    .foregroundStyle(Palette.navy)
                if stats.attempts > 0 {
                    Text(verbatim: "正答率 \(stats.accuracy)%")
                        .foregroundStyle(Palette.sub)
                }
                if stats.weak > 0 {
                    Text(verbatim: "復習中 \(stats.weak)字")
                        .foregroundStyle(Palette.bad)
                }
                if stats.writingDone > 0 {
                    Text(verbatim: "書き完了 \(stats.writingDone)字")
                        .foregroundStyle(Palette.sub)
                }
            }
            .font(.caption.bold())
        }
        .padding(.top, 8)
    }

    private var quizButtons: some View {
        let sample = Array(list.shuffled().prefix(10))
        return VStack(spacing: 10) {
            NavigationLink(value: KanjiRoute.quiz(title: "\(grade)年生 読みクイズ", kanjiIDs: sample.map(\.kanji), mode: .kanjiToReading)) {
                Text("漢字を見て 読みを選ぶ（10問）")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
            .disabled(sample.isEmpty)
            NavigationLink(value: KanjiRoute.quiz(title: "\(grade)年生 読みクイズ", kanjiIDs: sample.map(\.kanji), mode: .readingToKanji)) {
                Text("読みを見て 漢字を選ぶ（10問）")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.sub))
            .disabled(sample.isEmpty)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], spacing: 10) {
            ForEach(list) { entry in
                Button {
                    path.append(KanjiRoute.detail(entry.kanji))
                } label: {
                    VStack(spacing: 3) {
                        Text(entry.kanji)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(records.isWeak(entry.kanji) ? Palette.bad : Palette.ink)
                        Text(firstReading(entry))
                            .font(.caption2)
                            .foregroundStyle(Palette.sub)
                            .lineLimit(1)
                        statusMark(entry)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func firstReading(_ entry: KanjiEntry) -> String {
        if let kun = entry.kunReadings.first { return kun.plain }
        return entry.onReadings.first ?? ""
    }

    @ViewBuilder
    private func statusMark(_ entry: KanjiEntry) -> some View {
        if records.isWeak(entry.kanji) {
            Text("復習中")
                .font(.caption2.bold())
                .foregroundStyle(Palette.bad)
        } else if records.writingCompletions(entry.kanji) > 0 {
            Label("書けた", systemImage: "pencil.circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(Palette.navy)
        } else if records.isStudied(entry.kanji) {
            Label("学習済み", systemImage: "checkmark.circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(Palette.good)
        } else {
            Text(" ")
                .font(.caption2)
        }
    }
}
