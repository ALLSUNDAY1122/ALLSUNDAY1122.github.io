import SwiftUI

// Guideline 1.4.1: sources for the exam questions and public reference material
// for the app's own study explanations. Every URL below was opened and its title /
// content checked on 2026-11-28 (JST) before it was added. Do not add guessed URLs.
// Question text, answers and explanations are NOT modified; this only adds metadata.

enum ReferenceCategory: String, CaseIterable, Identifiable {
    case exam = "国家試験の原典（問題・正答）"
    case standard = "出題基準"
    case infection = "感染対策・感染症"
    case drug = "医薬品・薬理"
    case safety = "医療安全"
    case maternal = "母子保健"
    case publicHealth = "保健統計"
    case welfare = "社会保障・介護・福祉"
    case mental = "精神保健"
    case law = "法令"
    var id: String { rawValue }
}

struct SourceReference: Identifiable, Hashable {
    let id: String
    let title: String
    let organization: String
    let urlString: String
    let category: ReferenceCategory
    let summary: String
    var url: URL? { URL(string: urlString) }
}

/// Official MHLW publication of one exam (question booklets + answer key).
struct ExamSource: Identifiable {
    let exam: Int
    let heldOn: String
    let pageURLString: String
    let answerPDFURLString: String
    var id: Int { exam }
    /// The MHLW 「…問題および正答について」 page (HTML). Never the answer-key PDF.
    var pageURL: URL? { URL(string: pageURLString) }
    var answerPDFURL: URL? { URL(string: answerPDFURLString) }
    var title: String { "第\(exam)回 看護師国家試験" }
}

/// Per-question source metadata, resolved automatically (exam → official page,
/// subject area / topic → shared public references). Nothing is stored per question.
struct QuestionSource {
    let exam: ExamSource?
    let citation: String
    let explanationSourceIDs: [String]
    var explanationReferences: [SourceReference] { explanationSourceIDs.compactMap { ReferenceCatalog.reference($0) } }
}

enum ReferenceCatalog {
    static let checkedOn = "2026年11月28日"

