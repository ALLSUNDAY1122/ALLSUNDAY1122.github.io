import SwiftUI
import LearningSprintCore

struct TsukanshiMockNativeView: View {
    @ObservedObject var model: TsukanshiAppModel
    @ObservedObject private var purchase: PurchaseController
    @State private var showPaywall = false

    init(model: TsukanshiAppModel) {
        self.model = model
        self.purchase = model.purchaseController
    }

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
                            .fixedSize(horizontal: false, vertical: true)

                        practicalTraining

                        ForEach(TsukanshiNativeConfig.examRounds, id: \.self) { round in
                            roundCard(round)
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                    .padding(18)
                    .padding(.bottom, 16)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPaywall) {
            TsukanshiPaywallNativeView(purchase: purchase)
        }
    }

    private var practicalTraining: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("通関実務トレーニング")
                .font(LearningSprintTheme.serif(22, weight: .bold))
            Text("計算は無料範囲から開始できます。申告書演習はプレミアムで全12セットを利用できます。")
                .font(LearningSprintTheme.sans(12))
                .foregroundStyle(LearningSprintTheme.ink2)
            practiceButton(
                title: "計算",
                subtitle: "\(model.state.dailyTarget)問・完答 \(model.completionCount(for: .subject("通関実務｜計算")))回",
                systemImage: "number.square",
                locked: false
            ) {
                model.startNumericPractice()
            }
            practiceButton(
                title: "申告書演習",
                subtitle: purchase.isPremium
                    ? "全12セット・完答 \(model.completionCount(for: .subject("通関実務｜申告書")))回"
                    : "Premiumで全12セットを解放",
                systemImage: "doc.text.magnifyingglass",
                locked: !purchase.isPremium
            ) {
                if purchase.isPremium { model.startDeclarationPractice() }
                else { showPaywall = true }
            }
        }
        .padding(14)
        .background(LearningSprintTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LearningSprintTheme.line))
    }

    private func practiceButton(title: String, subtitle: String, systemImage: String, locked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(LearningSprintTheme.indigo)
                    .frame(width: 38, height: 38)
                    .background(LearningSprintTheme.indigoSoft, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(LearningSprintTheme.sans(14, weight: .bold))
                        if locked { Image(systemName: "lock.fill").font(.caption) }
                    }
                    Text(subtitle)
                        .font(LearningSprintTheme.sans(11))
                        .foregroundStyle(LearningSprintTheme.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(LearningSprintTheme.ink3)
            }
            .padding(10)
            .background(LearningSprintTheme.paper.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }

    private func roundCard(_ round: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(round)
                .font(LearningSprintTheme.serif(23, weight: .bold))
            ForEach(TsukanshiNativeConfig.subjects, id: \.self) { subject in
                let kind = SessionKind.mock("\(round)|\(subject)")
                let completed = model.completionCount(for: kind)
                Button { model.startMock(round: round, subject: subject) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(round)対応｜\(subject)")
                                .font(LearningSprintTheme.sans(14, weight: .bold))
                                .foregroundStyle(LearningSprintTheme.ink)
                            Text("独自演習 \(TsukanshiNativeConfig.mockQuestionCountBySubject[subject] ?? 0)問・完答 \(completed)回")
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
                .accessibilityLabel("\(round) \(subject) 模擬試験")
                .accessibilityValue("完答 \(completed)回")
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
