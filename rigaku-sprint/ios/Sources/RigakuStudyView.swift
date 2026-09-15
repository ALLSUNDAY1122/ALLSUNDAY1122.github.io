import LearningSprintCore
import SwiftUI

struct RigakuStudyView: View {
    @EnvironmentObject private var appModel: RigakuAppModel

    let kind: SessionKind
    let resumeExisting: Bool

    @State private var sessionQuestions: [LearningQuestion] = []
    @State private var index = 0
    @State private var selectedIndices: Set<Int> = []
    @State private var evaluation: AnswerEvaluation?
    @State private var correctness: [String: Bool] = [:]
    @State private var didLoad = false
    @State private var completed = false
    @State private var localError: String?

    init(kind: SessionKind, resumeExisting: Bool = false) {
        self.kind = kind
        self.resumeExisting = resumeExisting
    }

    var body: some View {
        ZStack {
            LearningSprintPaperBackground()
            if accessLocked {
                premiumLockedView
            } else if completed {
                completionView
            } else if sessionQuestions.isEmpty && didLoad {
                emptyView
            } else if let question = currentQuestion {
                questionView(question)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSessionIfNeeded)
        .alert("学習処理エラー", isPresented: Binding(
            get: { localError != nil },
            set: { if !$0 { localError = nil } }
        )) {
            Button("閉じる", role: .cancel) {}
        } message: {
            Text(localError ?? "")
        }
    }

    private var accessLocked: Bool {
        switch kind {
        case .mock:
            return !appModel.canAccessBaseMocks
        case .weak:
            return !appModel.canAccessFullWeakReview
        case .sprint, .subject:
            return false
        }
    }

    private var currentQuestion: LearningQuestion? {
        guard sessionQuestions.indices.contains(index) else { return nil }
        return sessionQuestions[index]
    }

    private var navigationTitle: String {
        switch kind {
        case .sprint: return "今日のスプリント"
        case .weak: return "苦手をつぶす"
        case .subject(let name): return name
        case .mock(let round): return "第\(round)回ベース模試"
        }
    }

    private func loadSessionIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard !accessLocked else { return }

        if resumeExisting,
           let snapshot = appModel.state.resumeSession,
           snapshot.kind == kind {
            sessionQuestions = appModel.resumeQuestions()
            correctness = appModel.resumeCorrectness()
            index = min(snapshot.currentIndex, max(0, sessionQuestions.count - 1))
            return
        }

        sessionQuestions = appModel.questions(for: kind)
        correctness = [:]
        index = 0
        if !sessionQuestions.isEmpty {
            appModel.beginSession(kind: kind, questions: sessionQuestions)
        }
    }