    static let examSources: [ExamSource] = [
        ExamSource(exam: 115, heldOn: "令和8年（2026年）2月15日実施",
                   pageURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp260424-03_04_05.html",
                   answerPDFURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp260424-05seitou.pdf"),
        ExamSource(exam: 114, heldOn: "令和7年（2025年）2月16日実施",
                   pageURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp250428-03_04_05.html",
                   answerPDFURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp250428-05seitou.pdf"),
        ExamSource(exam: 113, heldOn: "令和6年（2024年）2月11日実施",
                   pageURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/tp240424-03_04_05.html",
                   answerPDFURLString: "https://www.mhlw.go.jp/seisakunitsuite/bunya/kenkou_iryou/iryou/topics/dl/tp240424-05seitou.pdf")
    ]

    static let references: [SourceReference] = [
        SourceReference(id: "standard-2023-nurse", title: "看護師国家試験出題基準（保健師助産師看護師国家試験出題基準 令和5年版）", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/content/10803000/000919502.pdf", category: .standard,
                        summary: "看護師国家試験の出題範囲（科目・大項目・中項目）を示す公式資料。"),
        SourceReference(id: "standard-2023-page", title: "「保健師助産師看護師国家試験出題基準 令和5年版」について", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/shingi2/0000159020_00001.html", category: .standard,
                        summary: "出題基準の掲載ページ（全体版・改定概要・各職種版のPDF）。"),
        SourceReference(id: "mhlw-infection-control", title: "院内感染対策について", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/newpage_21747.html", category: .infection,
                        summary: "医療機関における院内感染対策の通知・講習会資料。"),
        SourceReference(id: "mhlw-standard-precautions", title: "令和7年度 院内感染対策講習会資料「標準予防策と経路別予防策」", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/content/10800000/001243398.pdf", category: .infection,
                        summary: "手指衛生・個人防護具・経路別予防策などの解説資料。"),
        SourceReference(id: "mhlw-infectious-disease", title: "感染症情報", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/kekkaku-kansenshou/index.html", category: .infection,
                        summary: "感染症・予防接種に関する厚生労働省の情報ページ。"),
        SourceReference(id: "pmda-rx", title: "医療用医薬品 添付文書等情報検索", organization: "独立行政法人 医薬品医療機器総合機構（PMDA）",
                        urlString: "https://www.pmda.go.jp/PmdaSearch/iyakuSearch/", category: .drug,
                        summary: "医療用医薬品の最新の添付文書を検索できます。薬剤情報は常に最新の添付文書を優先してください。"),
        SourceReference(id: "pmda-otc", title: "一般用医薬品・要指導医薬品 添付文書等情報検索", organization: "独立行政法人 医薬品医療機器総合機構（PMDA）",
                        urlString: "https://www.pmda.go.jp/PmdaSearch/otcSearch/", category: .drug,
                        summary: "一般用医薬品・要指導医薬品の添付文書を検索できます。"),
        SourceReference(id: "mhlw-medical-safety", title: "医療安全対策", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/iryou/i-anzen/index.html", category: .safety,
                        summary: "医療安全施策・医療事故調査制度などの情報ページ。"),
        SourceReference(id: "cfa-maternal", title: "母子保健・不妊症・不育症など", organization: "こども家庭庁",
                        urlString: "https://www.cfa.go.jp/policies/boshihoken", category: .maternal,
                        summary: "母子保健法・成育基本法に基づく妊産婦・乳幼児の保健施策（令和5年4月に厚生労働省から移管）。"),
        SourceReference(id: "mhlw-vital-stats", title: "人口動態調査", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/toukei/list/81-1.html", category: .publicHealth,
                        summary: "出生・死亡・死因などの公式統計。統計数値は最新の公表値を確認してください。"),
        SourceReference(id: "mhlw-health-insurance", title: "医療保険", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/iryouhoken/index.html", category: .welfare,
                        summary: "医療保険制度に関する厚生労働省の情報ページ。"),
        SourceReference(id: "mhlw-kaigo", title: "介護・高齢者福祉", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/kaigo_koureisha/index.html", category: .welfare,
                        summary: "介護保険制度・地域包括ケアなど高齢者福祉の情報ページ。"),
        SourceReference(id: "mhlw-disability", title: "障害者福祉", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/shougaishahukushi/index.html", category: .welfare,
                        summary: "障害福祉サービス・制度に関する情報ページ。"),
        SourceReference(id: "mhlw-mental-health", title: "心の健康", organization: "厚生労働省",
                        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/hukushi_kaigo/shougaishahukushi/kokoro/index.html", category: .mental,
                        summary: "精神保健医療福祉・心の健康に関する情報ページ。"),
        SourceReference(id: "egov-hojokan", title: "保健師助産師看護師法（e-Gov 法令検索）", organization: "デジタル庁 e-Gov",
                        urlString: "https://laws.e-gov.go.jp/law/323AC0000000203", category: .law,
                        summary: "看護職の資格・業務・義務を定める法律の現行条文。")
    ]

    static func reference(_ id: String) -> SourceReference? { references.first { $0.id == id } }
    static func examSource(_ exam: Int) -> ExamSource? { examSources.first { $0.exam == exam } }
    static func references(in category: ReferenceCategory) -> [SourceReference] { references.filter { $0.category == category } }

    static func sessionLabel(_ session: String) -> String { session == "AM" ? "午前" : (session == "PM" ? "午後" : session) }

    /// Topic mapping by subject area and topic keywords (shared IDs, never per question).
    static func source(for q: NativeQuestion) -> QuestionSource {
        // Topic keywords are matched on the topic (subject) only; subject areas by exact name.
        func has(_ words: [String]) -> Bool { words.contains { q.subject.contains($0) } }
        func area(_ names: [String]) -> Bool { names.contains(q.majorSubject) }
        var ids: [String] = []
        func add(_ id: String) { if !ids.contains(id) { ids.append(id) } }

        if has(["感染", "食中毒"]) { add("mhlw-standard-precautions"); add("mhlw-infection-control"); add("mhlw-infectious-disease") }
        if has(["薬", "与薬", "輸液", "輸血", "中毒"]) { add("pmda-rx") }
        if has(["安全", "看護管理"]) { add("mhlw-medical-safety") }
        if area(["母性看護学", "小児看護学"]) || has(["妊娠", "分娩", "産褥", "新生児", "周産期"]) { add("cfa-maternal") }
        if has(["統計"]) { add("mhlw-vital-stats") }
        if has(["保険", "社会保障", "医療制度", "保健医療"]) { add("mhlw-health-insurance") }
        if area(["老年看護学", "地域・在宅看護論"]) || has(["介護", "地域包括", "在宅"]) { add("mhlw-kaigo") }
        if has(["障害福祉", "障害者"]) { add("mhlw-disability") }
        if area(["精神看護学"]) || has(["こころ", "メンタル", "精神"]) { add("mhlw-mental-health") }
        if has(["法規", "倫理", "看護記録", "看護の基本概念"]) { add("egov-hojokan") }
        add("standard-2023-nurse")

        let citation = "第\(q.sourceExam)回 看護師国家試験 \(sessionLabel(q.session)) 問\(q.questionNo)"
        return QuestionSource(exam: examSource(q.sourceExam), citation: citation, explanationSourceIDs: ids)
    }

    static let disclaimerParagraphs: [String] = [
        "本アプリは、看護師国家試験の学習を目的とした教育用アプリです。",
        "掲載している問題、解説および学習用情報は、看護師国家試験の学習を補助するためのものであり、実際の診断、治療、投薬、看護処置その他の医療行為に関する助言を提供するものではありません。",
        "問題文と正答は厚生労働省が公表した看護師国家試験の問題および正答に基づいています。「ここだけ覚える」「もう少し詳しく」の解説は、本アプリが学習用にまとめた要約です。",
        "医学・医療に関する知識、診療指針、医薬品の情報および法令等は、改訂・変更される場合があります。本アプリの情報が最新の医療情報と一致することを保証するものではありません。",
        "実際の医療・看護の現場では、本アプリの情報のみを根拠とせず、最新の公的資料、診療ガイドライン、医薬品の添付文書、所属施設の規程および医師等の専門職による判断を確認してください。",
        "掲載する問題の原典および参考資料は、アプリ内の「出典・参考資料」から確認できます。"
    ]
}

// MARK: - Views

struct ReferenceLinkRow: View {
    let title: String
    let detail: String
    let url: URL?
    var identifier: String = ""
    var body: some View {
        if let url {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.subheadline.bold()).foregroundStyle(KSTheme.ai).multilineTextAlignment(.leading)
                        if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(KSTheme.secondary).multilineTextAlignment(.leading) }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right.square").foregroundStyle(KSTheme.ai)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier(identifier)
            .accessibilityValue(url.absoluteString)
        }
    }
}

