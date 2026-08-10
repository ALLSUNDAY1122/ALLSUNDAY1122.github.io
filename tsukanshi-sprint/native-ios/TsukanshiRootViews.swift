import SwiftUI
import UniformTypeIdentifiers
import LearningSprintCore

private enum TsukanshiTab: Hashable { case home, mock, records, settings }

struct TsukanshiRootView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    @State private var selectedTab: TsukanshiTab = .home
    @State private var showPaywall = false

    init(model: TsukanshiAppModel) {
        self.model = model
        self.purchase = model.purchaseController
    }

    var body: some View {
        Group {
            if let error = model.loadError {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                    Text("問題データを読み込めません")
                        .font(LearningSprintTheme.serif(22, weight: .bold))
                    Text(error)
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(LearningSprintTheme.ink2)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: 520)
            } else if model.content == nil {
                ZStack {
                    LearningSprintPaperBackground()
                    ProgressView("監査済み問題を読み込み中")
                }
            } else {
                TabView(selection: $selectedTab) {
                    TsukanshiHomeView(model: model, goMock: { selectedTab = .mock })
                        .tag(TsukanshiTab.home)
                        .tabItem { Label("ホーム", systemImage: "house") }
                    TsukanshiMockView(model: model)
                        .tag(TsukanshiTab.mock)
                        .tabItem { Label("模試", systemImage: "doc.text") }
                    TsukanshiRecordsView(model: model)
                        .tag(TsukanshiTab.records)
                        .tabItem { Label("記録", systemImage: "chart.bar") }
                    TsukanshiSettingsView(model: model, showPaywall: { showPaywall = true })
                        .tag(TsukanshiTab.settings)
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
                .tint(LearningSprintTheme.indigo)
                .dynamicTypeSize(dynamicType)
            }
        }
        .fullScreenCover(item: $model.activeSession) { session in
            TsukanshiStudyFlowView(model: model, session: session)
                .dynamicTypeSize(dynamicType)
        }
        .sheet(isPresented: $showPaywall) {
            TsukanshiPaywallView(purchase: purchase)
        }
        .alert("お知らせ", isPresented: Binding(
            get: { model.transientMessage != nil },
            set: { if !$0 { model.transientMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.transientMessage = nil }
        } message: {
            Text(model.transientMessage ?? "")
        }
    }

    private var dynamicType: DynamicTypeSize {
        switch model.state.textSizeStep {
        case 0: return .medium
        case 2: return .xxLarge
        default: return .large
        }
    }
}

struct TsukanshiHomeView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    let goMock: () -> Void

    init(model: TsukanshiAppModel, goMock: @escaping () -> Void) {
        self.model = model
        self.purchase = model.purchaseController
        self.goMock = goMock
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("学びスプリント")
                                .font(LearningSprintTheme.sans(12, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.vermilion)
                            Text("通関士")
                                .font(LearningSprintTheme.serif(34, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.ink)
                            Text("今日も1問、力に変える。")
                                .font(LearningSprintTheme.sans(15, weight: .medium))
                                .foregroundStyle(LearningSprintTheme.ink2)
                        }
                        countdown
                        todayCard
                        if model.state.resumeSession != nil {
                            Button(action: model.resume) {
                                Label("続きから再開", systemImage: "arrow.clockwise")
                                    .font(LearningSprintTheme.sans(15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.bordered)
                            .tint(LearningSprintTheme.indigo)
                            .accessibilityHint("中断した問題から学習を再開します")
                        }
                        actionButton(
                            title: "今日のスプリント",
                            subtitle: "\(model.state.dailyTarget)問を短く一周",
                            icon: "bolt.fill",
                            tint: LearningSprintTheme.indigo,
                            action: model.startSprint
                        )
                        actionButton(
                            title: "苦手をつぶす",
                            subtitle: model.weakCount == 0 ? "苦手はありません" : "\(model.weakCount)問・3連続正解で解除",
                            icon: "target",
                            tint: LearningSprintTheme.vermilion,
                            action: model.startWeak
                        )
                        .disabled(model.weakCount == 0)
                        .opacity(model.weakCount == 0 ? 0.55 : 1)
                        actionButton(
                            title: "模擬試験",
                            subtitle: "第59〜57回の試験構成に合わせた独自演習",
                            icon: "doc.text.fill",
                            tint: LearningSprintTheme.gold,
                            action: goMock
                        )
                        subjects
                        summary
                        if let content = model.content {
                            Text("教材 \(content.bank.studyQuestionCount)問＋申告書\(content.bank.declarationCount)セット／法令基準 \(content.bank.lawBaselineDate)／公式過去問本文は同梱していません。")
                                .font(LearningSprintTheme.sans(10))
                                .foregroundStyle(LearningSprintTheme.ink3)
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder private var countdown: some View {
        if let days = model.examDaysRemaining {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("試験まで")
                        .font(LearningSprintTheme.sans(12, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text("\(days)日")
                        .font(LearningSprintTheme.serif(31, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("必要ペース")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text("1日 \(model.requiredDailyPace ?? 0)問")
                        .font(LearningSprintTheme.sans(14, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                }
            }
            .padding(14)
            .background(LearningSprintTheme.vermilionSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var todayCard: some View {
        HStack(spacing: 16) {
            LearningSprintProgressRing(
                progress: model.todayProgress,
                label: "\(model.todayAnswered)/\(model.state.dailyTarget)"
            )
            VStack(alignment: .leading, spacing: 5) {
                Text("今日の学習")
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.ink3)
                Text(model.todayAnswered >= model.state.dailyTarget ? "今日の目標達成" : "あと\(max(0, model.state.dailyTarget - model.todayAnswered))問")
                    .font(LearningSprintTheme.serif(22, weight: .bold))
                Text("標準8問。設定で4／8／16問。")
                    .font(LearningSprintTheme.sans(12))
                    .foregroundStyle(LearningSprintTheme.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
    }

    private func actionButton(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(LearningSprintTheme.sans(16, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink)
                    Text(subtitle)
                        .font(LearningSprintTheme.sans(12))
                        .foregroundStyle(LearningSprintTheme.ink2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(14)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private var subjects: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            ForEach(TsukanshiNativeConfig.subjects, id: \.self) { subject in
                Button { model.startSubject(subject) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(subject)
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.ink)
                            let count = model.content?.questions(subject: subject, premium: purchase.isPremium).count ?? 0
                            Text("\(count)問利用可能")
                                .font(LearningSprintTheme.sans(11))
                                .foregroundStyle(LearningSprintTheme.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(LearningSprintTheme.indigo)
                    }
                    .padding(13)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearningSprintTheme.line))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで")
                .font(LearningSprintTheme.sans(15, weight: .bold))
            HStack(spacing: 8) {
                summaryCell("\(model.state.attempts.count)", "回答")
                summaryCell("\(model.uniqueAnsweredCount)", "既出")
                summaryCell("\(model.weakCount)", "苦手")
            }
        }
    }

    private func summaryCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(LearningSprintTheme.serif(23, weight: .bold))
                .foregroundStyle(LearningSprintTheme.indigo)
            Text(label)
                .font(LearningSprintTheme.sans(11, weight: .bold))
                .foregroundStyle(LearningSprintTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct TsukanshiMockView: View {
    @ObservedObject var model: TsukanshiAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("模擬試験")
                            .font(LearningSprintTheme.serif(32, weight: .bold))
                        Text("第59〜57回の出題数に合わせ、監査済み独自問題から構成します。実際の過去問本文はアプリに転載しません。")
                            .font(LearningSprintTheme.sans(13))
                            .foregroundStyle(LearningSprintTheme.ink2)
                        ForEach(TsukanshiNativeConfig.examRounds, id: \.self) { round in
                            VStack(alignment: .leading, spacing: 9) {
                                Text(round)
                                    .font(LearningSprintTheme.serif(23, weight: .bold))
                                ForEach(TsukanshiNativeConfig.subjects, id: \.self) { subject in
                                    Button { model.startMock(round: round, subject: subject) } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text("\(round)対応｜\(subject)")
                                                    .font(LearningSprintTheme.sans(14, weight: .bold))
                                                    .foregroundStyle(LearningSprintTheme.ink)
                                                Text("独自演習 \(TsukanshiNativeConfig.mockQuestionCountBySubject[subject] ?? 0)問")
                                                    .font(LearningSprintTheme.sans(11))
                                                    .foregroundStyle(LearningSprintTheme.ink3)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(LearningSprintTheme.indigo)
                                        }
                                        .padding(13)
                                        .background(LearningSprintTheme.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearningSprintTheme.line))
                                    }
                                    .buttonStyle(.plain)
                                    .frame(minHeight: 44)
                                }
                                if let url = TsukanshiNativeConfig.officialExamURLs[round] {
                                    Link(destination: url) {
                                        Label("税関公式問題をSafariで開く", systemImage: "safari")
                                            .font(LearningSprintTheme.sans(12, weight: .bold))
                                    }
                                    .accessibilityHint("税関ホームページを外部ブラウザで開きます")
                                }
                            }
                            .padding(14)
                            .background(LearningSprintTheme.card.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct TsukanshiRecordsView: View {
    @ObservedObject var model: TsukanshiAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("記録")
                            .font(LearningSprintTheme.serif(32, weight: .bold))
                        HStack(spacing: 12) {
                            accuracyDonut
                            VStack(alignment: .leading, spacing: 6) {
                                Text("累計 \(model.state.attempts.count)回答")
                                    .font(LearningSprintTheme.sans(14, weight: .bold))
                                Text("苦手 \(model.weakCount)問")
                                    .font(LearningSprintTheme.sans(13))
                                Text("既出 \(model.uniqueAnsweredCount) / 480")
                                    .font(LearningSprintTheme.sans(13))
                            }
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("科目別正答率")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            ForEach(TsukanshiNativeConfig.subjects, id: \.self) { subject in
                                let value = model.subjectAccuracy[subject] ?? 0
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(subject).font(LearningSprintTheme.sans(13, weight: .bold))
                                        Spacer()
                                        Text("\(Int((value * 100).rounded()))%")
                                            .font(LearningSprintTheme.sans(12, weight: .bold))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(LearningSprintTheme.line)
                                            Capsule().fill(LearningSprintTheme.indigo).frame(width: geo.size.width * value)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("直近5週間")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            LearningSprintHeatmap(values: model.heatmap)
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("苦手リスト")
                                .font(LearningSprintTheme.sans(15, weight: .bold))
                            if model.state.weakQuestions.isEmpty {
                                Text("現在、苦手登録はありません。")
                                    .font(LearningSprintTheme.sans(13))
                                    .foregroundStyle(LearningSprintTheme.ink2)
                            } else {
                                ForEach(model.state.weakQuestions.keys.sorted(), id: \.self) { id in
                                    let question = model.content?.questions.first(where: { $0.id == id })
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(question?.topic ?? id)
                                            .font(LearningSprintTheme.sans(13, weight: .bold))
                                        Text("連続正解 \(model.state.weakQuestions[id]?.consecutiveCorrect ?? 0) / 3")
                                            .font(LearningSprintTheme.sans(11))
                                            .foregroundStyle(LearningSprintTheme.ink3)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(16)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var accuracyDonut: some View {
        let total = model.state.attempts.count
        let correct = model.state.attempts.filter(\.isCorrect).count
        let value = total == 0 ? 0 : Double(correct) / Double(total)
        return ZStack {
            Circle().stroke(LearningSprintTheme.line, lineWidth: 10)
            Circle()
                .trim(from: 0, to: value)
                .stroke(LearningSprintTheme.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((value * 100).rounded()))%")
                .font(LearningSprintTheme.serif(20, weight: .bold))
        }
        .frame(width: 92, height: 92)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("累計正答率")
        .accessibilityValue("\(Int((value * 100).rounded()))パーセント")
    }
}

struct TsukanshiSettingsView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    let showPaywall: () -> Void
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDocument = JSONBackupDocument()

    init(model: TsukanshiAppModel, showPaywall: @escaping () -> Void) {
        self.model = model
        self.purchase = model.purchaseController
        self.showPaywall = showPaywall
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LearningSprintPaperBackground()
                Form {
                    Section("学習") {
                        Picker("1回の問題数", selection: Binding(
                            get: { model.state.dailyTarget },
                            set: model.setDailyTarget
                        )) {
                            Text("4問").tag(4)
                            Text("8問").tag(8)
                            Text("16問").tag(16)
                        }
                        .pickerStyle(.segmented)

                        Picker("文字サイズ", selection: Binding(
                            get: { model.state.textSizeStep },
                            set: model.setTextSizeStep
                        )) {
                            Text("小").tag(0)
                            Text("標準").tag(1)
                            Text("大").tag(2)
                        }
                        .pickerStyle(.segmented)

                        if let date = model.state.examDate {
                            DatePicker("試験日", selection: Binding(
                                get: { date },
                                set: { model.setExamDate($0) }
                            ), displayedComponents: .date)
                        }
                    }

                    Section("プレミアム") {
                        HStack {
                            Text(purchase.isPremium ? "プレミアム解放済み" : "無料版")
                            Spacer()
                            if let price = purchase.displayPrice, !purchase.isPremium {
                                Text(price).fontWeight(.bold)
                            }
                        }
                        if !purchase.isPremium {
                            Button("プレミアムを確認") { showPaywall() }
                        }
                        Button("購入を復元") {
                            Task { await purchase.restore() }
                        }
                    }

                    Section("バックアップ") {
                        Button("JSONを書き出す") {
                            do {
                                exportDocument = JSONBackupDocument(data: try model.backupData())
                                exporting = true
                            } catch {
                                model.transientMessage = "書き出せません: \(error.localizedDescription)"
                            }
                        }
                        Button("JSONから復元") { importing = true }
                        Text("バックアップには学習履歴・苦手・設定が含まれます。別資格のJSONは読み込みません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("教材監査") {
                        if let bank = model.content?.bank {
                            LabeledContent("contentVersion", value: bank.contentVersion)
                            LabeledContent("lawBaselineDate", value: bank.lawBaselineDate)
                            LabeledContent("学習問題", value: "\(bank.studyQuestionCount)")
                            LabeledContent("申告書", value: "\(bank.declarationCount)")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 520)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "tsukanshi-learning-backup"
        ) { result in
            if case .failure(let error) = result {
                model.transientMessage = "書き出せません: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { model.importBackup(try Data(contentsOf: url)) }
                catch { model.transientMessage = "読み込めません: \(error.localizedDescription)" }
            case .failure(let error):
                model.transientMessage = "読み込めません: \(error.localizedDescription)"
            }
        }
    }
}

struct TsukanshiPaywallView: View {
    @ObservedObject var purchase: PurchaseController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("通関士 プレミアム")
                    .font(LearningSprintTheme.serif(30, weight: .bold))
                Text("計算問題の全範囲と申告書演習を買い切りで解放します。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                LearningSprintMemoryBlock("価格はApp Storeから取得した正式価格だけを表示します。")
                Spacer()
                if purchase.isPremium {
                    Label("購入済み", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(LearningSprintTheme.green)
                        .font(LearningSprintTheme.sans(17, weight: .bold))
                } else if let price = purchase.displayPrice {
                    Button {
                        Task { await purchase.purchase() }
                    } label: {
                        Text("\(price)で解放")
                            .font(LearningSprintTheme.sans(17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                    .disabled(purchase.state == .purchasing)
                } else {
                    Text("価格を取得できません")
                        .font(LearningSprintTheme.sans(15, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.vermilion)
                }
                Button("購入を復元") { Task { await purchase.restore() } }
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 520)
            .padding(20)
            .background(LearningSprintTheme.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data("{}".utf8)

    init() {}
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
