import SwiftUI
import UniformTypeIdentifiers

private enum MainTab: String, CaseIterable {
    case home = "ホーム", mock = "模試", record = "記録", settings = "設定"
    var icon: String {
        switch self {
        case .home: return "house"
        case .mock: return "doc.text"
        case .record: return "chart.bar"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreKitManager
    @State private var tab: MainTab = .home
    @State private var showPremium = false

    var body: some View {
        ZStack {
            PaperGridBackground()
            if let error = model.startupError {
                StartupErrorView(message: error)
            } else if model.activeSession != nil {
                QuizView()
            } else if model.lastResult != nil {
                ResultView()
            } else {
                VStack(spacing: 0) {
                    Group {
                        switch tab {
                        case .home: HomeView(onStart: attemptStart, onResume: attemptResume, onOpenMock: { tab = .mock })
                        case .mock: MockView(onStart: attemptStart)
                        case .record: RecordView(onStart: attemptStart)
                        case .settings: SettingsView(showPremium: $showPremium)
                        }
                    }
                    .frame(maxWidth: 520)
                    BottomBar(tab: $tab)
                }
                .frame(maxWidth: 520)
            }
        }
        .foregroundStyle(SprintTheme.ink)
        .dynamicTypeSize(dynamicTypeSize)
        .sheet(isPresented: $showPremium) { PremiumSheet() }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch model.selectedTextSize {
        case "small": return .small
        case "large": return .xLarge
        default: return .medium
        }
    }

    private func attemptStart(_ descriptor: SessionDescriptor) {
        if !model.start(descriptor, premium: store.isPremium) { showPremium = true }
    }

    private func attemptResume() {
        if !model.resume(premium: store.isPremium) { showPremium = true }
    }
}

private struct StartupErrorView: View {
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(SprintTheme.vermilion)
            Text("教材データを読み込めませんでした").font(SprintTheme.serif(22, weight: .bold))
            Text(message).font(.footnote).foregroundStyle(SprintTheme.ink2).multilineTextAlignment(.center)
        }
        .padding(28)
    }
}

private struct BottomBar: View {
    @Binding var tab: MainTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                        Text(item.rawValue).font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(tab == item ? SprintTheme.indigo : SprintTheme.ink3)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(tab == item ? SprintTheme.indigoSoft : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel(item.rawValue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().foregroundStyle(SprintTheme.line) }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreKitManager
    let onStart: (SessionDescriptor) -> Void
    let onResume: () -> Void
    let onOpenMock: () -> Void
    @State private var year = 2025

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学びスプリント").font(.caption.bold()).foregroundStyle(SprintTheme.indigo)
                    Text("司法書士試験・択一式").font(SprintTheme.serif(28, weight: .bold))
                    Text("今日も1問、力に変える。").foregroundStyle(SprintTheme.ink2)
                }
                .padding(.top, 18)

                if let exam = model.state.examDate { ExamCountdown(examDate: exam) }
                ProgressCard()

                if model.state.resume != nil {
                    Button(action: onResume) {
                        Label("続きから再開", systemImage: "arrow.uturn.forward.circle.fill")
                    }.buttonStyle(SecondaryButtonStyle())
                }

