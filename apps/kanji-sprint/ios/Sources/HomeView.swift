import SwiftUI

enum QuizMode: Hashable {
    case kanjiToReading
    case readingToKanji
    case mixed
}

enum KanjiRoute: Hashable {
    case grade(Int)
    case detail(String)
    case quiz(title: String, kanjiIDs: [String], mode: QuizMode)
    case writing(String)
}

struct HomeView: View {
    @State private var path = NavigationPath()
    @State private var showSettings = false
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore

    private let dailyGoal = 10

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        Button { showSettings = true } label: {
                            Label(premium.isNoAds ? "設定・広告なし利用中" : "設定・広告なし（買い切り）", systemImage: "gearshape")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(Palette.navy)
                        todayCard
                        studyStatusCard
                        weakReviewCard
                        Text("学年から選ぶ")
                            .font(.maru(17))
                            .foregroundStyle(Palette.sub)
                        gradeGrid
                        sourceNotice
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
                if !premium.isNoAds {
                    Divider()
                    AdsBannerView()
                        .frame(height: 50)
                        .background(Palette.paper)
                }
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("小学生漢字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: KanjiRoute.self) { route in
                switch route {
                case .grade(let grade):
                    GradeKanjiListView(grade: grade, path: $path)
                case .detail(let kanji):
                    KanjiDetailView(kanji: kanji, path: $path)
                case .quiz(let title, let kanjiIDs, let mode):
                    ReadingQuizView(
                        title: title,
                        entries: kanjiIDs.compactMap { KanjiStore.shared.entry($0) },
                        mode: mode,
                        path: $path
                    )
                case .writing(let kanji):
                    if let entry = KanjiStore.shared.entry(kanji) {
                        WritingPracticeView(entry: entry)
                    }
                }
            }
        }
        .tint(Palette.navy)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学びスプリント")
                .font(.caption.bold())
                .foregroundStyle(Palette.sub)
            Text("小学生漢字")
                .font(.maru(31))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("読みと書きを、学年ごとに。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { grade in
                    Circle()
                        .fill(Palette.gradeColor(grade))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 4)
        }
        .padding(.top, 10)
    }

    private var todayCard: some View {
        let daily = KanjiStore.shared.daily(limit: dailyGoal, weakIDs: records.weakIDs)
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日の学習")
                .font(.maru(21))
                .foregroundStyle(Palette.ink)
            Text("苦手な字を優先して10字出します。字をタップすると書き練習もできます。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            if !daily.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(Array(daily.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            path.append(KanjiRoute.detail(entry.kanji))
                        } label: {
                            Text(entry.kanji)
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundStyle(records.isWeak(entry.kanji) ? Palette.bad : Palette.ink)
                                .frame(width: 44, height: 44)
                                .background(Palette.gradeSoft(index % 6 + 1), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            NavigationLink(value: KanjiRoute.quiz(title: "今日の学習", kanjiIDs: daily.map(\.kanji), mode: .mixed)) {
                Text(verbatim: "読みクイズをはじめる　\(daily.count)字")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
            .disabled(daily.isEmpty)
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var studyStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学習状況")
                .font(.maru(21))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 0) {
                statCell(value: "\(records.totalAnswered)", label: "総回答数")
                Divider()
                statCell(value: "\(records.accuracy)%", label: "正答率")
                Divider()
                statCell(value: "\(records.weakCount)", label: "苦手")
                Divider()
                statCell(value: "\(records.writingDoneCount)", label: "書き完了")
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("今日の進捗")
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text(verbatim: "今日 \(records.todayAnswered)問 / 目標\(dailyGoal)問")
                        .font(.caption)
                        .foregroundStyle(Palette.sub)
                }
                ProgressView(value: Double(min(records.todayAnswered, dailyGoal)), total: Double(dailyGoal))
                    .tint(Palette.navy)
            }
            if !records.state.history.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近の学習")
                        .font(.caption.bold())
                        .foregroundStyle(Palette.sub)
                    ForEach(records.state.history.prefix(3)) { session in
                        HStack {
                            Text(session.title)
                                .font(.caption)
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            Text(verbatim: "\(session.score)/\(session.total)問")
                                .font(.caption)
                                .foregroundStyle(Palette.sub)
                            Text(session.date, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(Palette.sub)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.sub)
        }
        .frame(maxWidth: .infinity)
    }

    private var weakReviewCard: some View {
        let weak = records.weakKanji()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("苦手復習")
                    .font(.maru(21))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(verbatim: "現在の苦手 \(records.weakCount)字")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.navy)
            }
            Text("読みクイズで間違えた字を集めて復習できます。3回連続で正解すると苦手から外れます。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            NavigationLink(value: KanjiRoute.quiz(title: "苦手復習", kanjiIDs: weak.map(\.kanji), mode: .mixed)) {
                Text(verbatim: "苦手だけ復習する　\(weak.count)字")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.primary))
            .disabled(weak.isEmpty)
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var gradeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(1...6, id: \.self) { grade in
                let stats = records.gradeStats(grade)
                NavigationLink(value: KanjiRoute.grade(grade)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Palette.gradeColor(grade))
                                    .frame(width: 34, height: 34)
                                Text(verbatim: "\(grade)")
                                    .font(.maru(18))
                                    .foregroundStyle(.white)
                            }
                            Text(verbatim: "\(grade)年生")
                                .font(.maru(20))
                                .foregroundStyle(Palette.ink)
                            if stats.studied >= 1 {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Palette.accent)
                            }
                            Spacer()
                        }
                        Text(verbatim: "全\(stats.total)字")
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                        Text(verbatim: "学習済み \(stats.studied)字")
                            .font(.caption.bold())
                            .foregroundStyle(Palette.navy)
                        if stats.attempts > 0 {
                            Text(verbatim: "正答率 \(stats.accuracy)%・苦手 \(stats.weak)字")
                                .font(.caption)
                                .foregroundStyle(Palette.sub)
                        } else {
                            Text("未回答")
                                .font(.caption)
                                .foregroundStyle(Palette.sub)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sourceNotice: some View {
        Text("漢字の学年・読み・画数は KANJIDIC2（© EDRDG）、筆順は KanjiVG（© Ulrich Apel and contributors）のデータを使っています。学年は文部科学省の学年別漢字配当表に基づきます。")
            .font(.caption)
            .foregroundStyle(Palette.sub)
            .padding(.top, 4)
    }
}
