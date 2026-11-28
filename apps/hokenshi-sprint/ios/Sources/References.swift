import SwiftUI

/// 出題元の表示（第◯回・午前/午後・第◯問）。
struct QuestionSourceBadge: View {
    let question: NativeQuestion
    var body: some View {
        Text("第\(question.sourceExam)回 \(question.category) 第\(question.questionNo)問")
            .font(.caption2.bold()).foregroundStyle(KSTheme.secondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(KSTheme.aiSoft).clipShape(Capsule())
    }
}

/// 解説下の「出典・参考資料」導線。
struct ExplanationReferencesSection: View {
    let question: NativeQuestion
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack {
                Label("出典・参考資料", systemImage: "books.vertical").font(.caption.bold())
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(KSTheme.ai)
            .padding(10)
            .background(KSTheme.aiSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explanation-references-link")
    }
}

private let referenceLaws = [
    "保健師助産師看護師法",
    "地域保健法",
    "健康増進法（健康日本21（第三次））",
    "母子保健法（健やか親子21）",
    "感染症の予防及び感染症の患者に対する医療に関する法律",
    "予防接種法",
    "学校保健安全法",
    "労働安全衛生法",
    "介護保険法",
    "精神保健及び精神障害者福祉に関する法律",
    "障害者の日常生活及び社会生活を総合的に支援するための法律",
    "難病の患者に対する医療等に関する法律",
    "食品衛生法",
    "医療法",
]

private var referenceBody: some View {
    VStack(alignment: .leading, spacing: 12) {
        Text("問題の原典は、厚生労働省が公表した保健師国家試験の問題・正答です（第112〜108回）。解説は公式資料をもとに作成した学習用の要約で、条文・数値の最終確認は下記の公的資料で行ってください。")
            .font(.caption).foregroundStyle(KSTheme.secondary)
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: "https://www.mhlw.go.jp/")!) {
                HStack { Label("厚生労働省（国家試験・公表資料）", systemImage: "building.columns").font(.subheadline.bold()); Spacer(); Image(systemName: "arrow.up.forward.square") }
                    .foregroundStyle(KSTheme.ai).frame(minHeight: 44).contentShape(Rectangle())
            }
            Link(destination: URL(string: "https://laws.e-gov.go.jp/")!) {
                HStack { Label("e-Gov法令検索", systemImage: "doc.text.magnifyingglass").font(.subheadline.bold()); Spacer(); Image(systemName: "arrow.up.forward.square") }
                    .foregroundStyle(KSTheme.ai).frame(minHeight: 44).contentShape(Rectangle())
            }
        }
        Text("主な根拠法令・計画").font(.subheadline.bold()).foregroundStyle(KSTheme.ink)
        ForEach(referenceLaws, id: \.self) { law in
            HStack(alignment: .top, spacing: 8) {
                Text("・").foregroundStyle(KSTheme.tertiary)
                Text(law).font(.caption).foregroundStyle(KSTheme.secondary)
            }
        }
    }
}

struct ReferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                referenceBody.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(KSTheme.paper.ignoresSafeArea())
            .navigationTitle("出典・参考資料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
        }
    }
}

struct ReferencesView: View {
    var body: some View {
        ScrollView {
            referenceBody.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle("出典・参考資料")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("このアプリは保健師国家試験の学習を補助するための教材です。収録問題は厚生労働省の公表資料と照合していますが、制度改正・統計の更新により、現在の制度や最新の数値と異なる場合があります（当時の正答にはその旨の注記を表示します）。")
                    .font(.caption).foregroundStyle(KSTheme.secondary)
                Text("試験の実施要項・出題範囲・合格基準などの公式情報は、必ず厚生労働省の発表でご確認ください。本アプリの利用によって生じた結果について、開発者は責任を負いません。")
                    .font(.caption).foregroundStyle(KSTheme.secondary)
                Text("本アプリは医療・保健指導の実務判断に代わるものではありません。")
                    .font(.caption).foregroundStyle(KSTheme.secondary)
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle("ご利用上の注意")
        .navigationBarTitleDisplayMode(.inline)
    }
}