                Button { onStart(.daily) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("今日のスプリント").font(.headline)
                            Text("標準 \(store.isPremium ? model.state.dailyGoal : min(model.state.dailyGoal, 8)) 問").font(.caption).opacity(0.85)
                        }
                        Spacer(); Image(systemName: "arrow.right")
                    }.padding(.horizontal, 4)
                }.buttonStyle(PrimaryButtonStyle())

                Button { onStart(.weak) } label: {
                    Label("苦手をつぶす　\(model.weakCount)問", systemImage: "scope")
                }.buttonStyle(SecondaryButtonStyle())

                Button(action: onOpenMock) {
                    Label("模擬試験", systemImage: "doc.text.magnifyingglass")
                }.buttonStyle(SecondaryButtonStyle())

                Text("分野から解く").font(SprintTheme.serif(20, weight: .bold)).padding(.top, 4)
                Picker("年度", selection: $year) {
                    Text("令和5").tag(2023); Text("令和6").tag(2024); Text("令和7").tag(2025)
                }.pickerStyle(.segmented)

                LazyVStack(spacing: 10) {
                    ForEach(model.subjects(for: year), id: \.self) { subject in
                        Button { onStart(.subject(year: year, subject: subject)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subject).font(.system(size: 16, weight: .bold)).foregroundStyle(SprintTheme.ink)
                                    Text("\(model.questionCount(year: year, subject: subject))問 ・ 完答 \(model.completionCount(year: year, subject: subject))回")
                                        .font(.caption).foregroundStyle(SprintTheme.ink3)
                                }
                                Spacer()
                                if !store.isPremium { Image(systemName: "lock.fill").foregroundStyle(SprintTheme.gold) }
                                Image(systemName: "chevron.right").foregroundStyle(SprintTheme.ink3)
                            }
                            .padding(15)
                            .background(SprintTheme.card)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(SprintTheme.line))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                HStack(spacing: 10) {
                    StatTile(value: "\(model.state.totalAnswered)", label: "解答")
                    StatTile(value: "\(Int(model.overallAccuracy * 100))%", label: "正答率")
                    StatTile(value: "\(model.weakCount)", label: "苦手")
                }
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct ProgressCard: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        PaperCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(SprintTheme.indigoSoft, lineWidth: 9)
                    Circle().trim(from: 0, to: min(1, Double(model.todayAnswered) / Double(max(model.state.dailyGoal, 1))))
                        .stroke(SprintTheme.vermilion, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(model.todayAnswered)").font(SprintTheme.serif(22, weight: .bold))
                        Text("/ \(model.state.dailyGoal)").font(.caption).foregroundStyle(SprintTheme.ink3)
                    }
                }.frame(width: 82, height: 82)
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日の学習").font(.headline)
                    Text(model.todayAnswered >= model.state.dailyGoal ? "今日の目標を達成しました。" : "あと\(max(0, model.state.dailyGoal - model.todayAnswered))問で今日の目標です。")
                        .font(.subheadline).foregroundStyle(SprintTheme.ink2)
                }
                Spacer()
            }
        }
    }
}

private struct ExamCountdown: View {
    @EnvironmentObject private var model: AppModel
    let examDate: Date
    var body: some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: examDate)).day ?? 0)
        let answeredUnique = model.state.attempts.values.filter { $0.answered > 0 }.count
        let remaining = max(0, model.questions.count - answeredUnique)
        let pace = days > 0 ? Double(remaining) / Double(days) : Double(remaining)
        PaperCard {
            HStack {
                VStack(alignment: .leading) {
                    Text("試験まで").font(.caption.bold()).foregroundStyle(SprintTheme.ink3)
                    Text("あと \(days) 日").font(SprintTheme.serif(26, weight: .bold))
                }
                Spacer()
                Text("必要ペース\n1日 \(String(format: "%.1f", pace))問")
                    .font(.caption.bold()).multilineTextAlignment(.trailing).foregroundStyle(SprintTheme.indigo)
            }
        }
    }
}

private struct StatTile: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) { Text(value).font(SprintTheme.serif(20, weight: .bold)); Text(label).font(.caption).foregroundStyle(SprintTheme.ink3) }
            .frame(maxWidth: .infinity).padding(.vertical, 13).background(SprintTheme.card).clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(SprintTheme.line))
    }
}

private struct MockView: View {
    @EnvironmentObject private var store: StoreKitManager
    let onStart: (SessionDescriptor) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("模擬試験").font(SprintTheme.serif(28, weight: .bold)).padding(.top, 18)
                Text("本試験と同じ午前35問・午後35問で解きます。").foregroundStyle(SprintTheme.ink2)
                ForEach([2025, 2024, 2023], id: \.self) { year in
                    ForEach(["AM", "PM"], id: \.self) { session in
                        Button { onStart(.mock(year: year, session: session)) } label: {
                            PaperCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("令和\(year - 2018)年度 \(session == "AM" ? "午前" : "午後")").font(SprintTheme.serif(18, weight: .bold)).foregroundStyle(SprintTheme.ink)
                                        Text("35問").font(.caption).foregroundStyle(SprintTheme.ink3)
                                    }
                                    Spacer(); if !store.isPremium { Image(systemName: "lock.fill").foregroundStyle(SprintTheme.gold) }; Image(systemName: "chevron.right").foregroundStyle(SprintTheme.ink3)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 20)
            }.padding(.horizontal, 18)
        }
    }
}

