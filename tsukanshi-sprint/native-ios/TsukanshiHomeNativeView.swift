import SwiftUI
import LearningSprintCore

struct TsukanshiHomeNativeView: View {
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
                        brand
                        countdown
                        todayCard
                        resumeButton
                        actionCard(title: "今日のスプリント", subtitle: "\(model.state.dailyTarget)問を短く一周", icon: "bolt.fill", tint: LearningSprintTheme.indigo, action: model.startSprint)
                        actionCard(title: "苦手をつぶす", subtitle: model.weakCount == 0 ? "苦手はありません" : "\(model.weakCount)問・3連続正解で解除", icon: "target", tint: LearningSprintTheme.vermilion, enabled: model.weakCount > 0, action: model.startWeak)
                        actionCard(title: "模擬試験", subtitle: "第59〜57回の試験構成に合わせた独自演習", icon: "doc.text.fill", tint: LearningSprintTheme.gold, action: goMock)
                        subjectCards
                        historySummary
                        auditFooter
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

    private var brand: some View {
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
        .accessibilityElement(children: .combine)
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
            .accessibilityElement(children: .combine)
        }
    }

    private var todayCard: some View {
        HStack(spacing: 16) {
            LearningSprintProgressRing(progress: model.todayProgress, label: "\(model.todayAnswered)/\(model.state.dailyTarget)")
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

    @ViewBuilder private var resumeButton: some View {
        if model.state.resumeSession != nil {
            Button(action: model.resume) {
                Label("続きから再開", systemImage: "arrow.clockwise")
                    .font(LearningSprintTheme.sans(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.bordered)
            .tint(LearningSprintTheme.indigo)
            .accessibilityLabel("続きから再開")
            .accessibilityHint("中断した問題から学習を再開します")
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String, tint: Color, enabled: Bool = true, action: @escaping () -> Void) -> some View {
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
                Image(systemName: "chevron.right").foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(14)
            .background(LearningSprintTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }

    private var subjectCards: some View {
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
                            let completed = model.completionCount(for: .subject(subject))
                            Text("\(count)問利用可能・完答 \(completed)回")
                                .font(LearningSprintTheme.sans(11))
                                .foregroundStyle(LearningSprintTheme.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(LearningSprintTheme.indigo)
                    }
                    .padding(13)
                    .background(LearningSprintTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LearningSprintTheme.line))
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel(subject)
                .accessibilityValue("完答 \(model.completionCount(for: .subject(subject)))回")
            }
        }
    }

    private var historySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("これまで").font(LearningSprintTheme.sans(15, weight: .bold))
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
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var auditFooter: some View {
        if let content = model.content {
            Text("教材 \(content.bank.studyQuestionCount)問＋申告書\(content.bank.declarationCount)セット／法令基準 \(content.bank.lawBaselineDate)／公式過去問本文は同梱していません。")
                .font(LearningSprintTheme.sans(10))
                .foregroundStyle(LearningSprintTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
