import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @EnvironmentObject private var learning: LearningStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ScreenTitle(brand: "学習記録", title: "積み上げ", tagline: "短い反復が、そのまま形になります。")
                    .padding(.top, 18)
                topStats
                achievement
                heatmap
                weakList
                recentList
            }
            .sprintScreenMargins()
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("historyScreen")
    }

    private var topStats: some View {
        HStack(spacing: 10) {
            stat("\(learning.state.totalAnswered)", "のべ回答")
            stat("\(learning.state.totalCorrect)", "正解")
            stat("\(learning.streak)", "連続日数")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 7) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.sprintAi)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.sprintInk3)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Color.sprintCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
    }

    private var achievement: some View {
        SprintCard {
            VStack(spacing: 16) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(Color.sprintLine, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: learning.learningProgress)
                            .stroke(Color.sprintAi, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text("\(Int((learning.learningProgress * 100).rounded()))%")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Color.sprintAi)
                            Text("\(learning.learnedCount)/\(learning.activeQuestions.count)")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.sprintInk3)
                        }
                    }
                    .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("達成度")
                            .font(.system(size: 21, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.sprintInk)
                        Text("解いた問題数で一周の進み具合を表示します。")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.sprintInk2)
                        Text(learning.state.totalAnswered == 0 ? "全体正答率 —" : "全体正答率 \(Int((learning.overallAccuracy * 100).rounded()))%")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.sprintInk3)
                    }
                    Spacer(minLength: 0)
                }

                Divider().overlay(Color.sprintLine)

                VStack(spacing: 0) {
                    ForEach(learning.uniqueFields, id: \.self) { field in
                        let r = learning.fieldRecord(field)
                        let rate: Double? = r.answered > 0 ? Double(r.correct) / Double(r.answered) : nil
                        VStack(spacing: 7) {
                            HStack {
                                Text(field).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sprintInk)
                                Spacer()
                                Text(rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.sprintInk)
                            }
                            FieldProgressBar(progress: rate ?? 0, color: rateColor(rate))
                        }
                        .padding(.vertical, 9)
                        if field != learning.uniqueFields.last { Divider().overlay(Color.sprintLine) }
                    }
                }
            }
        }
        .accessibilityIdentifier("achievementCard")
    }

    private func rateColor(_ rate: Double?) -> Color {
        guard let rate else { return Color.sprintLine }
        if rate >= 0.7 { return .sprintMidori }
        if rate >= 0.5 { return .sprintKin }
        return .sprintShu
    }

    private var heatmap: some View {
        SprintCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("5週間の学習")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.sprintInk)
                VStack(spacing: 7) {
                    HStack(spacing: 0) {
                        ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                            Text(day).font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.sprintInk3).frame(width: 20)
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 4), count: 7), spacing: 4) {
                        ForEach(Array(learning.dailyCells35().enumerated()), id: \.offset) { _, cell in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(heatColor(cell.answered, future: cell.isFuture))
                                .frame(width: 16, height: 16)
                                .overlay {
                                    if cell.isToday { RoundedRectangle(cornerRadius: 3).stroke(Color.sprintAi, lineWidth: 2) }
                                }
                                .accessibilityLabel("\(dateLabel(cell.date))、\(cell.answered)問")
                        }
                    }
                    .frame(width: 136)
                }
                .frame(maxWidth: .infinity)
                Text("回答した問数を当日に記録します。正解・不正解にかかわらず学習量として反映されます。")
                    .font(.system(size: 11)).foregroundStyle(Color.sprintInk3)
            }
        }
        .accessibilityIdentifier("heatmapCard")
    }

    private func heatColor(_ count: Int, future: Bool) -> Color {
        if future { return Color.sprintLine.opacity(0.35) }
        switch count {
        case 0: return Color(red: 239/255, green: 232/255, blue: 218/255)
        case 1...3: return Color(red: 247/255, green: 201/255, blue: 189/255)
        case 4...7: return Color(red: 239/255, green: 156/255, blue: 136/255)
        case 8...15: return Color(red: 226/255, green: 111/255, blue: 85/255)
        default: return Color.sprintShu
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    private var weakList: some View {
        SprintCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("苦手一覧").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.sprintInk)
                if learning.state.weak.isEmpty {
                    Text("苦手問題はまだありません。").font(.system(size: 13)).foregroundStyle(Color.sprintInk3).padding(.vertical, 8)
                } else {
                    ForEach(Array(learning.state.weak.keys.prefix(20)), id: \.self) { id in
                        if let q = learning.questionMap[id], let w = learning.state.weak[id] {
                            HStack {
                                Text("\(q.field)・問\(q.questionNo)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sprintInk)
                                Spacer()
                                Text("\(w.streak)/3").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sprintShu)
                            }
                            .padding(.vertical, 7)
                            Divider().overlay(Color.sprintLine)
                        }
                    }
                }
            }
        }
    }

    private var recentList: some View {
        SprintCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("直近のスプリント").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.sprintInk)
                if learning.state.history.isEmpty {
                    Text("完了したスプリントがここに表示されます。").font(.system(size: 13)).foregroundStyle(Color.sprintInk3).padding(.vertical, 8)
                } else {
                    ForEach(learning.state.history.prefix(10)) { h in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(h.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sprintInk)
                                Text(h.completedAt.formatted(date: .numeric, time: .shortened)).font(.system(size: 10)).foregroundStyle(Color.sprintInk3)
                            }
                            Spacer()
                            Text("\(h.score)/\(h.total)").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.sprintAi)
                        }
                        .padding(.vertical, 7)
                        Divider().overlay(Color.sprintLine)
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var learning: LearningStore
    @State private var useExamDate = false
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var importMessage: String?
    @State private var resetConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenTitle(brand: "設定", title: "学び方", tagline: "毎日の量と読みやすさを、自分に合わせます。")
                    .padding(.top, 18)
                SprintCard {
                    VStack(spacing: 0) {
                        settingBlock("文字サイズ") {
                            HStack(spacing: 6) {
                                ForEach([16, 18, 20], id: \.self) { size in
                                    segmentButton(label: size == 16 ? "標準" : size == 18 ? "大" : "特大", active: learning.state.fontSize == size) {
                                        learning.updateFontSize(size)
                                    }
                                }
                            }
                        }
                        divider
                        settingBlock("1日の目標") {
                            HStack(spacing: 6) {
                                ForEach([4, 8, 16], id: \.self) { goal in
                                    segmentButton(label: "\(goal)問", active: learning.state.goal == goal) { learning.updateGoal(goal) }
                                }
                            }
                        }
                        divider
                        toggleRow("出題順をシャッフル", isOn: Binding(get: { learning.state.shuffleQuestions }, set: learning.updateShuffleQuestions))
                        divider
                        toggleRow("選択肢もシャッフル", isOn: Binding(get: { learning.state.shuffleChoices }, set: learning.updateShuffleChoices))
                        divider
                        examDateBlock
                        divider
                        backupBlock
                        divider
                        infoBlock(title: "覚えかたのルール", text: "間違い・「わからない」は苦手に追加。苦手問題は3回連続正解で自動的に卒業します。")
                        divider
                        infoBlock(title: "この教材について", text: "第111・110・109回の監査済み問題バンク1,035問を端末内に同梱。採点対象1,031問は追加購入なしですべて利用できます。ログイン・広告・アプリ内課金・独自クラウド同期はありません。")
                        divider
                        Button(role: .destructive) { resetConfirm = true } label: {
                            Text("学習記録をリセット").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity, minHeight: 50)
                        }
                    }
                }
                .accessibilityIdentifier("mandatorySettingsCard")
            }
            .sprintScreenMargins()
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .onAppear { useExamDate = learning.state.examDate != nil }
        .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "yakuzaishi-learning-backup.json") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                try learning.importData(Data(contentsOf: url))
                importMessage = "学習データを読み込みました。"
            } catch {
                importMessage = "読み込みに失敗しました。バックアップファイルを確認してください。"
            }
        }
        .alert("学習データ", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK") { importMessage = nil }
        } message: { Text(importMessage ?? "") }
        .confirmationDialog("学習記録をすべて削除しますか？", isPresented: $resetConfirm, titleVisibility: .visible) {
            Button("削除する", role: .destructive) { learning.resetLearningData() }
            Button("キャンセル", role: .cancel) { }
        }
    }

    private var divider: some View { Divider().overlay(Color.sprintLine).padding(.vertical, 2) }

    private func settingBlock<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sprintInk)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func segmentButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(active ? Color.sprintAi : Color.sprintInk3)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(active ? Color.sprintAiSoft : Color.sprintPaper)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sprintInk)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Color.sprintAi)
        }
        .padding(.vertical, 12)
    }

    private var examDateBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("試験日を設定", isOn: $useExamDate)
                .font(.system(size: 13, weight: .semibold))
                .tint(Color.sprintAi)
                .onChange(of: useExamDate) { enabled in
                    if enabled && learning.state.examDate == nil { learning.updateExamDate(Calendar.current.date(byAdding: .month, value: 6, to: Date())) }
                    if !enabled { learning.updateExamDate(nil) }
                }
            if useExamDate {
                DatePicker("試験日", selection: Binding(get: { learning.state.examDate ?? Date() }, set: { learning.updateExamDate($0) }), displayedComponents: .date)
                    .font(.system(size: 13))
            }
        }
        .padding(.vertical, 12)
    }

    private var backupBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("学習データ").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sprintInk)
            HStack(spacing: 8) {
                Button("JSONを書き出す") {
                    do { exportDocument = BackupDocument(data: try learning.exportData()); exporting = true }
                    catch { importMessage = "書き出しに失敗しました。" }
                }
                .buttonStyle(.bordered)
                Button("JSONを読み込む") { importing = true }.buttonStyle(.bordered)
            }
            .tint(Color.sprintAi)
        }
        .padding(.vertical, 12)
    }

    private func infoBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.sprintInk)
            Text(text).font(.system(size: 12)).foregroundStyle(Color.sprintInk2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