private struct RecordView: View {
    @EnvironmentObject private var model: AppModel
    let onStart: (SessionDescriptor) -> Void
    private let subjects = ["憲法","民法","刑法","商法・会社法","民事訴訟法","民事保全法","民事執行法","司法書士法","供託法","不動産登記法","商業登記法"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("学習記録").font(SprintTheme.serif(28, weight: .bold)).padding(.top, 18)
                PaperCard {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(SprintTheme.indigoSoft, lineWidth: 12)
                            Circle().trim(from: 0, to: model.overallAccuracy).stroke(SprintTheme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                            Text("\(Int(model.overallAccuracy * 100))%").font(SprintTheme.serif(22, weight: .bold))
                        }.frame(width: 92, height: 92)
                        VStack(alignment: .leading) { Text("全体正答率").font(.headline); Text("\(model.state.totalCorrect) / \(model.state.totalAnswered) 正解").foregroundStyle(SprintTheme.ink2) }
                        Spacer()
                    }
                }
                Text("分野別").font(.headline)
                ForEach(subjects, id: \.self) { subject in
                    let a = model.subjectAccuracy(subject)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(subject).font(.caption.bold()); Spacer(); Text("\(Int(a * 100))%").font(.caption.monospacedDigit()) }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) { Capsule().fill(SprintTheme.indigoSoft); Capsule().fill(SprintTheme.indigo).frame(width: geo.size.width * a) }
                        }.frame(height: 8)
                    }
                }
                Text("5週間").font(.headline).padding(.top, 4)
                HeatmapView()
                Button { onStart(.weak) } label: { Label("苦手 \(model.weakCount)問を復習", systemImage: "scope") }.buttonStyle(SecondaryButtonStyle())
                Spacer(minLength: 20)
            }.padding(.horizontal, 18)
        }
    }
}

private struct HeatmapView: View {
    @EnvironmentObject private var model: AppModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(Array((0..<35).reversed()), id: \.self) { offset in
                let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                let count = model.dayStat(date).answered
                RoundedRectangle(cornerRadius: 4)
                    .fill(count == 0 ? SprintTheme.line : SprintTheme.green.opacity(min(1, 0.25 + Double(count) / 12)))
                    .frame(height: 28)
                    .accessibilityLabel("\(offset)日前 \(count)問")
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreKitManager
    @Binding var showPremium: Bool
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var resetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("設定").font(SprintTheme.serif(28, weight: .bold)).padding(.top, 18)
                settingsCard(title: "文字サイズ") {
                    Picker("文字サイズ", selection: Binding(get: { model.state.textSize }, set: { model.setTextSize($0) })) {
                        Text("小").tag("small"); Text("中").tag("medium"); Text("大").tag("large")
                    }.pickerStyle(.segmented)
                }
                settingsCard(title: "1日の目標") {
                    Picker("目標", selection: Binding(get: { model.state.dailyGoal }, set: { model.setDailyGoal($0) })) {
                        Text("4問").tag(4); Text("8問").tag(8); Text("16問").tag(16)
                    }.pickerStyle(.segmented)
                }
                settingsCard(title: "試験日") {
                    DatePicker("試験日", selection: Binding(get: { model.state.examDate ?? Date() }, set: { model.setExamDate($0) }), displayedComponents: .date)
                    if model.state.examDate != nil { Button("試験日を未設定に戻す") { model.setExamDate(nil) }.font(.footnote.bold()).foregroundStyle(SprintTheme.vermilion) }
                }
                settingsCard(title: "プレミアム") {
                    Text(store.isPremium ? "解放済み" : (store.displayPrice.isEmpty ? "価格を取得中" : "買い切り \(store.displayPrice)"))
                        .font(.headline).foregroundStyle(SprintTheme.indigo)
                    Button(store.isPremium ? "プレミアム解放済み" : "プレミアムを確認") { showPremium = true }.buttonStyle(SecondaryButtonStyle()).disabled(store.isPremium)
                    Button("購入を復元") { Task { await store.restore() } }.buttonStyle(SecondaryButtonStyle())
                }
                settingsCard(title: "学習データ") {
                    Button("JSONを書き出す") {
                        if let data = try? model.exportBackupData() { exportDocument = BackupDocument(data: data); exporting = true }
                    }.buttonStyle(SecondaryButtonStyle())
                    Button("JSONを読み込む") { importing = true }.buttonStyle(SecondaryButtonStyle())
                    if let message = model.importMessage { Text(message).font(.footnote).foregroundStyle(SprintTheme.green) }
                    Button("学習データをリセット", role: .destructive) { resetConfirm = true }.font(.footnote.bold())
                }
                settingsCard(title: "情報") {
                    Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/learning-sprint/shoshi/privacy/")!)
                    Link("サポート", destination: URL(string: "https://allsunday1122.github.io/learning-sprint/shoshi/support/")!)
                    Text("法務省公開問題をアプリ向けに整形して収録しています。法務省の公式アプリではありません。")
                        .font(.footnote).foregroundStyle(SprintTheme.ink2)
                }
                Spacer(minLength: 20)
            }.padding(.horizontal, 18)
        }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "shoshi-learning-backup") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try model.importBackupData(Data(contentsOf: url))
            } catch { model.importMessage = "読み込みに失敗しました：\(error.localizedDescription)" }
        }
        .confirmationDialog("学習履歴をリセットしますか？", isPresented: $resetConfirm, titleVisibility: .visible) {
            Button("リセット", role: .destructive) { model.resetLearningData() }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        PaperCard { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() } }
    }
}

