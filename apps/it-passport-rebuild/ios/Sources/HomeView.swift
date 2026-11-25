import SwiftUI

private struct StudyDomain: Identifiable, Hashable {
    let id: String
    let title: String
}

private struct QuestionSet: Identifiable, Hashable {
    let id: Int
    let start: Int
    let end: Int

    var title: String { "セット \(id)" }
    var subtitle: String { "問題 \(start)〜\(end)" }
}

private enum StudyRoute: Hashable {
    case domain(domainId: String)
    case quiz(title: String, questions: [StudyQuestion], isMock: Bool = false)
}

private enum Palette {
    static let paper = Color(red: 247/255, green: 243/255, blue: 234/255)
    static let card = Color(red: 1.0, green: 253/255, blue: 249/255)
    static let navy = Color(red: 47/255, green: 74/255, blue: 109/255)
    static let line = Color(red: 232/255, green: 223/255, blue: 207/255)

    static let ink = Color(red: 31/255, green: 41/255, blue: 55/255)

    static let sub = Color(red: 91/255, green: 100/255, blue: 112/255)
}

struct HomeView: View {
    @State private var dailyCount = 8
    @State private var path = NavigationPath()
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @State private var showSettings = false

    private let domains = [
        StudyDomain(id: "strategy", title: "ストラテジ系"),
        StudyDomain(id: "management", title: "マネジメント系"),
        StudyDomain(id: "technology", title: "テクノロジ系")
    ]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    Button { showSettings = true } label: {
                        Label(premium.isPremium ? "設定・Premium利用中" : "設定・Premium（全500問）", systemImage: "gearshape")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    todayCard
                    studyStatusCard
                    weakReviewCard
                    mockExamCard
                    VStack(alignment: .leading, spacing: 4) {
                        Text("分野から解く")
                            .font(.headline)
                            .foregroundStyle(Palette.sub)
                        Text(premium.isPremium ? "表示中の問題数は全500問分の合計です。" : "表示中の問題数は2026年度100問分の内訳です。Premiumでは全500問分の合計になります。")
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                    }
                    domainGrid
                    officialExamCard
                    sourceNotice
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 32)
            }
            .background(Palette.paper.ignoresSafeArea())
            .navigationTitle("ITパスポート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: StudyRoute.self) { route in
                switch route {
                case .domain(let domainId):
                    if let domain = domains.first(where: { $0.id == domainId }) {
                        DomainSetView(domain: domain)
                    }
                case .quiz(let title, let questions, let isMock):
                    QuizView(title: title, questions: questions, isMock: isMock, path: $path)
                }
            }
        }
        .tint(Palette.navy)
        .sheet(isPresented: $showSettings) { PremiumSettingsView() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("学びスプリント")
                .font(.caption.bold())
                .foregroundStyle(Palette.sub)
            Text("ITパスポート")
                .font(.system(size: 31, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("今日も1問、力に変える。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
        }
        .padding(.top, 10)
    }

    private var todayCard: some View {
        let daily = QuestionStore.daily(limit: dailyCount, premium: premium.isPremium, weakIDs: records.weakIDs)
        return VStack(alignment: .leading, spacing: 10) {
            Text("今日の学習")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            Text("片手でも進めやすい短時間学習。今日の問題数を選べます。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            Picker("問題数", selection: $dailyCount) {
                Text("4問").tag(4)
                Text("8問").tag(8)
                Text("16問").tag(16)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("今日の学習の問題数")
            NavigationLink(value: StudyRoute.quiz(title: "今日のスプリント", questions: daily)) {
                Text("今日のスプリントを始める　\(daily.count)問")
            }
            .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            .disabled(daily.isEmpty)
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private var studyStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学習状況")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 0) {
                statCell(value: "\(records.totalAnswered)", label: "総回答数")
                Divider()
                statCell(value: "\(records.accuracy)%", label: "正答率")
                Divider()
                statCell(value: "\(records.weakCount)", label: "苦手")
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("今日の進捗")
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("今日 \(records.todayAnswered)問 / 目標\(dailyCount)問")
                        .font(.caption)
                        .foregroundStyle(Palette.sub)
                }
                ProgressView(value: Double(min(records.todayAnswered, dailyCount)), total: Double(dailyCount))
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
                            Text("\(session.score)/\(session.total)問")
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
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("苦手復習")
                    .font(.system(size: 21, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("現在の苦手 \(records.weakCount)問")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.navy)
            }
            Text("不正解だった問題を集めて復習できます。3回連続で正解すると苦手から外れます。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            if records.weakCount == 0 {
                Text("苦手はありません。この調子で続けましょう。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            } else if premium.isPremium {
                NavigationLink(value: StudyRoute.quiz(title: "苦手復習", questions: records.weakQuestions())) {
                    Text("苦手復習を始める　\(records.weakCount)問")
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            } else {
                Button { showSettings = true } label: {
                    HStack {
                        Text("苦手復習はPremiumで利用できます")
                        Spacer()
                        Image(systemName: "lock.fill")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line))
    }

    private var mockExamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("模試")
                .font(.system(size: 21, weight: .bold, design: .serif))
                .foregroundStyle(Palette.ink)
            Text("年度別の公式公開問題100問を120分で解きます。採点は終了時のみ。公式IRT評価点・合否判定ではありません。")
                .font(.subheadline)
                .foregroundStyle(Palette.sub)
            ForEach(QuestionStore.availableOfficialYears, id: \.self) { year in
                let questions = QuestionStore.officialExam(year: year, premium: premium.isPremium)
                if !premium.isPremium && year != QuestionStore.freeYear {
                    Button { showSettings = true } label: {
                        HStack {
                            Text(verbatim: "\(year)年度").font(.subheadline.bold()).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("Premium・模試100問").font(.caption).foregroundStyle(Palette.sub)
                            Image(systemName: "lock.fill")
                        }
                    }
                    .buttonStyle(.plain)
                } else if questions.count == 100 {
                    NavigationLink(value: StudyRoute.quiz(title: "\(year)年度 模試", questions: questions, isMock: true)) {
                        HStack {
                            Text(verbatim: "\(year)年度").font(.subheadline.bold()).foregroundStyle(Palette.ink)
                            Spacer()
                            Text("100問・120分").font(.caption).foregroundStyle(Palette.sub)
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
    }

    private var domainGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(domains) { domain in
                let stats = records.domainStats(domain: domain.id, premium: premium.isPremium)
                NavigationLink(value: StudyRoute.domain(domainId: domain.id)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(domain.title)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Text("回答済み \(stats.answered)/\(stats.total)問")
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                        Text(stats.attempts > 0 ? "正答率 \(stats.accuracy)%・苦手 \(stats.weak)問" : "未回答")
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                        Spacer(minLength: 0)
                        HStack {
                            Text("10問ずつ選ぶ")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Palette.navy)
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
                }
                .buttonStyle(.plain)
                .gridCellColumns(domain.id == "technology" ? 2 : 1)
            }
        }
    }

    private var officialExamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("IPA公式公開問題・年度別100問")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            if QuestionStore.availableOfficialYears.isEmpty {
                Text("公式公開問題の原文・正答・図表を照合中です。監査前の問題は公開しません。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            } else {
                ForEach(QuestionStore.availableOfficialYears, id: \.self) { year in
                    let questions = QuestionStore.officialExam(year: year, premium: premium.isPremium)
                    if !premium.isPremium && year != QuestionStore.freeYear {
                        Button { showSettings = true } label: {
                            HStack {
                                Text(verbatim: "\(year)年度").font(.subheadline.bold()).foregroundStyle(Palette.ink)
                                Spacer()
                                Text("Premium・100問").font(.caption).foregroundStyle(Palette.sub)
                                Image(systemName: "lock.fill")
                            }
                        }
                        .buttonStyle(.plain)
                    } else if questions.count == 100 {
                        NavigationLink(value: StudyRoute.quiz(title: "\(year)年度 公式公開問題", questions: questions)) {
                            HStack {
                                Text(verbatim: "\(year)年度").font(.subheadline.bold()).foregroundStyle(Palette.ink)
                                Spacer()
                                Text("100問").font(.caption).foregroundStyle(Palette.sub)
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(verbatim: "\(year)年度：照合未完了（\(questions.count)/100問）")
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                    }
                }
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
    }

    private var sourceNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("公式公開問題", systemImage: "checkmark.shield")
                .font(.subheadline.bold())
                .foregroundStyle(Palette.ink)
            Text("2026年度100問は無料。Premiumでは2022〜2026年度の全500問を学習できます。")
                .font(.caption)
                .foregroundStyle(Palette.sub)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
    }
}

private struct DomainSetView: View {
    let domain: StudyDomain

    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @State private var showSettings = false
    private var questions: [StudyQuestion] { QuestionStore.questions(domain: domain.id, premium: premium.isPremium) }
    private var sets: [QuestionSet] {
        stride(from: 0, to: questions.count, by: 10).enumerated().map { offset, start in
            QuestionSet(id: offset + 1, start: start + 1, end: min(start + 10, questions.count))
        }
    }

    var body: some View {
        let stats = records.domainStats(domain: domain.id, premium: premium.isPremium)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(domain.title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text("全\(questions.count)問を10問ずつのセットに分割")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
                Text(stats.attempts > 0 ? "回答済み \(stats.answered)/\(stats.total)問・正答率 \(stats.accuracy)%・苦手 \(stats.weak)問" : "回答済み \(stats.answered)/\(stats.total)問・未回答")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
                domainWeakReviewCard(stats: stats)

                ForEach(sets) { set in
                    let slice = Array(questions[(set.start - 1)..<set.end])
                    NavigationLink(value: StudyRoute.quiz(title: "\(domain.title)・\(set.title)", questions: slice)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(set.title).font(.headline).foregroundStyle(Palette.ink)
                                Text("\(set.subtitle)・回答済み \(records.answeredCount(for: slice))/\(slice.count)問")
                                    .font(.caption)
                                    .foregroundStyle(Palette.sub)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.navy)
                        }
                        .padding(16)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(domain.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showSettings) { PremiumSettingsView() }
    }

    private func domainWeakReviewCard(stats: StudyRecordStore.DomainStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("この分野の苦手だけ復習")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("苦手 \(stats.weak)問")
                    .font(.caption.bold())
                    .foregroundStyle(Palette.navy)
            }
            if stats.weak == 0 {
                Text("この分野の苦手はありません。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sub)
            } else if premium.isPremium {
                NavigationLink(value: StudyRoute.quiz(title: "\(domain.title)・苦手復習", questions: records.weakQuestions(domain: domain.id))) {
                    Text("苦手だけ復習する　\(stats.weak)問")
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            } else {
                Button { showSettings = true } label: {
                    HStack {
                        Text("苦手復習はPremiumで利用できます")
                        Spacer()
                        Image(systemName: "lock.fill")
                    }
                    .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
    }
}

private struct QuizView: View {
    let title: String
    let questions: [StudyQuestion]
    let isMock: Bool
    var path: Binding<NavigationPath>

    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var records: StudyRecordStore
    @State private var showSettings = false
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var correctCount = 0
    @State private var finished = false
    @State private var imageScale: CGFloat = 1
    @State private var answers: [String: Int] = [:]
    @State private var remainingSeconds = 7200
    @State private var showFinishConfirm = false
    @State private var showMockReview = false

    private static let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canStudy: Bool {
        premium.isPremium || questions.allSatisfy { $0.year == QuestionStore.freeYear }
    }

    private var current: StudyQuestion? {
        guard questions.indices.contains(index) else { return nil }
        return questions[index]
    }

    private var remainingTimeText: String {
        "\(remainingSeconds / 60):\(String(format: "%02d", remainingSeconds % 60))"
    }

    var body: some View {
        VStack(spacing: 0) {
            if canStudy, !finished, let q = current {
                quizHeader(q)
            }
            ScrollView {
                if !canStudy {
                    VStack(spacing: 16) {
                        Label("Premiumが必要です", systemImage: "lock.fill").font(.headline).foregroundStyle(Palette.ink)
                        Text("2026年度100問は無料で学習できます。")
                            .foregroundStyle(Palette.ink)
                        Button("購入・復元へ") { showSettings = true }
                    }.padding(24)
                } else if finished {
                    resultView
                } else if let q = current {
                    questionBody(q)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(Palette.navy)
                        Text("問題がありません")
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        Text("問題データの読み込み状態を確認してください。")
                            .font(.subheadline)
                            .foregroundStyle(Palette.sub)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onReceive(Self.timer) { _ in tick() }
        .alert("模試を終了して採点しますか？", isPresented: $showFinishConfirm) {
            Button("採点する", role: .destructive) { finishMock() }
            Button("続ける", role: .cancel) { }
        }
        .sheet(isPresented: $showSettings) { PremiumSettingsView() }
        .navigationDestination(isPresented: $showMockReview) {
            MockReviewView(title: title, questions: questions, answers: answers)
        }
    }

    private func quizHeader(_ q: StudyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(q.category).font(.caption.bold()).foregroundStyle(Palette.navy)
                Spacer()
                if isMock {
                    Text("残り \(remainingTimeText)")
                        .font(.caption.bold())
                        .foregroundStyle(remainingSeconds <= 600 ? .red : Palette.navy)
                }
                Text("\(index + 1) / \(questions.count)").font(.caption).foregroundStyle(Palette.sub)
            }
            ProgressView(value: Double(index), total: Double(max(questions.count, 1)))
                .tint(Palette.navy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Palette.paper)
    }

    private func questionBody(_ q: StudyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            QuestionTextView(text: q.question, font: .system(size: 19, weight: .bold, design: .serif))
            if q.originType == "ipa_published_verbatim" {
                Text(q.primaryEvidence)
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
            } else {
                Text("独自演習（IPA公式公開問題ではありません）")
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
            }
            if q.modified || q.representationChanged {
                Text("改変あり：\(q.modificationNote ?? "表示形式を変更")")
                    .font(.caption)
                    .foregroundStyle(Palette.ink)
            }
            if let asset = q.sourceFigureName, !asset.isEmpty {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(imageScale)
                    .gesture(MagnificationGesture().onChanged { value in
                        imageScale = min(max(value, 1), 4)
                    })
                    .onTapGesture(count: 2) { imageScale = 1 }
                    .accessibilityLabel(q.sourceFigureAlt ?? "問題の公式図表")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            ForEach(q.choices.indices, id: \.self) { choiceIndex in
                Button {
                    if isMock {
                        mockAnswer(choiceIndex, question: q)
                    } else {
                        answer(choiceIndex, question: q)
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(["ア", "イ", "ウ", "エ"][choiceIndex]).font(.headline)
                        Text(q.choices[choiceIndex]).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(15)
                    .foregroundStyle(choiceForeground(choiceIndex, q: q))
                    .background(choiceBackground(choiceIndex, q: q), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(choiceBorder(choiceIndex, q: q), lineWidth: 1.4))
                }
                .buttonStyle(.plain)
                .disabled(!isMock && selected != nil)
            }

            if !isMock && selected == nil {
                Button("わからない") { giveUp(question: q) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }

            if isMock {
                mockNavigation
            } else if selected != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected == q.correctIndex ? "正解" : "不正解")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text(q.explanation)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                    if let detail = q.detailedExplanation, !detail.isEmpty {
                        DisclosureGroup("詳しい解説を見る") {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.navy)
                    }
                    Text(q.primaryEvidence)
                        .font(.caption)
                        .foregroundStyle(Palette.sub)
                    Button(index + 1 == questions.count ? "結果を見る" : "次の問題") {
                        advance()
                    }
                    .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
                }
                .padding(16)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line))
            }
        }
        .padding(18)
    }

    private var mockNavigation: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if index > 0 {
                    Button("前へ") {
                        index -= 1
                        imageScale = 1
                    }
                    .buttonStyle(.bordered)
                }
                if index + 1 == questions.count {
                    Button("終了して採点") { showFinishConfirm = true }
                        .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
                } else {
                    Button("次へ") {
                        index += 1
                        imageScale = 1
                    }
                    .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
                }
            }
            Button("模試を終了して採点する") { showFinishConfirm = true }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
    }

    private var resultView: some View {
        let weak = records.weakQuestions()
        return VStack(spacing: 16) {
            Image(systemName: isMock ? "timer" : "flag.checkered").font(.system(size: 42)).foregroundStyle(Palette.navy)
            Text(isMock ? "模試結果" : "セット完了").font(.system(size: 28, weight: .bold, design: .serif)).foregroundStyle(Palette.ink)
            Text("\(questions.count)問中 \(correctCount)問正解")
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
            Text("正答率 \(questions.isEmpty ? 0 : Int(Double(correctCount) / Double(questions.count) * 100))%")
                .foregroundStyle(Palette.sub)
            if isMock {
                Text("※ 公式IRT評価点・合否判定ではありません。")
                    .font(.caption)
                    .foregroundStyle(Palette.sub)
                    .multilineTextAlignment(.center)
                domainAccuracyRows
                Button("全問の正答・解説を見る") { showMockReview = true }
                    .buttonStyle(.bordered)
            }
            if !weak.isEmpty {
                NavigationLink(value: StudyRoute.quiz(title: "苦手復習", questions: weak)) {
                    Text("苦手だけ復習する　\(weak.count)問")
                }
                .buttonStyle(PrimaryButtonStyle(background: Palette.navy))
            }
            Button("ホームへ戻る") { path.wrappedValue = NavigationPath() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line))
        .padding(18)
    }

    private var domainAccuracyRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([("strategy", "ストラテジ系"), ("management", "マネジメント系"), ("technology", "テクノロジ系")], id: \.0) { domain, label in
                let qs = questions.filter { $0.domain == domain }
                let ok = qs.filter { answers[$0.id] == $0.correctIndex }.count
                if !qs.isEmpty {
                    HStack {
                        Text(label).font(.subheadline).foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(ok)/\(qs.count)問・\(Int(Double(ok) / Double(qs.count) * 100))%")
                            .font(.subheadline).foregroundStyle(Palette.sub)
                    }
                }
            }
        }
    }

    private func tick() {
        guard isMock, !finished, canStudy else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            if remainingSeconds == 0 { finishMock() }
        }
    }

    private func answer(_ choice: Int, question: StudyQuestion) {
        guard canStudy, selected == nil else { return }
        selected = choice
        let correct = choice == question.correctIndex
        if correct { correctCount += 1 }
        records.record(questionId: question.id, correct: correct)
    }

    /// 「わからない」は不正解として記録し、苦手に登録して解説を表示する。
    private func giveUp(question: StudyQuestion) {
        guard canStudy, selected == nil else { return }
        records.record(questionId: question.id, correct: false)
        selected = -1
    }

    private func mockAnswer(_ choice: Int, question: StudyQuestion) {
        guard canStudy else { return }
        answers[question.id] = choice
    }

    private func advance() {
        guard canStudy else { return }
        if index + 1 >= questions.count {
            records.addSession(title: title, score: correctCount, total: questions.count)
            finished = true
        } else {
            index += 1
            selected = nil
            imageScale = 1
        }
    }

    private func finishMock() {
        guard !finished else { return }
        var score = 0
        for q in questions {
            if let chosen = answers[q.id] {
                let correct = chosen == q.correctIndex
                if correct { score += 1 }
                records.record(questionId: q.id, correct: correct)
            }
        }
        correctCount = score
        records.addSession(title: title, score: score, total: questions.count)
        finished = true
    }

    private func choiceBackground(_ choice: Int, q: StudyQuestion) -> Color {
        if isMock {
            return answers[q.id] == choice ? Palette.navy.opacity(0.12) : Palette.card
        }
        guard let selected else { return Palette.card }
        if choice == q.correctIndex { return Color.green.opacity(0.13) }
        if choice == selected { return Color.red.opacity(0.10) }
        return Palette.card
    }

    private func choiceBorder(_ choice: Int, q: StudyQuestion) -> Color {
        if isMock {
            return answers[q.id] == choice ? Palette.navy : Palette.line
        }
        guard let selected else { return Palette.line }
        if choice == q.correctIndex { return .green }
        if choice == selected { return .red }
        return Palette.line
    }

    private func choiceForeground(_ choice: Int, q: StudyQuestion) -> Color {
        if isMock { return Palette.ink }
        guard let selected else { return Palette.ink }
        if choice == q.correctIndex { return .green }
        if choice == selected { return .red }
        return Palette.ink
    }
}

private struct MockReviewView: View {
    let title: String
    let questions: [StudyQuestion]
    let answers: [String: Int]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(questions) { q in
                    let mine = answers[q.id]
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(verbatim: "\(q.year)年度 問\(q.questionNumber)")
                                .font(.caption.bold())
                                .foregroundStyle(Palette.navy)
                            Spacer()
                            Text(mine == nil ? "未回答" : mine == q.correctIndex ? "正解" : "不正解")
                                .font(.caption.bold())
                                .foregroundStyle(mine == nil ? Palette.sub : mine == q.correctIndex ? .green : .red)
                        }
                        QuestionTextView(text: q.question, font: .subheadline)
                        ForEach(q.choices.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 6) {
                                Text(["ア", "イ", "ウ", "エ"][i]).font(.caption.bold())
                                Text(q.choices[i]).font(.caption)
                                if i == q.correctIndex {
                                    Text("正答").font(.caption.bold()).foregroundStyle(.green)
                                }
                                if mine == i && mine != q.correctIndex {
                                    Text("あなたの回答").font(.caption.bold()).foregroundStyle(.red)
                                }
                            }
                            .foregroundStyle(Palette.ink)
                        }
                        Text(q.explanation)
                            .font(.caption)
                            .foregroundStyle(Palette.ink)
                        if let detail = q.detailedExplanation, !detail.isEmpty {
                            DisclosureGroup("詳しい解説を見る") {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(Palette.sub)
                            }
                            .font(.caption.bold())
                            .foregroundStyle(Palette.navy)
                        }
                        Text(q.primaryEvidence)
                            .font(.caption)
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(14)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))
                }
            }
            .padding(18)
        }
        .background(Palette.paper.ignoresSafeArea())
        .navigationTitle("\(title)・振り返り")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - 問題文の表描画
// 問題文に含まれるパイプ記号の表を SwiftUI の表として描画する。
// 対応する形式：(1) 見出し行＋区切り行（|---|---|）のある Markdown 表、
// (2) 「選択肢 | …」や「売上高 | …」のように「 | 」を含む行が2行以上続くブロック。
// どちらにも当てはまらない行は従来どおりテキスト表示（フォールバック）。

private enum QuestionTextSegment {
    case text(String)
    case table(MarkdownTable)
}

private struct MarkdownTable {
    let headers: [String]
    let alignments: [Alignment]
    let rows: [[String]]
}

private enum QuestionTextParser {
    static func segments(_ text: String) -> [QuestionTextSegment] {
        let lines = text.components(separatedBy: "\n")
        var result: [QuestionTextSegment] = []
        var buffer: [String] = []
        var i = 0
        func flush() {
            if !buffer.isEmpty {
                result.append(.text(buffer.joined(separator: "\n")))
                buffer.removeAll()
            }
        }
        while i < lines.count {
            if let table = parseMarkdownTable(lines, at: i) {
                flush()
                result.append(.table(table.value))
                i = table.nextIndex
                continue
            }
            if let table = parsePipeBlock(lines, at: i) {
                flush()
                result.append(.table(table.value))
                i = table.nextIndex
                continue
            }
            buffer.append(lines[i])
            i += 1
        }
        flush()
        return result
    }

    private static func parseMarkdownTable(_ lines: [String], at i: Int) -> (value: MarkdownTable, nextIndex: Int)? {
        guard i + 1 < lines.count,
              lines[i].contains("|"),
              isSeparatorRow(lines[i + 1]) else { return nil }
        let headers = splitCells(lines[i])
        guard !headers.isEmpty else { return nil }
        let alignments = parseAlignments(lines[i + 1], count: headers.count)
        var rows: [[String]] = []
        var j = i + 2
        while j < lines.count && lines[j].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
            rows.append(splitCells(lines[j]))
            j += 1
        }
        guard !rows.isEmpty else { return nil }
        let width = max(headers.count, rows.map(\.count).max() ?? 0)
        return (
            MarkdownTable(
                headers: normalize(headers, to: width),
                alignments: alignments + Array(repeating: Alignment.leading, count: max(0, width - alignments.count)),
                rows: rows.map { normalize($0, to: width) }
            ),
            j
        )
    }

    private static func parsePipeBlock(_ lines: [String], at i: Int) -> (value: MarkdownTable, nextIndex: Int)? {
        var block: [String] = []
        var j = i
        while j < lines.count {
            let line = lines[j]
            guard line.contains(" | "),
                  !line.trimmingCharacters(in: .whitespaces).hasSuffix("。"),
                  !isSeparatorRow(line) else { break }
            block.append(line)
            j += 1
        }
        guard block.count >= 2 else { return nil }
        let cells = block.map(splitCells)
        let width = cells.map(\.count).max() ?? 0
        guard width >= 2 else { return nil }
        return (
            MarkdownTable(
                headers: normalize(cells[0], to: width),
                alignments: Array(repeating: Alignment.leading, count: width),
                rows: Array(cells.dropFirst().map { normalize($0, to: width) })
            ),
            j
        )
    }

    private static func splitCells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") { text.removeLast() }
        return text.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        let cells = splitCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let core = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !core.isEmpty && core.allSatisfy { $0 == "-" }
        }
    }

    private static func parseAlignments(_ line: String, count: Int) -> [Alignment] {
        let cells = splitCells(line)
        return (0..<count).map { index in
            guard index < cells.count else { return Alignment.leading }
            let cell = cells[index]
            if cell.hasPrefix(":") && cell.hasSuffix(":") && cell.count > 1 { return Alignment.center }
            if cell.hasSuffix(":") { return Alignment.trailing }
            return Alignment.leading
        }
    }

    private static func normalize(_ cells: [String], to width: Int) -> [String] {
        if cells.count >= width { return Array(cells.prefix(width)) }
        return cells + Array(repeating: "", count: width - cells.count)
    }
}

private struct QuestionTextView: View {
    let text: String
    let font: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(QuestionTextParser.segments(text).enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let value):
                    if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(value)
                            .font(font)
                            .foregroundStyle(Palette.ink)
                            .lineSpacing(5)
                    }
                case .table(let table):
                    MarkdownTableView(table: table)
                }
            }
        }
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownTable

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(table.headers.indices, id: \.self) { index in
                    Text(table.headers[index])
                        .font(.caption.bold())
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: table.alignments[index])
                        .padding(6)
                        .background(Palette.navy.opacity(0.08))
                        .border(Palette.line, width: 0.5)
                }
            }
            ForEach(table.rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(table.rows[row].indices, id: \.self) { index in
                        Text(table.rows[row][index])
                            .font(.caption)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, alignment: table.alignments[index])
                            .padding(6)
                            .border(Palette.line, width: 0.5)
                    }
                }
            }
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1), in: RoundedRectangle(cornerRadius: 14))
    }
}