/// Compact source line shown on every question screen.
struct QuestionSourceBadge: View {
    let question: NativeQuestion
    var body: some View {
        let source = ReferenceCatalog.source(for: question)
        VStack(alignment: .leading, spacing: 4) {
            Text("出典：\(source.citation)（厚生労働省）").font(.caption2).foregroundStyle(KSTheme.secondary)
            if let exam = source.exam, let url = exam.pageURL {
                // Opens the exam's MHLW 「問題および正答について」 HTML page (not the answer PDF).
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("公式の問題・正答を確認する（厚生労働省「\(exam.title)の問題および正答について」ページ）").multilineTextAlignment(.leading)
                    }
                    .font(.caption2.bold()).foregroundStyle(KSTheme.ai)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("question-source-link")
                .accessibilityValue(url.absoluteString)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sources & references block shown in the explanation (feedback) area.
struct ExplanationReferencesSection: View {
    let question: NativeQuestion
    let openReferences: () -> Void
    var body: some View {
        let source = ReferenceCatalog.source(for: question)
        VStack(alignment: .leading, spacing: 8) {
            Text("出典・参考資料").font(.caption2.bold()).tracking(1.5).foregroundStyle(KSTheme.ai)
            Text("問題の原典：\(source.citation)（厚生労働省 公表）").font(.caption).foregroundStyle(KSTheme.secondary)
            if let exam = source.exam {
                ReferenceLinkRow(title: "\(exam.title) 問題（厚生労働省）", detail: exam.heldOn, url: exam.pageURL, identifier: "explanation-exam-link")
                ReferenceLinkRow(title: "\(exam.title) 正答値表（PDF）", detail: "厚生労働省", url: exam.answerPDFURL, identifier: "explanation-answer-link")
            }
            Text("解説は本アプリが学習用にまとめたものです。医学的な内容は、関連する公的資料や最新の添付文書・ガイドラインで確認してください。").font(.caption2).foregroundStyle(KSTheme.tertiary)
            ForEach(source.explanationReferences) { ref in
                ReferenceLinkRow(title: ref.title, detail: ref.organization, url: ref.url)
            }
            Button(action: openReferences) {
                Label("出典・参考資料の一覧を見る", systemImage: "books.vertical").font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered).tint(KSTheme.ai)
            .accessibilityIdentifier("explanation-references-button")
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(KSTheme.aiSoft.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ReferencesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("本アプリの問題は厚生労働省が公表した看護師国家試験（第115・114・113回）の問題および正答に基づいています。解説は本アプリが学習用にまとめたもので、医学的な内容は下記の公的資料で確認できます。各リンクは\(ReferenceCatalog.checkedOn)に掲載を確認しました。")
                    .font(.caption).foregroundStyle(KSTheme.secondary).padding(.horizontal, 18)

                section(ReferenceCategory.exam.rawValue) {
                    ForEach(ReferenceCatalog.examSources) { exam in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(exam.title)（\(exam.heldOn)）").font(.caption.bold()).foregroundStyle(KSTheme.ink)
                            ReferenceLinkRow(title: "問題および正答（掲載ページ）", detail: "厚生労働省", url: exam.pageURL, identifier: "references-exam-\(exam.exam)")
                            ReferenceLinkRow(title: "正答値表（PDF）", detail: "厚生労働省", url: exam.answerPDFURL)
                        }
                    }
                }
                ForEach(ReferenceCategory.allCases.filter { $0 != .exam }) { category in
                    let refs = ReferenceCatalog.references(in: category)
                    if !refs.isEmpty {
                        section(category.rawValue) {
                            ForEach(refs) { ref in
                                VStack(alignment: .leading, spacing: 2) {
                                    ReferenceLinkRow(title: ref.title, detail: ref.organization, url: ref.url)
                                    Text(ref.summary).font(.caption2).foregroundStyle(KSTheme.tertiary)
                                }
                            }
                        }
                    }
                }
                section("ご利用上の注意") { DisclaimerText() }
            }
            .padding(.vertical, 14)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle("出典・参考資料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        KSCard(content: VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(KSTheme.ink)
            content()
        }).padding(.horizontal, 18)
    }
}

struct DisclaimerText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ReferenceCatalog.disclaimerParagraphs, id: \.self) { p in
                Text(p).font(.caption).foregroundStyle(KSTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            KSCard(content: VStack(alignment: .leading, spacing: 10) {
                Text("ご利用上の注意").font(.headline).foregroundStyle(KSTheme.ink)
                DisclaimerText()
                NavigationLink { ReferencesView() } label: {
                    Label("出典・参考資料を見る", systemImage: "books.vertical").font(.subheadline.bold()).foregroundStyle(KSTheme.ai).frame(minHeight: 44)
                }
            }).padding(18)
        }
        .background(KSTheme.paper.ignoresSafeArea())
        .navigationTitle("ご利用上の注意")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

/// Sheet wrapper used from the explanation screen (inside the quiz full-screen cover).
struct ReferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ReferencesView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() }.accessibilityIdentifier("references-close") }
                }
        }
    }
}