struct QuizView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreKitManager

    var body: some View {
        if let session = model.activeSession, let question = model.currentQuestion {
            VStack(spacing: 0) {
                HStack {
                    Button { model.leaveQuizKeepingResume() } label: { Image(systemName: "house").frame(width: 44, height: 44) }.accessibilityLabel("ホームへ戻る")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.index + 1) / \(session.questionIDs.count)").font(.caption.bold())
                        Text("\(question.yearLabel)・\(question.sessionLabel)・\(question.subject)").font(.caption2).foregroundStyle(SprintTheme.ink3)
                    }
                    Spacer()
                    ProgressView(value: Double(session.index + (model.showFeedback ? 1 : 0)), total: Double(session.questionIDs.count)).frame(width: 90).tint(SprintTheme.indigo)
                }.padding(.horizontal, 14).padding(.vertical, 6).background(SprintTheme.card)
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(question.topic).font(.caption.bold()).foregroundStyle(SprintTheme.indigo)
                        Text(question.question).font(SprintTheme.serif(18)).lineSpacing(6).textSelection(.enabled)
                            .padding(16).background(SprintTheme.card).clipShape(RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(SprintTheme.line))

                        VStack(spacing: 9) {
                            ForEach(1...5, id: \.self) { choice in
                                Button { model.answer(choice) } label: {
                                    HStack { Text("\(choice)").font(.headline.monospacedDigit()); Spacer(); answerMark(choice, question: question) }
                                        .foregroundStyle(SprintTheme.ink).padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 52)
                                        .background(answerColor(choice, question: question)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(SprintTheme.line))
                                }.disabled(model.showFeedback)
                            }
                        }

                        if model.showFeedback {
                            VStack(spacing: 10) {
                                Text(model.lastWasCorrect == true ? "○" : "×")
                                    .font(.system(size: 88, weight: .bold, design: .serif))
                                    .foregroundStyle(model.lastWasCorrect == true ? SprintTheme.green : SprintTheme.vermilion)
                                    .transition(.scale.combined(with: .opacity))
                                if question.isAllCorrect { Text("公式採点：全員正答").font(.headline).foregroundStyle(SprintTheme.indigo) }
                            }.frame(maxWidth: .infinity)

                            PaperCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("解説").font(.headline)
                                    Text(question.shortExplanation).font(.subheadline).lineSpacing(4)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("ここだけ覚える").font(.caption.bold()).foregroundStyle(SprintTheme.gold)
                                        Text(question.memoryLine).font(SprintTheme.serif(16, weight: .bold))
                                    }
                                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(SprintTheme.memory)
                                    .overlay(alignment: .leading) { Rectangle().fill(SprintTheme.gold).frame(width: 4) }
                                    Text("法令基準日：\(question.lawBaseline)／\(question.currentLawStatus == "historical" ? "出題当時基準" : question.currentLawStatus)")
                                        .font(.caption).foregroundStyle(SprintTheme.ink3)
                                    if let url = URL(string: question.basisURL) { Link("一次根拠を開く", destination: url).font(.caption.bold()) }
                                }
                            }
                            Button { model.next(premium: store.isPremium) } label: {
                                Text(session.index + 1 == session.questionIDs.count ? "結果を見る" : "次の問題")
                            }.buttonStyle(PrimaryButtonStyle())
                        }
                    }.padding(18).padding(.bottom, 20)
                }
            }.background(SprintTheme.paper)
        }
    }

    @ViewBuilder private func answerMark(_ choice: Int, question: Question) -> some View {
        if model.showFeedback {
            if question.isAllCorrect || question.officialAnswerNo == choice { Image(systemName: "checkmark.circle.fill").foregroundStyle(SprintTheme.green) }
            else if model.selectedChoice == choice { Image(systemName: "xmark.circle.fill").foregroundStyle(SprintTheme.vermilion) }
        }
    }

    private func answerColor(_ choice: Int, question: Question) -> Color {
        guard model.showFeedback else { return SprintTheme.card }
        if question.isAllCorrect || question.officialAnswerNo == choice { return SprintTheme.greenSoft }
        if model.selectedChoice == choice { return SprintTheme.vermilionSoft }
        return SprintTheme.card
    }
}

