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
        HStack(spacing: 8) {
            Button(action: start) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category).font(.subheadline.bold()).foregroundStyle(KSTheme.ink)
                        Text("解いた \(model.seenCount(exam: exam, category: category))/\(count)問").font(.caption2).foregroundStyle(KSTheme.tertiary)
                    }
                    Spacer()
                    Text("\(count)問").font(.caption).foregroundStyle(KSTheme.tertiary)
                    Image(systemName: purchase.isPremium ? "chevron.right" : "lock.fill")
                        .foregroundStyle(KSTheme.ai)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if purchase.isPremium {
                NavigationLink {
                    QuestionListView(title: "第\(exam)回・\(category)", questions: model.questions(exam: exam, category: category), sourceExam: exam, category: category, isMock: true)
                } label: {
                    Image(systemName: "list.bullet").font(.subheadline.bold()).foregroundStyle(KSTheme.ai)
                        .frame(width: 38, height: 38).background(KSTheme.aiSoft).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("問題一覧")
            }
        }
        .padding(14)
        .background(KSTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func start() {
        if purchase.isPremium {
            model.startMock(exam: exam, category: category)
        } else {
            showPaywall = true
        }
    }
}

struct QuestionListView: View {
    @EnvironmentObject var model: HokenshiAppModel
    let title: String
    let questions: [NativeQuestion]
    let sourceExam: Int?
    let category: String?
    let isMock: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 9) {
                HStack {
                    Text("解いた \(questions.filter { model.attempts(for: $0.id) > 0 }.count)/\(questions.count)問")
                        .font(.caption.bold()).foregroundStyle(KSTheme.ai)
                    Spacer()
                    Text("タップでその問題から解けます").font(.caption2).foregroundStyle(KSTheme.tertiary)
                }
                ForEach(questions) { q in
                    Button {
                        model.startFrom(q, in: questions, title: title, sourceExam: sourceExam, category: category, isMock: isMock)
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(q.questionNo)").font(.subheadline.bold()).foregroundStyle(KSTheme.ai).frame(width: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(q.question).font(.caption).foregroundStyle(KSTheme.ink).lineLimit(2).multilineTextAlignment(.leading)
                                Text(q.subject).font(.caption2).foregroundStyle(KSTheme.tertiary)
                            }
                            Spacer()
                            attemptBadge(q)
                        }
                        .padding(11)
                        .background(KSTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func attemptBadge(_ q: NativeQuestion) -> some View {
        let n = model.attempts(for: q.id)
        if n == 0 {
            Text("未挑戦").font(.caption2.bold()).foregroundStyle(KSTheme.tertiary)
                .padding(.horizontal, 8).padding(.vertical, 4).background(KSTheme.aiSoft).clipShape(Capsule())
        } else {
            let m = model.correctCount(for: q.id)
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(n)回").font(.caption.bold()).foregroundStyle(m == n ? KSTheme.green : KSTheme.ai)
                Text("正解 \(m)回").font(.caption2).foregroundStyle(KSTheme.tertiary)
            }
        }
    }
}

struct QuestionIndexView: View {
    @EnvironmentObject var model: HokenshiAppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach([112, 111, 110, 109, 108], id: \.self) { exam in
                    VStack(alignment: .leading, spacing: 9) {
                        Text("第\(exam)回").font(.headline)
                        ForEach(["午前", "午後"], id: \.self) { category in
                            let qs = model.questions(exam: exam, category: category)
                            NavigationLink {
                                QuestionListView(title: "第\(exam)回・\(category)", questions: qs, sourceExam: exam, category: category, isMock: true)
                            } label: {
                                HStack {
                                    Text(category).font(.subheadline.bold()).foregroundStyle(KSTheme.ink)
                                    Spacer()
                                    Text("解いた \(qs.filter { model.attempts(for: $0.id) > 0 }.count)/\(qs.count)問").font(.caption).foregroundStyle(KSTheme.tertiary)
                                    Image(systemName: "chevron.right").foregroundStyle(KSTheme.tertiary)
                                }
                                .padding(14).background(KSTheme.card)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KSTheme.line))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle("問題ごとの記録")
        .navigationBarTitleDisplayMode(.inline)
    }
}
