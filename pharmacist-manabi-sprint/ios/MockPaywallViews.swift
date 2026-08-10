import SwiftUI

struct MockView: View {
    @EnvironmentObject private var learning: LearningStore
    @EnvironmentObject private var storeKit: StoreKitManager

    private let exams = [111, 110, 109]
    private let sections = ["必須", "理論", "実践"]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ScreenTitle(brand: "模擬試験", title: "本番形式", tagline: "3回分を必須・理論・実践に分けて解けます。")
                    .padding(.top, 18)
                ForEach(exams, id: \.self) { exam in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("第\(exam)回")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.sprintInk)
                            Spacer()
                            let done = sections.filter { learning.state.mock["\(exam)-\($0)"] != nil }.count
                            Text("完答 \(done)/3 区分")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.sprintInk3)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                            ForEach(sections, id: \.self) { section in
                                mockCard(exam: exam, section: section)
                            }
                        }
                    }
                }
            }
            .sprintScreenMargins()
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("mockScreen")
    }

    private func mockCard(exam: Int, section: String) -> some View {
        let all = learning.activeQuestions.filter { $0.exam == exam && $0.section == section }
        let unlocked = storeKit.isPremium || (exam == 111 && section == "必須")
        let result = learning.state.mock["\(exam)-\(section)"]
        let rate = result.map { $0.total > 0 ? Double($0.score) / Double($0.total) : 0 }
        return Button {
            if unlocked { learning.startMock(exam: exam, section: section, premium: storeKit.isPremium) }
            else { learning.paywallPresented = true }
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    ZStack {
                        Circle().stroke(Color.sprintLine, lineWidth: 5)
                        if let rate {
                            Circle().trim(from: 0, to: rate).stroke(rate >= 0.6 ? Color.sprintMidori : Color.sprintShu, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                        }
                        Text(rate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.sprintInk)
                    }.frame(width: 46, height: 46)
                    Spacer()
                    if !unlocked { Image(systemName: "lock.fill").foregroundStyle(Color.sprintKin) }
                }
                Text(section).font(.system(size: 15, weight: .bold)).foregroundStyle(Color.sprintInk)
                Text("\(all.count)問").font(.system(size: 11)).foregroundStyle(Color.sprintInk3)
                Text(result.map { "前回 \($0.score)/\($0.total)" } ?? (unlocked ? "未受験" : "プレミアム"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(result == nil ? Color.sprintInk3 : ((rate ?? 0) >= 0.6 ? Color.sprintMidori : Color.sprintShu))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintLine))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mock_\(exam)_\(section)")
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeKit: StoreKitManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color.sprintAiSoft).frame(width: 76, height: 76)
                        Image(systemName: "books.vertical.fill").font(.system(size: 32)).foregroundStyle(Color.sprintAi)
                    }
                    Text("薬剤師国家試験 プレミアム")
                        .font(.system(size: 25, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.sprintInk)
                    Text("第111・110・109回の採点対象1,031問を、必須・理論・実践すべて解放します。")
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.sprintInk2)

                    SprintCard {
                        VStack(alignment: .leading, spacing: 11) {
                            benefit("3回分の全採点対象問題")
                            benefit("分野別・模試・苦手復習")
                            benefit("オフライン学習・途中再開")
                            benefit("購入後も学習記録は端末内に保持")
                        }
                    }

                    if storeKit.monthlyAvailable {
                        Button {
                            Task { await storeKit.purchaseMonthly() }
                        } label: {
                            VStack(spacing: 3) {
                                Text(storeKit.introConfigured && storeKit.introEligible ? "7日間無料ではじめる" : "月額プランではじめる")
                                    .font(.system(size: 16, weight: .bold))
                                Text(storeKit.monthlyPrice.isEmpty ? "価格はApp Storeで確認" : "\(storeKit.monthlyPrice) / 月で自動更新")
                                    .font(.system(size: 11)).opacity(0.82)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    } else {
                        unavailable("月額プラン")
                    }

                    if storeKit.lifetimeAvailable {
                        Button {
                            Task { await storeKit.purchaseLifetime() }
                        } label: {
                            VStack(spacing: 3) {
                                Text("買い切りで利用する").font(.system(size: 15, weight: .bold))
                                Text(storeKit.lifetimePrice.isEmpty ? "価格はApp Storeで確認" : storeKit.lifetimePrice)
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(Color.sprintAi)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.sprintAi))
                        }
                        .buttonStyle(.plain)
                    } else {
                        unavailable("買い切りプラン")
                    }

                    HStack {
                        Button("購入を復元") { Task { await storeKit.restore() } }
                        if storeKit.hasMonthlyEntitlement {
                            Spacer()
                            Button("サブスクリプション管理") { Task { await storeKit.manageSubscriptions() } }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.sprintAi)
                    .frame(maxWidth: .infinity)

                    if let message = storeKit.statusMessage {
                        Text(message).font(.system(size: 12)).foregroundStyle(Color.sprintInk3).multilineTextAlignment(.center)
                    }

                    Text("無料期間が表示されるのは、App Storeが対象と判定した場合のみです。月額プランは解約するまで自動更新されます。価格・無料期間の条件は購入確認画面で最終確認してください。")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.sprintInk3)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(Color.sprintPaper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.foregroundStyle(Color.sprintAi)
                }
            }
            .task { await storeKit.refresh() }
        }
        .presentationDetents([.large])
    }

    private func benefit(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.sprintMidori)
            Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.sprintInk)
        }
    }

    private func unavailable(_ title: String) -> some View {
        Text("\(title)の商品情報を取得できません。App Store設定を確認してください。")
            .font(.system(size: 12)).foregroundStyle(Color.sprintInk3)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.sprintCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
