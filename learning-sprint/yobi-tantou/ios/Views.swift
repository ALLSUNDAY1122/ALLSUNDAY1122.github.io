import SwiftUI
import UniformTypeIdentifiers

private enum MainTab: String, CaseIterable {
    case home = "ホーム"
    case mock = "模試"
    case record = "記録"
    case settings = "設定"

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
                        case .home:
                            HomeView(onStart: attemptStart, onResume: attemptResume, onOpenMock: { tab = .mock })
                        case .mock:
                            MockView(onStart: attemptStart)
                        case .record:
                            RecordView(onStart: attemptStart)
                        case .settings:
                            SettingsView(showPremium: $showPremium)
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
        switch model.state.selectedTextSize {
        case "small": return .small
        case "large": return .xxLarge
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(SprintTheme.vermilion)
            Text("教材データを読み込めませんでした")
                .font(SprintTheme.serif(22, weight: .bold))
            Text(message)
                .font(.footnote)
                .foregroundStyle(SprintTheme.ink2)
                .multilineTextAlignment(.center)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("学びスプリント").font(.caption.bold()).foregroundStyle(SprintTheme.indigo)
                    Text("司法試験予備試験・短答式")
                        .font(SprintTheme.serif(27, weight: .bold))
                    Text("今日も1問、力に変える。").foregroundStyle(SprintTheme.ink2)
                }
                .padding(.top, 18)

