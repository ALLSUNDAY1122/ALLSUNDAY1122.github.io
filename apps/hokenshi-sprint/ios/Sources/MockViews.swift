import SwiftUI
import LearningSprintCore

private let mockCategories = ["午前", "午後"]

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
                        tagline: "第112〜108回を、午前・午後ごとに本番の順番で解けます。"
                    )
                    if !purchase.isPremium {
                        MockPremiumNotice(showPaywall: $showPaywall)
                    }
                    ForEach([112, 111, 110, 109, 108], id: \.self) { exam in
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
                Text("5試験回×午前・午後の構成で、公式の正答を反映します（公式PDFと照合できた問題のみ収録）。")
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
    @EnvironmentObject var model: HokenshiAppModel
    @EnvironmentObject var purchase: PurchaseController
    let exam: Int
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("第\(exam)回").font(.headline)
                Spacer()
                Text("\(model.questionCount(exam: exam))問").font(.caption).foregroundStyle(KSTheme.tertiary)
            }
            ForEach(mockCategories, id: \.self) { category in
                MockCategoryButton(
                    exam: exam,
                    category: category,
                    count: model.questionCount(exam: exam, category: category),
                    showPaywall: $showPaywall
                )
            }
        }
        .padding(.horizontal, 18)
    }
}

private struct MockCategoryButton: View {
    @EnvironmentObject var model: HokenshiAppModel
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
