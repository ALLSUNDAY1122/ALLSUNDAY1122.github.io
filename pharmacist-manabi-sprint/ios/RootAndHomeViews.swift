import SwiftUI

struct RootView: View {
    @EnvironmentObject private var learning: LearningStore
    @EnvironmentObject private var storeKit: StoreKitManager

    var body: some View {
        ZStack {
            PaperBackground()
            switch learning.route {
            case .tabs:
                tabContent
            case .quiz:
                QuizView()
            case .result:
                ResultView()
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $learning.paywallPresented) {
            PaywallView()
                .environmentObject(storeKit)
        }
        .alert("教材データエラー", isPresented: Binding(get: { learning.loadError != nil }, set: { if !$0 { learning.loadError = nil } })) {
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(learning.loadError ?? "")
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        VStack(spacing: 0) {
            ZStack {
                switch learning.selectedTab {
                case .home: HomeView()
                case .mock: MockView()
                case .history: HistoryView()
                case .settings: SettingsView()
                }
            }
            BottomNav(selected: $learning.selectedTab)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var learning: LearningStore
    @EnvironmentObject private var storeKit: StoreKitManager
    @State private var selectedFieldForBatches: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ScreenTitle(brand: "学びスプリント", title: "薬剤師国家試験", tagline: "今日も1問、力に変える。")
                    .padding(.top, 18)
                if let days = learning.remainingDays() { countdown(days: days) }
                todayCard
                if learning.state.inProgress != nil { resumeButton }
                todaySprintButton
                weakButton
                mockButton
                fieldsSection
                totalStats
                sourceNote
            }
            .sprintScreenMargins()
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: Binding(
            get: { selectedFieldForBatches != nil },
            set: { if !$0 { selectedFieldForBatches = nil } }
        )) {
            if let field = selectedFieldForBatches {
                FieldBatchPickerView(field: field)
                    .environmentObject(learning)
                    .environmentObject(storeKit)
            }
        }
    }

    private func countdown(days: Int) -> some View {
        SprintCard {
            HStack(spacing: 18) {
                VStack(spacing: 0) {
                    Text("\(days)")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(days <= 14 ? Color.sprintShu : Color.sprintAi)
                    Text("日")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.sprintInk3)
                }
                let remaining = learning.unansweredCount(premium: storeKit.isPremium)
                Text(days == 0 ? "試験日です。" : "試験日まで。未着手 \(remaining)問。1日 \(max(1, Int(ceil(Double(remaining) / Double(max(days, 1))))))問ほどで一周できます。")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.sprintInk2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var todayCard: some View {
        SprintCard {
            HStack(spacing: 18) {
                ProgressRing(progress: learning.todayProgress) {
                    VStack(spacing: 0) {
                        Text("\(learning.todayRecord.answered)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color.sprintInk)
                        Text("/ \(learning.state.goal)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.sprintInk3)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日の学習")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.sprintInk)
                    Text(todayMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.sprintInk2)
                    Text("連続 \(learning.streak)日")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.sprintAi)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.sprintAiSoft)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var todayMessage: String {
        let r = learning.todayRecord
        if r.answered == 0 { return "まだ今日の分は解いていません。まずは1問。" }
        if r.answered >= learning.state.goal { return "今日の目標は達成。正解\(r.correct)問でした。" }
        return "あと\(learning.state.goal - r.answered)問で今日の目標に届きます。"
    }

    private var resumeButton: some View {
        Button {
            learning.resume()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("続きから再開").font(.system(size: 16, weight: .bold))
                    if let s = learning.state.inProgress {
                        Text("\(s.title)　\(min(s.index + 1, s.ids.count))問目から")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.sprintInk3)
                    }
                }
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(Color.sprintInk)
            .padding(16)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("resumeButton")
    }

    private var todaySprintButton: some View {
        Button {
            learning.startDaily(premium: storeKit.isPremium)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("今日のスプリント").font(.system(size: 17, weight: .bold))
                    Text("\(learning.state.goal)問・短く集中").font(.system(size: 12)).opacity(0.8)
                }
                Spacer()
                Image(systemName: "arrow.right")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("dailySprintButton")
    }

    private var weakButton: some View {
        Button {
            if learning.weakCount == 0 { return }
            let accessible = learning.state.weak.keys.compactMap { learning.questionMap[$0] }.contains { storeKit.isPremium || $0.isFree }
            if accessible { learning.startWeak(premium: storeKit.isPremium) } else { learning.paywallPresented = true }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.sprintShuSoft).frame(width: 38, height: 38)
                    Text("!").font(.system(size: 20, weight: .bold)).foregroundStyle(Color.sprintShu)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("苦手をつぶす").font(.system(size: 16, weight: .bold))
                    Text("3連続正解で苦手から卒業").font(.system(size: 12)).foregroundStyle(Color.sprintInk3)
                }
                Spacer()
                Text("\(learning.weakCount)問")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(learning.weakCount > 0 ? Color.sprintShu : Color.sprintInk3)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(learning.weakCount > 0 ? Color.sprintShuSoft : Color.sprintPaper)
                    .clipShape(Capsule())
            }
            .padding(15)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weakButton")
    }

    private var mockButton: some View {
        Button {
            learning.selectedTab = .mock
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.sprintAiSoft).frame(width: 38, height: 38)
                    Image(systemName: "rectangle.grid.2x2").foregroundStyle(Color.sprintAi)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("模擬試験").font(.system(size: 16, weight: .bold))
                    Text("3回分・必須／理論／実践").font(.system(size: 12)).foregroundStyle(Color.sprintInk3)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.sprintInk3)
            }
            .padding(15)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mockHomeButton")
    }

    private var fieldsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("分野から解く")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.sprintInk)
            Text("分野を選んだあと、約20問ずつのセットから開始できます。")
                .font(.system(size: 12))
                .foregroundStyle(Color.sprintInk3)
            ForEach(learning.uniqueFields, id: \.self) { field in
                let all = learning.activeQuestions.filter { $0.field == field }
                let seen = all.filter { learning.state.seen.contains($0.id) }.count
                let weak = all.filter { learning.state.weak[$0.id] != nil }.count
                Button {
                    if storeKit.isPremium {
                        selectedFieldForBatches = field
                    } else {
                        learning.paywallPresented = true
                    }
                } label: {
                    VStack(spacing: 9) {
                        HStack {
                            Text(field).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.sprintInk)
                            Spacer()
                            Text("\(all.count)問").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.sprintInk3)
                            if !storeKit.isPremium {
                                Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Color.sprintKin)
                            } else {
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.sprintInk3)
                            }
                        }
                        FieldProgressBar(progress: all.isEmpty ? 0 : Double(seen) / Double(all.count), color: .sprintAi)
                        HStack {
                            Text("解いた \(seen)/\(all.count)問")
                            Spacer()
                            Text("苦手 \(weak)問")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Color.sprintInk3)
                    }
                    .padding(15)
                    .background(Color.sprintCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private var totalStats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.sprintInk)
            HStack(spacing: 10) {
                stat(value: "\(learning.state.totalAnswered)", label: "のべ回答")
                stat(value: learning.state.totalAnswered == 0 ? "—" : "\(Int((learning.overallAccuracy * 100).rounded()))%", label: "正答率")
                stat(value: "\(learning.studyDays)", label: "学習日数")
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 7) {
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Color.sprintAi)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.sprintInk3)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .background(Color.sprintCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
    }

    private var sourceNote: some View {
        Text(storeKit.isPremium ? "第111・110・109回｜監査済み問題バンク1,035問" : "無料版｜第111回 必須90問。プレミアムで3回分1,031採点対象問題を解放。")
            .font(.system(size: 10))
            .foregroundStyle(Color.sprintInk3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}

struct FieldBatchPickerView: View {
    @EnvironmentObject private var learning: LearningStore
    @EnvironmentObject private var storeKit: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    let field: String

    private var batches: [FieldQuestionBatch] {
        learning.fieldQuestionBatches(field, premium: storeKit.isPremium)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("約20問ずつに分けています")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(Color.sprintInk)
                        Text("分野別学習は「今日のスプリント」の4／8／16問設定とは別です。選んだセットをまとめて解きます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.sprintInk3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                    ForEach(batches) { batch in
                        let seen = batch.questions.filter { learning.state.seen.contains($0.id) }.count
                        let weak = batch.questions.filter { learning.state.weak[$0.id] != nil }.count
                        Button {
                            learning.startFieldBatch(field, batchIndex: batch.index, premium: storeKit.isPremium)
                            dismiss()
                        } label: {
                            VStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(batch.title)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.sprintInk)
                                        Text("\(batch.count)問")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.sprintAi)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(Color.sprintAi)
                                }
                                FieldProgressBar(progress: batch.count == 0 ? 0 : Double(seen) / Double(batch.count), color: .sprintAi)
                                HStack {
                                    Text("解いた \(seen)/\(batch.count)問")
                                    Spacer()
                                    Text("苦手 \(weak)問")
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(Color.sprintInk3)
                            }
                            .padding(15)
                            .background(Color.sprintCard)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fieldBatch_\(batch.index)")
                    }
                }
                .sprintScreenMargins()
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(PaperBackground())
            .navigationTitle(field)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