                if model.isPreviewBank {
                    Label("開発プレビュー問題のみ。正式3回分は権利・正答監査PASS後に解放します。", systemImage: "hammer.fill")
                        .font(.caption.bold())
                        .foregroundStyle(SprintTheme.vermilion)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SprintTheme.vermilionSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let examDate = model.state.examDate { ExamCountdown(examDate: examDate) }
                ProgressCard()

                if model.state.resume != nil {
                    Button(action: onResume) {
                        Label("続きから再開", systemImage: "arrow.uturn.forward.circle.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button { onStart(.daily) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.isPreviewBank ? "8問UIプレビュー" : "今日のスプリント").font(.headline)
                            Text("標準 \(model.state.dailyGoal)問").font(.caption).opacity(0.85)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button { onStart(.weak) } label: {
                    Label("苦手をつぶす　\(model.weakCount)問", systemImage: "scope")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(action: onOpenMock) {
                    Label("模擬試験", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("分野から解く")
                    .font(SprintTheme.serif(20, weight: .bold))
                    .padding(.top, 4)

                LazyVStack(spacing: 10) {
                    ForEach(model.subjects(), id: \.self) { subject in
                        let count = model.questionCount(subject: subject)
                        Button { onStart(.subject(subject)) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subject).font(.system(size: 16, weight: .bold)).foregroundStyle(SprintTheme.ink)
                                    Text(count == 0 ? "問題監査待ち" : "\(count)問")
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
                        .disabled(count == 0)
                    }
                }

                HStack(spacing: 10) {
                    StatTile(value: "\(model.state.totalAnswered)", label: "解答")
                    StatTile(value: "\(Int(model.overallAccuracy * 100))%", label: "正答率")
                    StatTile(value: "\(model.unknownCount)", label: "わからない")
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
                    Circle()
                        .trim(from: 0, to: min(1, Double(model.todayAnswered) / Double(max(model.state.dailyGoal, 1))))
                        .stroke(SprintTheme.vermilion, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(model.todayAnswered)").font(SprintTheme.serif(22, weight: .bold))
                        Text("/ \(model.state.dailyGoal)").font(.caption).foregroundStyle(SprintTheme.ink3)
                    }
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 5) {
                    Text("今日の学習").font(.headline)
                    Text(model.todayAnswered >= model.state.dailyGoal ? "今日の目標を達成しました。" : "あと\(max(0, model.state.dailyGoal - model.todayAnswered))問で今日の目標です。")
                        .font(.subheadline)
                        .foregroundStyle(SprintTheme.ink2)
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
        let remaining = max(0, model.questions.filter(\.releaseEligible).count - model.state.attempts.filter { $0.value.answered > 0 }.count)
        let pace = days > 0 ? Double(remaining) / Double(days) : Double(remaining)
        PaperCard {
            HStack {
                VStack(alignment: .leading) {
                    Text("試験まで").font(.caption.bold()).foregroundStyle(SprintTheme.ink3)
                    Text("あと \(days) 日").font(SprintTheme.serif(26, weight: .bold))
                }
                Spacer()
                Text("必要ペース\n1日 \(String(format: "%.1f", pace))問")
                    .font(.caption.bold())
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(SprintTheme.indigo)
            }
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(SprintTheme.serif(20, weight: .bold))
            Text(label).font(.caption).foregroundStyle(SprintTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(SprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(SprintTheme.line))
    }
}

private struct MockView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreKitManager
    let onStart: (SessionDescriptor) -> Void

    private var releasedYears: [Int] {
        Array(Set(model.questions.compactMap { $0.releaseEligible ? $0.examYear : nil })).sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("模擬試験")
                    .font(SprintTheme.serif(28, weight: .bold))
                    .padding(.top, 18)
                Text("R6・R7は法務省一次資料から年度構成・正答・配点・順不同・部分点まで確認済みです。問題本文は権利・教材監査を通過したものだけを解放します。")
                    .foregroundStyle(SprintTheme.ink2)

                if !model.officialScoringYears.isEmpty {
                    Text("確認済みの公式採点構造")
                        .font(SprintTheme.serif(19, weight: .bold))
                        .padding(.top, 2)

                    ForEach(model.officialScoringYears, id: \.self) { year in
                        if let scoring = model.officialScoring(year: year) {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text("令和\(year - 2018)年")
                                            .font(SprintTheme.serif(18, weight: .bold))
                                        Spacer()
                                        Label("採点確認済み", systemImage: "checkmark.seal.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(SprintTheme.green)
                                    }
                                    Text("法律基本科目 \(scoring.legal.questionCount)問・\(scoring.legal.maxPoints)点")
                                        .font(.subheadline)
                                    Text("一般教養 \(scoring.generalEducation.offered)題から\(scoring.generalEducation.select)題選択・\(scoring.generalEducation.maxPoints)点")
                                        .font(.subheadline)
                                    HStack {
                                        Text("満点 \(scoring.totalMaxPoints)点")
                                        Spacer()
                                        Text("公式合格点 \(scoring.officialPassScore)点")
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(SprintTheme.indigo)
                                }
                            }
                        }
                    }
                }

                if releasedYears.isEmpty {
                    PaperCard {
                        Label("採点構造は確認済みです。正式教材問題の権利・内容監査が完了するまで、年度模試の開始だけをロックしています。", systemImage: "lock.doc")
                            .foregroundStyle(SprintTheme.ink2)
                    }
                } else {
                    Text("受験できる年度")
                        .font(SprintTheme.serif(19, weight: .bold))
                        .padding(.top, 2)
                    ForEach(releasedYears, id: \.self) { year in
                        let summary = model.mockSelectionSummary(year: year)
                        Button { onStart(.mock(year)) } label: {
                            PaperCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("令和\(year - 2018)年").font(SprintTheme.serif(18, weight: .bold)).foregroundStyle(SprintTheme.ink)
                                        Text("採点対象 \(summary.totalScoredQuestions)問")
                                            .font(.caption).foregroundStyle(SprintTheme.ink3)
                                        if summary.generalEducationAvailable > summary.generalEducationSelected {
                                            Text("一般教養 \(summary.generalEducationAvailable)題から\(summary.generalEducationSelected)題を抽出")
                                                .font(.caption2).foregroundStyle(SprintTheme.ink3)
                                        }
                                    }
                                    Spacer()
                                    if !store.isPremium { Image(systemName: "lock.fill").foregroundStyle(SprintTheme.gold) }
                                    Image(systemName: "chevron.right").foregroundStyle(SprintTheme.ink3)
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct RecordView: View {
    @EnvironmentObject private var model: AppModel
    let onStart: (SessionDescriptor) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("学習記録").font(SprintTheme.serif(28, weight: .bold)).padding(.top, 18)
                PaperCard {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(SprintTheme.indigoSoft, lineWidth: 12)
                            Circle()
                                .trim(from: 0, to: model.overallAccuracy)
                                .stroke(SprintTheme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(model.overallAccuracy * 100))%")
                                .font(SprintTheme.serif(22, weight: .bold))
                        }
                        .frame(width: 92, height: 92)
                        VStack(alignment: .leading) {
                            Text("全体正答率").font(.headline)
                            Text("\(model.state.totalCorrect) / \(model.state.totalAnswered) 正解")
                                .foregroundStyle(SprintTheme.ink2)
                        }
                        Spacer()
                    }
                }

                Text("分野別").font(.headline)
                ForEach(model.subjects(), id: \.self) { subject in
                    let accuracy = model.subjectAccuracy(subject)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(subject).font(.caption.bold())
                            Spacer()
                            Text("\(Int(accuracy * 100))%").font(.caption.monospacedDigit())
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(SprintTheme.indigoSoft)
                                Capsule().fill(SprintTheme.indigo).frame(width: geometry.size.width * accuracy)
                            }
                        }
                        .frame(height: 8)
                    }
                }

                Text("5週間").font(.headline).padding(.top, 4)
                HeatmapView()
                Button { onStart(.weak) } label: {
                    Label("苦手 \(model.weakCount)問を復習", systemImage: "scope")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.weakCount == 0)

                PaperCard {
                    HStack {
                        Label("わからない記録", systemImage: "questionmark.circle")
                        Spacer()
                        Text("\(model.unknownCount)問").font(.headline)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
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
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument = BackupDocument()
    @State private var message: String?
    @State private var examDateEnabled = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("設定").font(SprintTheme.serif(28, weight: .bold)).padding(.top, 18)

                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1日の目標").font(.headline)
                        Picker("1日の目標", selection: Binding(get: { model.state.dailyGoal }, set: model.setDailyGoal)) {
                            Text("4問").tag(4)
                            Text("8問").tag(8)
                            Text("16問").tag(16)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("文字サイズ").font(.headline)
                        Picker("文字サイズ", selection: Binding(get: { model.state.selectedTextSize }, set: model.setTextSize)) {
                            Text("小").tag("small")
                            Text("標準").tag("medium")
                            Text("大").tag("large")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("試験日を設定", isOn: Binding(
                            get: { model.state.examDate != nil },
                            set: { enabled in model.setExamDate(enabled ? (model.state.examDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date())!) : nil) }
                        ))
                        if let date = model.state.examDate {
                            DatePicker("試験日", selection: Binding(get: { date }, set: { model.setExamDate($0) }), displayedComponents: .date)
                        }
                    }
                }

                PaperCard {
                    VStack(spacing: 10) {
                        Button {
                            do {
                                exportDocument = BackupDocument(data: try model.backupData())
                                showExporter = true
                            } catch {
                                message = error.localizedDescription
                            }
                        } label: { Label("学習データを書き出す", systemImage: "square.and.arrow.up") }
                            .buttonStyle(SecondaryButtonStyle())

                        Button { showImporter = true } label: {
                            Label("学習データを読み込む", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                PaperCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(store.isPremium ? "プレミアム有効" : "プレミアム")
                                .font(.headline)
                            Spacer()
                            if store.isPremium { Image(systemName: "checkmark.seal.fill").foregroundStyle(SprintTheme.green) }
                        }
                        if !store.isConfigured {
                            Text("Product IDは要確認のため未設定です。値を推測していません。")
                                .font(.caption).foregroundStyle(SprintTheme.vermilion)
                        }
                        Button(store.isPremium ? "購入済み" : "プレミアムを見る") { showPremium = true }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(store.isPremium)
                    }
                }

                Button(role: .destructive) { model.resetLearningData() } label: {
                    Label("学習履歴をリセット", systemImage: "trash")
                }
                .frame(maxWidth: .infinity, minHeight: 48)

                Text("問題・解説は法務省/e-Gov等の一次資料を根拠に監査し、法令基準日と出典を問題単位で保持します。")
                    .font(.footnote)
                    .foregroundStyle(SprintTheme.ink3)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 18)
        }
        .onAppear { examDateEnabled = model.state.examDate != nil }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json, defaultFilename: "yobi-sprint-backup") { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                try model.importBackup(Data(contentsOf: url))
                message = "バックアップを読み込みました。"
            } catch {
                message = error.localizedDescription
            }
        }
        .alert("お知らせ", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

private struct QuizView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        if let question = model.currentQuestion {
            QuizQuestionView(question: question)
                .id(question.id)
        } else {
            ProgressView()
        }
    }
}

private struct QuizQuestionView: View {
    @EnvironmentObject private var model: AppModel
    let question: StudyQuestion
    @State private var selected: Set<Int> = []
    @State private var submitted = false
    @State private var wasCorrect = false
    @State private var showStamp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        model.activeSession = nil
                    } label: {
                        Label("ホーム", systemImage: "chevron.left")
                    }
                    .font(.caption.bold())
                    Spacer()
                    Text("\(model.currentIndex + 1) / \(model.sessionCount)")
                        .font(.caption.monospacedDigit().bold())
                }
                .foregroundStyle(SprintTheme.indigo)
                .padding(.top, 14)

                HStack {
                    Text(question.subject).font(.caption.bold()).foregroundStyle(SprintTheme.indigo)
                    Text(question.topic).font(.caption).foregroundStyle(SprintTheme.ink3)
                    Spacer()
                    Button {
                        model.toggleUnknown()
                    } label: {
                        Image(systemName: model.isUnknown(question.id) ? "questionmark.circle.fill" : "questionmark.circle")
                    }
                    .accessibilityLabel("わからない記録")
                }

                ZStack {
                    PaperCard {
                        Text(question.stem)
                            .font(SprintTheme.serif(19, weight: .medium))
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if submitted {
                        Text(wasCorrect ? "○" : "×")
                            .font(.system(size: 96, weight: .thin, design: .rounded))
                            .foregroundStyle(SprintTheme.vermilion.opacity(0.82))
                            .rotationEffect(.degrees(wasCorrect ? -8 : 6))
                            .scaleEffect(showStamp ? 1 : 1.8)
                            .opacity(showStamp ? 1 : 0)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            guard !submitted else { return }
                            if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .frame(width: 28, height: 28)
                                    .background(selected.contains(index) ? SprintTheme.indigo : SprintTheme.indigoSoft)
                                    .foregroundStyle(selected.contains(index) ? .white : SprintTheme.indigo)
                                    .clipShape(Circle())
                                Text(choice)
                                    .foregroundStyle(SprintTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(14)
                            .background(SprintTheme.card)
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(selected.contains(index) ? SprintTheme.indigo : SprintTheme.line, lineWidth: selected.contains(index) ? 2 : 1))
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }

                if submitted {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(wasCorrect ? "正解" : "不正解")
                            .font(.headline)
                            .foregroundStyle(wasCorrect ? SprintTheme.green : SprintTheme.vermilion)
                        Text(question.explanation)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("ここだけ覚える").font(.caption.bold()).foregroundStyle(SprintTheme.gold)
                            Text(question.memory).font(SprintTheme.serif(16, weight: .medium))
                        }
                        .padding(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SprintTheme.memory)
                        .overlay(alignment: .leading) { Rectangle().fill(SprintTheme.gold).frame(width: 4) }

                        if let url = URL(string: question.sourceURL) {
                            Link(destination: url) {
                                Label(question.sourceTitle, systemImage: "link")
                                    .font(.caption.bold())
                            }
                        }
                        Text("根拠確認: \(question.evidenceCheckedDate)" + (question.lawBasisDate.map { " / 法令基準: \($0)" } ?? ""))
                            .font(.caption2)
                            .foregroundStyle(SprintTheme.ink3)
                    }
                    .padding(15)
                    .background(SprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(SprintTheme.line))

                    Button {
                        model.answer(selectedIndices: selected)
                    } label: {
                        Text(model.currentIndex + 1 >= model.sessionCount ? "結果を見る" : "次の問題へ")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button {
                        wasCorrect = selected == Set(question.correctIndices)
                        submitted = true
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { showStamp = true }
                    } label: {
                        Text("回答する")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selected.isEmpty)
                    .opacity(selected.isEmpty ? 0.45 : 1)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
        }
    }
}

private struct ResultView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        if let result = model.lastResult {
            VStack(spacing: 18) {
                Spacer()
                Text(result.title).font(.caption.bold()).foregroundStyle(SprintTheme.indigo)
                Text("\(result.correct) / \(result.answered)")
                    .font(SprintTheme.serif(58, weight: .bold))
                Text(result.correct == result.answered ? "全問正解。知識がつながっています。" : "間違えた問題は苦手として自動記録しました。")
                    .font(SprintTheme.serif(19, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SprintTheme.ink2)
                Button("ホームへ") { model.dismissResult() }
                    .buttonStyle(PrimaryButtonStyle())
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
    }
}

private struct PremiumSheet: View {
    @EnvironmentObject private var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("学びスプリント Premium")
                    .font(SprintTheme.serif(26, weight: .bold))
                Text("分野別演習・模試・苦手復習などを解放します。正式な価格とProduct IDはApp Store Connect確定後に反映します。")
                    .foregroundStyle(SprintTheme.ink2)
                if let product = store.product {
                    Text(product.displayPrice).font(.title2.bold())
                    Button("購入") { Task { await store.purchase() } }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Label("IAP Product ID：要確認", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(SprintTheme.vermilion)
                }
                Button("購入を復元") { Task { await store.restore() } }
                    .buttonStyle(SecondaryButtonStyle())
                if let status = store.statusMessage {
                    Text(status).font(.footnote).foregroundStyle(SprintTheme.ink3)
                }
                Spacer()
            }
            .padding(22)
            .background(SprintTheme.paper)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}