struct ResultView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        if let result = model.lastResult {
            VStack(spacing: 20) {
                Spacer()
                Text("結果").font(SprintTheme.serif(24, weight: .bold))
                Text("\(result.correct) / \(result.total)").font(SprintTheme.serif(52, weight: .bold)).foregroundStyle(SprintTheme.indigo)
                Text(result.correct == result.total ? "全問正解です。" : "今日の間違いが、次の得点になります。")
                    .font(SprintTheme.serif(18, weight: .bold)).multilineTextAlignment(.center)
                Button("ホームへ") { model.closeResult() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 32)
                Spacer()
            }.padding(24).background(SprintTheme.paper)
        }
    }
}

private struct PremiumSheet: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("210問をすべて解放").font(SprintTheme.serif(26, weight: .bold))
                    Text("最初の『今日のスプリント』1回（最大8問）は無料で試せます。プレミアムは買い切りです。")
                        .foregroundStyle(SprintTheme.ink2)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("令和5〜7年度の公式択一210問", systemImage: "checkmark.circle.fill")
                        Label("年度 × 11科目の指定演習", systemImage: "checkmark.circle.fill")
                        Label("午前・午後6枠の模試", systemImage: "checkmark.circle.fill")
                        Label("苦手問題の個別復習", systemImage: "checkmark.circle.fill")
                    }.foregroundStyle(SprintTheme.green)
                    Text(store.isPremium ? "プレミアム解放済み" : (store.displayPrice.isEmpty ? "価格を取得できません" : "買い切り \(store.displayPrice)"))
                        .font(.title3.bold()).foregroundStyle(SprintTheme.indigo)
                    Button(store.isPremium ? "解放済み" : (store.displayPrice.isEmpty ? "価格を取得できません" : "\(store.displayPrice)で解放")) {
                        Task { await store.purchase(); if store.isPremium { dismiss() } }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(!store.canPurchase)
                    Button("購入を復元") { Task { await store.restore(); if store.isPremium { dismiss() } } }.buttonStyle(SecondaryButtonStyle())
                    Text("価格はApp Storeから取得します。このアプリは法務省の公式アプリではありません。")
                        .font(.footnote).foregroundStyle(SprintTheme.ink3)
                    HStack { Link("プライバシー", destination: URL(string: "https://allsunday1122.github.io/learning-sprint/shoshi/privacy/")!); Link("サポート", destination: URL(string: "https://allsunday1122.github.io/learning-sprint/shoshi/support/")!) }.font(.footnote.bold())
                }.padding(20)
            }.background(SprintTheme.paper).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}