    @ViewBuilder
    private func questionView(_ question: LearningQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("\(index + 1) / \(sessionQuestions.count)")
                        .font(LearningSprintTheme.sans(13, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.indigo)
                    Spacer()
                    Text(question.subject)
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Text(question.prompt)
                    .font(LearningSprintTheme.serif(19, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("study.prompt")

                if let media = appModel.media(for: question.id) {
                    Image(media.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(media.accessibilityLabel)
                }

                choiceArea(question)

                if evaluation == nil {
                    Button {
                        submit(question: question, answer: .unknown)
                    } label: {
                        Text("わからない")
                            .font(LearningSprintTheme.sans(15, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(LearningSprintTheme.indigo)
                    .accessibilityIdentifier("study.unknown")
                }

                if let evaluation {
                    resultArea(question: question, evaluation: evaluation)
                }
            }
            .padding(18)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func choiceArea(_ question: LearningQuestion) -> some View {
        switch question.answerType {
        case .singleChoice, .multiChoice:
            VStack(spacing: 10) {
                ForEach(question.choices.indices, id: \.self) { choiceIndex in
                    Button {
                        handleChoiceTap(question: question, choiceIndex: choiceIndex)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text(choiceLabel(choiceIndex))
                                .font(LearningSprintTheme.sans(13, weight: .bold))
                                .frame(width: 28, height: 28)
                                .background(selectedIndices.contains(choiceIndex) ? LearningSprintTheme.indigo : LearningSprintTheme.indigoSoft)
                                .foregroundStyle(selectedIndices.contains(choiceIndex) ? Color.white : LearningSprintTheme.indigo)
                                .clipShape(Circle())
                            Text(question.choices[choiceIndex])
                                .font(LearningSprintTheme.serif(16))
                                .foregroundStyle(LearningSprintTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(LearningSprintTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(selectedIndices.contains(choiceIndex) ? LearningSprintTheme.indigo : LearningSprintTheme.line, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(evaluation != nil)
                }

                if question.answerType == .multiChoice && evaluation == nil {
                    Button("回答する") {
                        submit(
                            question: question,
                            answer: AnswerPayload(selectedIndices: selectedIndices.sorted())
                        )
                    }
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .disabled(selectedIndices.isEmpty)
                }
            }

        default:
            Text("この回答形式は理学療法士版の初期対象外です。問題データ監査で混入を禁止します。")
                .font(LearningSprintTheme.sans(14, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.vermilion)
                .padding(14)
                .background(LearningSprintTheme.vermilionSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func handleChoiceTap(question: LearningQuestion, choiceIndex: Int) {
        guard evaluation == nil else { return }
        switch question.answerType {
        case .singleChoice:
            selectedIndices = [choiceIndex]
            submit(question: question, answer: AnswerPayload(selectedIndices: [choiceIndex]))
        case .multiChoice:
            if selectedIndices.contains(choiceIndex) {
                selectedIndices.remove(choiceIndex)
            } else {
                selectedIndices.insert(choiceIndex)
            }
        default:
            break
        }
    }

    private func submit(question: LearningQuestion, answer: AnswerPayload) {
        do {
            let result = try appModel.recordAnswer(
                question: question,
                answer: answer,
                advanceTo: index + 1
            )
            correctness[question.id] = result.isCorrect
            evaluation = result
        } catch {
            localError = "回答を採点できませんでした。問題データの監査が必要です。"
        }
    }

    @ViewBuilder
    private func resultArea(question: LearningQuestion, evaluation: AnswerEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text(evaluation.isCorrect ? "○" : "×")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(LearningSprintTheme.vermilion)
                    .rotationEffect(.degrees(evaluation.isCorrect ? -7 : 5))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(evaluation.message)
                        .font(LearningSprintTheme.sans(18, weight: .bold))
                    if evaluation.isUnknown {
                        Text("苦手として記録しました")
                            .font(LearningSprintTheme.sans(12, weight: .semibold))
                            .foregroundStyle(LearningSprintTheme.ink2)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Text(question.explanation)
                .font(LearningSprintTheme.serif(16))
                .foregroundStyle(LearningSprintTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            LearningSprintMemoryBlock(question.memoryPoint)

            if let sourceTitle = question.sourceTitle, let sourceURL = question.sourceURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text("根拠")
                        .font(LearningSprintTheme.sans(11, weight: .bold))
                        .foregroundStyle(LearningSprintTheme.ink3)
                    Text(sourceTitle)
                        .font(LearningSprintTheme.sans(12, weight: .semibold))
                    Text(sourceURL)
                        .font(LearningSprintTheme.sans(10))
                        .foregroundStyle(LearningSprintTheme.indigo)
                        .textSelection(.enabled)
                }
            }

            Button(index + 1 < sessionQuestions.count ? "次の問題" : "結果へ") {
                advance()
            }
            .font(LearningSprintTheme.sans(15, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(LearningSprintTheme.indigo)
            .frame(maxWidth: .infinity, minHeight: 50)
            .accessibilityIdentifier("study.next")
        }
        .padding(16)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func advance() {
        if index + 1 < sessionQuestions.count {
            index += 1
            selectedIndices = []
            evaluation = nil
        } else {
            appModel.finishSession()
            completed = true
        }
    }

    private var premiumLockedView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.open.display")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(LearningSprintTheme.gold)
                Text("月額プランで解放")
                    .font(LearningSprintTheme.serif(24, weight: .bold))
                Text("無料版では8分野から選んだ60問を利用できます。月額プランでは全600問・第58〜60回ベース模試・全苦手復習を利用できます。")
                    .font(LearningSprintTheme.sans(14))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let price = appModel.purchaseDisplayPrice {
                    Button("月額プランを開始（\(price) / 1か月）") {
                        Task { await appModel.purchasePremium() }
                    }
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(LearningSprintTheme.indigo)
                    .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    Text("App Storeから価格を確認しています。")
                        .font(LearningSprintTheme.sans(13))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }

                Text("1か月ごとに自動更新され、解約するまで継続します。請求額は購入時にApp Storeへ表示される価格です。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink2)
                    .multilineTextAlignment(.center)

                Button("購入を復元") {
                    Task { await appModel.restorePurchases() }
                }
                .font(LearningSprintTheme.sans(14, weight: .semibold))

                HStack(spacing: 18) {
                    Link("プライバシー", destination: RigakuAppConfiguration.privacyURL)
                    Link("利用条件", destination: RigakuAppConfiguration.termsURL)
                }
                .font(LearningSprintTheme.sans(12, weight: .semibold))

                Text("購読の管理・解約はApple Accountのサブスクリプション設定で行えます。")
                    .font(LearningSprintTheme.sans(11))
                    .foregroundStyle(LearningSprintTheme.ink3)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("premium.locked")
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(LearningSprintTheme.indigo)
            Text("利用できる問題がありません")
                .font(LearningSprintTheme.serif(22, weight: .bold))
            Text("監査済み問題データと利用範囲を確認してください。")
                .font(LearningSprintTheme.sans(14))
                .foregroundStyle(LearningSprintTheme.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    @ViewBuilder
    private var completionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if case .mock(let round) = kind,
                   let score = appModel.mockScore(
                       round: round,
                       questions: sessionQuestions,
                       correctness: correctness
                   ) {
                    Text(score.passed ? "合格基準クリア" : "合格基準未到達")
                        .font(LearningSprintTheme.serif(28, weight: .bold))
                        .foregroundStyle(score.passed ? LearningSprintTheme.green : LearningSprintTheme.vermilion)
                        .accessibilityIdentifier("mock.result.status")

                    VStack(spacing: 10) {
                        scoreRow("総得点", score.totalPoints, score.totalMax, threshold: score.passTotal)
                        scoreRow("実地問題", score.practicalPoints, score.practicalMax, threshold: score.passPractical)
                        scoreRow("一般問題", score.generalPoints, score.generalMax, threshold: nil)
                    }
                    .padding(16)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))

                    Text("第\(round)回の公式配点を再現して集計します。問題文・図版は権利と内容を監査した独自問題で再構成し、厚生労働省が採点対象外とした問題は0点として扱います。")
                        .font(LearningSprintTheme.sans(12, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("完了")
                        .font(LearningSprintTheme.serif(30, weight: .bold))
                    Text("このセットの記録を保存しました。")
                        .font(LearningSprintTheme.sans(14, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink2)
                }
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private func scoreRow(_ label: String, _ points: Int, _ max: Int, threshold: Int?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LearningSprintTheme.sans(13, weight: .bold))
                if let threshold {
                    Text("基準 \(threshold)点以上")
                        .font(LearningSprintTheme.sans(10, weight: .medium))
                        .foregroundStyle(LearningSprintTheme.ink3)
                }
            }
            Spacer()
            Text("\(points) / \(max)")
                .font(LearningSprintTheme.serif(20, weight: .bold))
                .foregroundStyle(LearningSprintTheme.indigo)
        }
    }

    private func choiceLabel(_ index: Int) -> String {
        ["A", "B", "C", "D", "E", "F", "G"].indices.contains(index)
            ? ["A", "B", "C", "D", "E", "F", "G"][index]
            : String(index + 1)
    }
}
