import SwiftUI
import LearningSprintCore

private struct MockCategoryRow: Identifiable {
    let id: String
    let count: Int
}

private let mockCategories = [
    MockCategoryRow(id: "必修", count: 50),
    MockCategoryRow(id: "一般", count: 130),
    MockCategoryRow(id: "状況設定", count: 60)
]

struct MockView: View {
    @EnvironmentObject var purchase: PurchaseController
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PageHeader(
                        eyebrow: "模擬試験",
                        title: "本番形式",
                        tagline: "第115・114・113回を、必修・一般・状況設定ごとに解けます。"
                    )
                    if !purchase.isPremium {
                        MockPremiumNotice(showPaywall: $showPaywall)
                    }
                    ForEach([115, 114, 113], id: \.self) { exam in
                        MockExamSection(exam: exam, showPaywall: $showPaywall)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(KSTheme.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MockPremiumNotice: View {
    @Binding var showPaywall: Bool
    var body: some View {
        KSCard(content:
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    PremiumBadge()
                    Text("本番形式はプレミアム").font(.headline)
                }
                Text("3試験回×240問の公式構成と特殊採点ルールを反映します。")
                    .font(.caption)
                    .foregroundStyle(KSTheme.secondary)
                Button("プレミアムを見る") { showPaywall = true }
                    .buttonStyle(.borderedProminent)
                    .tint(KSTheme.ai)
            }
        )
        .padding(.horizontal, 18)
    }
}

private struct MockExamSection: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    let exam: Int
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("第\(exam)回").font(.headline)
                Spacer()
                Text("240問").font(.caption).foregroundStyle(KSTheme.tertiary)
            }
            ForEach(mockCategories) { item in
                MockCategoryButton(
                    exam: exam,
                    category: item.id,
                    count: item.count,
                    showPaywall: $showPaywall
                )
            }
        }
        .padding(.horizontal, 18)
    }
}

private struct MockCategoryButton: View {
    @EnvironmentObject var model: KangoshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    let exam: Int
    let category: String
    let count: Int
    @Binding var showPaywall: Bool

    var body: some View {
        Button(action: start) {
            HStack {
                Text(category).font(.subheadline.bold())
                Spacer()
                Text("\(count)問").font(.caption).foregroundStyle(KSTheme.tertiary)
                Image(systemName: purchase.isPremium ? "chevron.right" : "lock.fill")
                    .foregroundStyle(KSTheme.ai)
            }
            .padding(14)
            .background(KSTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func start() {
        if purchase.isPremium {
            model.startMock(exam: exam, category: category)
        } else {
            showPaywall = true
        }
    }
}
